# --- اسکریپت جامع برای ساخت و پیکربندی سیستم آپدیت آفلاین ---
# این اسکریپت فایل‌های PowerShell و CMD لازم را می‌سازد
# و دستورالعمل‌های لازم برای اضافه کردن به فایل .csproj و کد WPF را نمایش می‌دهد.

# تنظیمات خطا
$ErrorActionPreference="Stop"
# $DebugPreference = "Continue" # برای نمایش پیام‌های Debug در صورت نیاز

# --- مسیرهای کاری ---
# مسیر روت اسکریپت، جایی که فایل‌های خروجی ساخته می‌شوند
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- پارامترهای اسکریپت ---
param(
    # مسیر فایل .csproj پروژه WPF. اگر خالی باشد، اسکریپت در پوشه فعلی به دنبال MyCompanyApp.Wpf.csproj می‌گردد.
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Join-Path $ScriptDir "MyCompanyApp.Wpf.csproj"),

    # نام اصلی پروژه WPF (بدون پسوند .csproj). برای نام‌گذاری فایل اجرایی و پکیج استفاده می‌شود.
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "MyCompanyApp.Wpf",

    # پیکربندی بیلد (مانند Release یا Debug)
    [Parameter(Mandatory=$false)]
    [string]$Configuration = "Release",

    # فریم‌ورک هدف (.NET 8 Windows)
    [Parameter(Mandatory=$false)]
    [string]$Framework = "net8.0-windows",

    # شناسه زمان اجرا (Runtime Identifier)
    [Parameter(Mandatory=$false)]
    [string]$RuntimeIdentifier = "win-x64",

    # تعیین می‌کند که آیا بیلد باید Self-Contained باشد یا خیر (نیاز به نصب .NET Runtime روی سیستم مشتری ندارد)
    [Parameter(Mandatory=$false)]
    [switch]$SelfContained,

    # پوشه خروجی برای فایل‌های ایجاد شده (اسکریپت‌ها، پکیج آپدیت و...)
    [Parameter(Mandatory=$false)]
    [string]$OutputRoot = (Join-Path $ScriptDir "OfflineUpdateFiles")
)

# --- اعتبار سنجی مسیر پروژه ---
if (!(Test-Path $ProjectPath)) {
    Write-Warning "Project file not found at '$ProjectPath'. Attempting to use default name 'MyCompanyApp.Wpf.csproj' in current directory."
    $ProjectPath = (Join-Path $ScriptDir "MyCompanyApp.Wpf.csproj")
    if (!(Test-Path $ProjectPath)) {
        throw "Project file '$ProjectPath' not found. Please provide a valid path using the -ProjectPath parameter."
    }
}
# استخراج نام پروژه از مسیر فایل .csproj اگر ProjectName داده نشده باشد
if (-not $ProjectName) {
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
}

# --- تعریف نام فایل‌های خروجی ---
$ValidatorFile = Join-Path $OutputRoot "ValidateUpdate.ps1"
$UpdaterFile = Join-Path $OutputRoot "MyCompanyApp.Updater.ps1"
$CmdFile = Join-Path $OutputRoot "RunUpdate.cmd"
$BuildScriptFile = Join-Path $OutputRoot "Build-OfflineUpdate.ps1" # اسکریپت ساخت پکیج .mya

# --- ایجاد پوشه خروجی ---
if (!(Test-Path $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    Write-Host "Created output directory: '$OutputRoot'" -ForegroundColor Green
} else {
    Write-Host "Output directory already exists: '$OutputRoot'"
}

# --- محتوای اسکریپت ValidateUpdate.ps1 ---
$ValidatorContent = @'
<#
.SYNOPSIS
    Validates the integrity of an update package (.mya file).

.DESCRIPTION
    This script extracts the update package, checks for the existence of manifest.json and checksums.sha256,
    and verifies the SHA256 hash of each file within the package against the checksums file.
    It outputs 'VALID' if all checks pass, and 'INVALID' otherwise.

.PARAMETER Package
    The full path to the update package file (.mya).

.EXAMPLE
    .\ValidateUpdate.ps1 -Package "C:\Updates\MyCompanyApp_Update_1.0.1.mya"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Package
)

$ErrorActionPreference="Stop"
# Use a temporary directory for extraction
$temp = Join-Path $env:TEMP "MyCompanyAppUpdateCheck_$(Get-Random)"

try {
    # Check if package file exists
    if (!(Test-Path $Package)) {
        Write-Output "INVALID"
        Write-Error "Package file not found: '$Package'"
        exit 1
    }

    # Clean up any previous temporary extraction
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

    # Extract the package
    Expand-Archive -Path $Package -DestinationPath $temp -Force
    Write-Verbose "Package extracted to '$temp'"

    # Define expected files
    $manifest = Join-Path $temp "manifest.json"
    $checksums = Join-Path $temp "checksums.sha256"

    # Check for manifest and checksums file
    if (!(Test-Path $manifest) -or !(Test-Path $checksums)) {
        Write-Output "INVALID"
        Write-Error "Manifest or Checksums file missing in package."
        exit 1
    }

    # Verify all files against checksums
    $checksumLines = Get-Content $checksums
    foreach($line in $checksumLines){
        $parts = $line.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        if($parts.Length -ne 2) {
            Write-Output "INVALID"
            Write-Error "Invalid line format in checksums file: '$line'"
            exit 1
        }
        $expectedHash = $parts[0].ToLower()
        $relativePath = $parts[1]
        $filePath = Join-Path $temp $relativePath

        if(!(Test-Path $filePath)){
            Write-Output "INVALID"
            Write-Error "File listed in checksums not found in package: '$relativePath'"
            exit 1
        }

        $actualHash = (Get-FileHash $filePath -Algorithm SHA256).Hash.ToLower()
        if($actualHash -ne $expectedHash){
            Write-Output "INVALID"
            Write-Error "Hash mismatch for '$relativePath'. Expected '$expectedHash', got '$actualHash'."
            exit 1
        }
        Write-Verbose "Verified: '$relativePath' with hash '$expectedHash'"
    }

    # If all checks passed
    Write-Output "VALID"
    Write-Host "Update package validation successful."

}
catch {
    Write-Output "INVALID"
    Write-Error "An unexpected error occurred during validation: $($_.Exception.Message)"
    exit 1
}
finally {
    # Clean up temporary directory
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
'@
Set-Content -Path $ValidatorFile -Value $ValidatorContent -Encoding UTF8
Write-Host "Created: '$ValidatorFile'"

# --- محتوای اسکریپت MyCompanyApp.Updater.ps1 (با GUI و Rollback) ---
$UpdaterContent = @'
<#
.SYNOPSIS
    Updates the MyCompanyApp application using a provided update package.

.DESCRIPTION
    This script handles the update process with a graphical interface. It extracts the package,
    backs up the current application files, replaces them with updated files, and performs rollback
    in case of any errors. It also attempts to launch the updated application.

.PARAMETER Package
    The full path to the update package file (.mya).

.EXAMPLE
    .\MyCompanyApp.Updater.ps1 -Package "C:\Downloads\MyCompanyApp_Update_1.0.1.mya"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Package
)

# Add necessary .NET assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Xml # Required for XmlDocument if needed, but not used here directly

# --- Define Paths and Directories ---
# Get the directory where this script (Updater.ps1) is located
$UpdaterScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
# The main application directory is assumed to be the parent of the updater script's directory
# or the directory where RunUpdate.cmd is executed from.
# We use "%~dp0" from RunUpdate.cmd, which resolves to the directory of RunUpdate.cmd.
# Since Updater.ps1 is copied next to RunUpdate.cmd, this effectively becomes the app dir.
$AppDir = $UpdaterScriptDir

# Temporary directory for extracting the package
$TempDir = Join-Path $env:TEMP "MyCompanyAppUpdate_$(Get-Random)"
# Backup directory for current application files
$BackupDir = Join-Path $AppDir "backup"

# --- Helper Function for Rollback ---
function Rollback {
    param($sourceDir, $destDir)
    Write-Host "Starting rollback..."
    if (Test-Path $sourceDir) {
        try {
            # Ensure destination exists before copying
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            # Copy contents from backup to destination
            Copy-Item -Path "$sourceDir\*" -Destination $destDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Rollback completed successfully from '$sourceDir' to '$destDir'."
        } catch {
            Write-Error "Rollback failed: $($_.Exception.Message)"
        } finally {
            # Clean up backup directory after rollback attempt
            Remove-Item $sourceDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "Backup directory not found: '$sourceDir'. Cannot perform rollback."
    }
}

# --- Form Creation ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "MyCompanyApp Update"
$Form.Size = New-Object System.Drawing.Size(550, 200) # Slightly wider form
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.MinimizeBox = $false
$Form.TopMost = $true # Keep form on top

# Status Label
$Label = New-Object System.Windows.Forms.Label
$Label.Size = New-Object System.Drawing.Size(490, 50) # Increased height
$Label.Location = New-Object System.Drawing.Point(20, 20)
$Label.Text = "Initializing update process..."
$Label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Form.Controls.Add($Label)

# Progress Bar
$Progress = New-Object System.Windows.Forms.ProgressBar
$Progress.Size = New-Object System.Drawing.Size(490, 30)
$Progress.Location = New-Object System.Drawing.Point(20, 80)
$Progress.Minimum = 0
$Progress.Maximum = 100
$Progress.Value = 0
$Form.Controls.Add($Progress)

# --- Form Shown Event Handler ---
# This block runs when the form is first displayed
$Form.Add_Shown({
    $FormInstance = $this # Reference to the form

    # Define the script block that performs the update logic
    $updateScriptBlock = {
        param($Form, $Label, $Progress, $PackagePath, $AppDir, $BackupDir, $TempDir)

        try {
            # --- Step 1: Extract Package ---
            $Label.Invoke({ $Label.Text = "Extracting update package..." })
            $Progress.Invoke({ $Progress.Value = 10 })
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Expand-Archive -Path $PackagePath -DestinationPath $TempDir -Force)) {
                throw "Failed to extract update package. Please ensure the package is valid."
            }
            Write-Host "Package extracted to '$TempDir'"

            # --- Step 2: Backup Current Application ---
            $Label.Invoke({ $Label.Text = "Backing up current version..." })
            $Progress.Invoke({ $Progress.Value = 30 })
            Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            # Copy items from the application directory to backup, excluding the backup folder itself
            Get-ChildItem -Path $AppDir -Recurse | Where-Object { $_.FullName -ne $BackupDir -and $_.FullName -ne $PackagePath } | Copy-Item -Destination $BackupDir -Recurse -Force
            Write-Host "Current application backed up to '$BackupDir'"

            # --- Step 3: Replace Files ---
            $Label.Invoke({ $Label.Text = "Applying update files..." })
            $Progress.Invoke({ $Progress.Value = 50 })
            # Copy updated files from temp directory to application directory
            Copy-Item -Path "$TempDir\*" -Destination $AppDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Updated files copied to '$AppDir'"

            # --- Step 4: Cleanup Temporary Files ---
            $Label.Invoke({ $Label.Text = "Cleaning up temporary files..." })
            $Progress.Invoke({ $Progress.Value = 80 })
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Temporary files cleaned up."

            # --- Step 5: Cleanup Backup (if update was successful) ---
            $Label.Invoke({ $Label.Text = "Finalizing update..." })
            Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Backup directory removed after successful update."

            # --- Success Message and Launch ---
            $Label.Invoke({ $Label.Text = "Update successful! Restarting application..." })
            $Progress.Invoke({ $Progress.Value = 100 })
            Start-Sleep -Seconds 2 # Short pause to show success message

            # --- Attempt to launch the main application executable ---
            # Dynamically determine the executable name (e.CH. MyCompanyApp.Wpf.exe)
            $mainExeName = ""
            $manifestJsonPath = Join-Path $AppDir "manifest.json"
            if (Test-Path $manifestJsonPath) {
                $manifestContent = Get-Content $manifestJsonPath | ConvertFrom-Json
                if ($manifestContent.executable) {
                    $mainExeName = $manifestContent.executable
                }
            }
            # Fallback if manifest is missing or doesn't specify executable
            if (-not $mainExeName) {
                $mainExeName = (Get-ChildItem -Path $AppDir -Filter "*.exe" | Where-Object { $_.Name -notmatch "powershell.exe" -and $_.Name -notmatch "updater.exe" -and $_.Name -notmatch "runupdate.cmd" } | Select-Object -First 1).Name
            }

            if ($mainExeName -and (Test-Path (Join-Path $AppDir $mainExeName))) {
                Write-Host "Launching updated application: '$mainExeName'"
                # Use Start-Process with admin rights if updater was run as admin
                # If not run as admin, it will launch with current user privileges
                Start-Process (Join-Path $AppDir $mainExeName)
            } else {
                Write-Warning "Could not automatically determine or launch the main application executable."
            }

            # Close the form after a short delay
            Start-Sleep -Seconds 1
            $Form.Invoke({ $Form.Close() })

        }
        catch {
            # --- Error Handling and Rollback ---
            $errorMessage = $_.Exception.Message
            # Basic sanitization for label display - remove potentially harmful characters or excessive newlines
            $SafeErrorMessage = $errorMessage -replace "`r|`n", " "
            if ($SafeErrorMessage.Length -gt 100) { $SafeErrorMessage = $SafeErrorMessage.Substring(0, 100) + "..." }
            
            $Label.Invoke({ $Label.Text = "Update Failed: $($SafeErrorMessage)" })
            $Label.Invoke({ $Label.ForeColor = [System.Drawing.Color]::Red }) # Set text color to red for errors
            $Progress.Invoke({ $Progress.Value = 100 }) # Indicate process completion (even if error)

            Write-Error "Update process failed: $($errorMessage)"

            # Attempt rollback
            Rollback -sourceDir $BackupDir -destDir $AppDir

            # Give user time to read the error message
            Start-Sleep -Seconds 4

            # Ensure the form is closed after rollback attempt
            $Form.Invoke({ $Form.Close() })
        }
    } # End of $updateScriptBlock

    # Start the update process in a background job to keep the GUI responsive
    $job = Start-Job -ScriptBlock $updateScriptBlock -ArgumentList @($FormInstance, $Label, $Progress, $Package, $AppDir, $BackupDir, $TempDir)

    # Optional: You could add logic here to monitor $job.JobState or use IJob::HasExited,
    # but for this simple GUI, we rely on the script block's UI updates and form closing.
})

# Enable visual styles for the form
[System.Windows.Forms.Application]::EnableVisualStyles()
# Run the form
[System.Windows.Forms.Application]::Run($Form)
'@
Set-Content -Path $UpdaterFile -Value $UpdaterContent -Encoding UTF8
Write-Host "Created: '$UpdaterFile'"

# --- محتوای اسکریپت RunUpdate.cmd ---
$CmdContent = @'
@echo off
REM ============================================================
REM RunUpdate.cmd
REM
REM This command file launches the MyCompanyApp.Updater.ps1 PowerShell script.
REM It ensures PowerShell is run with appropriate execution policy and
REM requests administrator privileges for the update process.
REM
REM Usage: RunUpdate.cmd "path\to\your\update.mya"
REM OR just run it and it will prompt for the update file.
REM ============================================================

echo Preparing to launch the MyCompanyApp update process...
echo.

REM Get the directory where this CMD file is located
SET ScriptDir=%~dp0

REM Define the path to the PowerShell updater script
SET UpdaterScript="%ScriptDir%MyCompanyApp.Updater.ps1"

REM Get the update package path from command line arguments, or prompt the user
SET UpdatePackagePath=%1

IF "%UpdatePackagePath%"=="" (
    echo No update package path provided. Please select the .mya file.
    REM Use PowerShell to show an Open File Dialog
    powershell -Command "$words = @('Update Package (*.mya)|*.mya'); $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog; $openFileDialog.Filter = $words -join ''; $openFileDialog.Title = 'Select Update Package'; if ($openFileDialog.ShowDialog() -eq 'OK') { Write-Host $openFileDialog.FileName }"
    REM Read the selected file path from PowerShell output
    set /p UpdatePackagePath="Enter the full path to the update package (.mya file) or paste the path shown above: "
)

REM Check if a package path was provided or entered
IF "%UpdatePackagePath%"=="" (
    echo Error: No update package path specified. Exiting.
    pause
    EXIT /B 1
)

REM Remove surrounding quotes if present
SET UpdatePackagePath=%UpdatePackagePath:"=%

REM Check if the specified package file exists
IF NOT EXIST "%UpdatePackagePath%" (
    echo Error: Update package file not found at "%UpdatePackagePath%". Exiting.
    pause
    EXIT /B 1
)

echo Launching updater with package: "%UpdatePackagePath%"
echo.

REM Execute the PowerShell updater script.
REM -NoProfile: Does not load the PowerShell profile.
REM -ExecutionPolicy Bypass: Allows the script to run regardless of the system's execution policy.
REM -File: Specifies the path to the script to run.
REM "%UpdatePackagePath%" is passed as an argument to the PowerShell script.

powershell -NoProfile -ExecutionPolicy Bypass -File %UpdaterScript% -Package "%UpdatePackagePath%"

REM The PowerShell script will handle GUI display, updates, and launching the main app.
REM This CMD file simply acts as a launcher.

echo.
echo Update process initiated via PowerShell. Please check the application window for status.
echo If the updater window does not appear, ensure PowerShell is enabled and accessible.
REM pause REM Uncomment if you want the CMD window to stay open after PowerShell finishes.
EXIT /B 0
'@
Set-Content -Path $CmdFile -Value $CmdContent -Encoding ASCII
Write-Host "Created: '$CmdFile'"

# --- محتوای اسکریپت Build-OfflineUpdate.ps1 ---
$BuildScriptContent = @'
<#
.SYNOPSIS
    Builds a self-contained offline update package (.mya) for the WPF application.

.DESCRIPTION
    This script performs the following actions:
    1. Cleans and publishes the WPF project using 'dotnet publish'.
    2. Gathers all published files into a temporary payload directory.
    3. Calculates SHA256 checksums for all files in the payload.
    4. Creates a manifest.json file containing package metadata.
    5. Compresses the payload, manifest, and checksums into a single .mya archive file.

.PARAMETER Version
    The version number for the update package (e.g., "1.0.1"). Mandatory.

.PARAMETER ProjectPath
    The full path to the WPF project file (.csproj). Defaults to looking for MyCompanyApp.Wpf.csproj in the same directory as this script.

.PARAMETER ProjectName
    The name of the WPF project without the .csproj extension. Used for identifying the main executable. Defaults to the project file name.

.PARAMETER Configuration
    The build configuration (e.g., "Release", "Debug"). Defaults to "Release".

.PARAMETER Framework
    The target .NET framework (e.g., "net8.0-windows"). Defaults to "net8.0-windows".

.PARAMETER RuntimeIdentifier
    The target runtime identifier (e.g., "win-x64", "win-x86", "win-arm64"). Defaults to "win-x64".

.PARAMETER SelfContained
    Specifies whether the publish should be self-contained. Use the switch -SelfContained to enable.
    Set to '$true' if the target environment might not have the .NET runtime installed.

.PARAMETER OutputRoot
    The root directory where the update package and temporary files will be stored. Defaults to ".\OfflinePackages" in the script's directory.

.EXAMPLE
    # Build an update package for version 1.0.1 using default settings
    .\Build-OfflineUpdate.ps1 -Version "1.0.1"

.EXAMPLE
    # Build a self-contained update package for a specific project and runtime
    .\Build-OfflineUpdate.ps1 -Version "1.1.0" -ProjectPath "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj" -ProjectName "MyCompanyApp.Wpf" -RuntimeIdentifier "win-x64" -SelfContained
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$false)]
    [string]$ProjectName,

    [Parameter(Mandatory=$false)]
    [string]$Configuration = "Release",

    [Parameter(Mandatory=$false)]
    [string]$Framework = "net8.0-windows",

    [Parameter(Mandatory=$false)]
    [switch]$SelfContained, # Use -SelfContained switch to enable

    [Parameter(Mandatory=$false)]
    [string]$RuntimeIdentifier = "win-x64", # Default RID

    [Parameter(Mandatory=$false)]
    [string]$OutputRoot # Will default to .\OfflinePackages in script dir if not provided
)

# --- Initial Setup and Validation ---
$ErrorActionPreference="Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Resolve Project Path
if (-not $ProjectPath) {
    $ProjectPath = Join-Path $ScriptDir "MyCompanyApp.Wpf.csproj"
}
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction SilentlyContinue
if (-not $ProjectPath) {
    throw "WPF project file not found at specified path: '$($ProjectPath)'."
}

# Resolve Project Name
if (-not $ProjectName) {
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
}

# Resolve Output Root
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $ScriptDir "OfflinePackages"
}
$OutputRoot = Resolve-Path $OutputRoot -ErrorAction SilentlyContinue
if (-not $OutputRoot) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

$PublishDir = Join-Path $OutputRoot "publish_$Version"
$WorkDir = Join-Path $OutputRoot "work_$Version"
$PayloadDir = Join-Path $WorkDir "payload"
$PackageName = "$ProjectName\_Update_$Version.mya"
$PackagePath = Join-Path $OutputRoot $PackageName

# Ensure dotnet CLI is available
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "Dotnet CLI is not found. Please ensure .NET SDK is installed and in your system's PATH."
}

# Create necessary directories
New-Item -ItemType Directory -Force -Path $PayloadDir | Out-Null
Write-Host "Created payload directory: '$PayloadDir'" -ForegroundColor Green

# --- Helper Functions ---
function Write-Section($t){
    Write-Host ""
    Write-Host "====================== $t ======================" -ForegroundColor Cyan
}

function Hash-File($path){
    # Calculates SHA256 hash of a file
    return (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
}

# --- Step 1: Dotnet Publish ---
Write-Section "Dotnet Publish"
$publishParams = @{
    "ProjectPath" = $ProjectPath
    "Configuration" = $Configuration
    "Framework" = $Framework
    "Output" = $PublishDir
    "Runtime" = $RuntimeIdentifier
    "ErrorAction" = "Stop"
    "Verbosity" = "normal"
    "SelfContained" = $SelfContained.IsPresent # Handles the switch parameter correctly
}

Write-Host "Running: dotnet publish '$ProjectPath' for '$RuntimeIdentifier'..."
if ($SelfContained.IsPresent) {
    Write-Host "Publishing as Self-Contained."
} else {
    Write-Host "Publishing as Framework-Dependent."
}

# We publish with PublishSingleFile=true and IncludeNativeLibrariesForSelfExtract=true to get a single executable
# However, for an update system, we need individual files.
# The best approach is to publish WITHOUT PublishSingleFile, and then manually zip the contents.
# If you MUST use PublishSingleFile, it complicates extracting individual files reliably.
# For simplicity and update system needs, let's adjust to publish without single file.
# If you need a single executable, consider a different update strategy or post-processing.

# Option 1: Publish WITHOUT PublishSingleFile (Recommended for this update system)
dotnet publish $ProjectPath -c $Configuration -f $Framework -r $RuntimeIdentifier --output $PublishDir @publishParams

# Option 2: If you absolutely need PublishSingleFile (and accept complexities)
# dotnet publish $ProjectPath -c $Configuration -f $Framework -r $RuntimeIdentifier --output $PublishDir /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true

Write-Host "Publish completed. Output directory: '$PublishDir'"

# --- Step 2: Copy Published Files to Payload ---
Write-Section "Copying Publish Output to Payload"
# Copy all files from the publish directory to the payload directory
Get-ChildItem -Path $PublishDir -Recurse -File | ForEach-Object {
    $destinationPath = Join-Path $PayloadDir $_.Name
    Copy-Item $_.FullName -Destination $destinationPath -Force
    Write-Verbose "Copied '$($_.Name)' to payload."
}
Write-Host "Copied published files to '$PayloadDir'."

# --- Step 3: Generate Checksums ---
Write-Section "Generating Checksums"
$checksumEntries = @()
$payloadFiles = Get-ChildItem $PayloadDir -Recurse -File

# Ensure manifest and checksum files themselves are not included in checksum calculation
$payloadFiles | Where-Object { $_.Name -ne "manifest.json" -and $_.Name -ne "checksums.sha256" } | ForEach-Object {
    # Calculate relative path within the payload directory for the checksum file
    $relativePath = $_.FullName.Substring($PayloadDir.Length + 1).Replace("\", "/")
    $hash = Hash-File $_.FullName
    $checksumEntries += "$hash  $relativePath"
    Write-Verbose "Checksum for '$relativePath': $hash"
}
# Save checksums to a file within the payload
$checksumFile = Join-Path $PayloadDir "checksums.sha256"
$checksumEntries | Set-Content $checksumFile -Encoding UTF8
Write-Host "Generated checksums file: '$checksumFile'"

# --- Step 4: Create Manifest ---
Write-Section "Creating Manifest"
$manifest = @{
    packageId      = [guid]::NewGuid().ToString()
    application    = $ProjectName
    executable     = "$ProjectName.exe" # Assumes executable name matches project name. Adjust if needed.
    version        = $Version
    created        = (Get-Date).ToUniversalTime().ToString("o") # ISO 8601 format
    framework      = $Framework
    runtime        = $RuntimeIdentifier
    selfContained  = $SelfContained.IsPresent
}
$manifestJsonPath = Join-Path $PayloadDir "manifest.json"
$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestJsonPath -Encoding UTF8
Write-Host "Created manifest file: '$manifestJsonPath'"

# --- Step 5: Create Package Archive (.mya) ---
Write-Section "Creating Package Archive"
# Compress the contents of the payload directory into a single zip file, then rename to .mya
$tempZipPath = Join-Path $OutputRoot "temp_package_$($ProjectName)_$($Version).zip"
Compress-Archive -Path "$PayloadDir\*" -DestinationPath $tempZipPath -Force -ErrorAction Stop
Rename-Item $tempZipPath -NewName $PackagePath -Force
Write-Host "Package archive created: '$PackagePath'"

# --- Final Summary ---
Write-Section "Build Process Complete"
$packageSizeMB = [Math]::Round((Get-Item $PackagePath).Length / 1MB, 2)
$packageHash = Hash-File $PackagePath

Write-Host "Offline update package created successfully!" -ForegroundColor Green
Write-Host "  Package Path: '$PackagePath'"
Write-Host "  Version: $Version"
Write-Host "  Size: $($packageSizeMB) MB"
Write-Host "  SHA256 Hash: $packageHash"
Write-Host ""
Write-Host "Temporary working files are located in: '$WorkDir'"
Write-Host "Published files are located in: '$PublishDir'"

# Optional: Cleanup temporary working directories after successful package creation
# Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
# Remove-Item $PublishDir -Recurse -Force -ErrorAction SilentlyContinue
# Write-Host "Cleaned up temporary working directories."

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Next Steps:" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "1. Copy the generated update files to your WPF project's output directory:"
Write-Host "   - Copy the following files FROM '$OutputRoot' INTO your WPF project folder (e.g., G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf):"
Write-Hos