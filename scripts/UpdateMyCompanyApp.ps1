# UpdateMyCompanyApp.ps1
# Offline updater for MyCompanyApp.Wpf
# Compatible with Windows PowerShell 5.1
# Keep this file ASCII/UTF-8 to avoid encoding issues.

$ErrorActionPreference = "Stop"

# =========================
# Configuration
# =========================

$projectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$myaPackageName = "MyCompanyApp.Wpf.update.mya"
$myaPackagePath = Join-Path $projectRoot $myaPackageName

$targetDir = "C:\MyApp"

$sevenZipExe = "C:\Program Files\7-Zip\7z.exe"

$mainExeName = "MyCompanyApp.Wpf.exe"

$tempExtract = Join-Path $env:TEMP "MyCompanyApp_Update_Extract"

# If you want to search only in installed files, set this to $false.
# If you want to also search project root, keep it $true.
$alsoSearchProjectRoot = $true

# =========================
# Helper functions
# =========================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Format-FileSizeMB {
    param([long]$Bytes)

    if ($Bytes -le 0) {
        return "0 MB"
    }

    return ("{0:N2} MB" -f ($Bytes / 1MB))
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Remove-DirectoryIfExists {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-BestExeCandidate {
    param(
        [string[]]$SearchRoots,
        [string]$ExeName
    )

    $allCandidates = @()

    foreach ($root in $SearchRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $root)) {
            Write-Warn "Search root does not exist: $root"
            continue
        }

        Write-Info "Scanning for '$ExeName' in: $root"

        $found = Get-ChildItem -LiteralPath $root -Filter $ExeName -Recurse -File -ErrorAction SilentlyContinue

        if ($found) {
            $allCandidates += $found
        }
    }

    if (-not $allCandidates -or $allCandidates.Count -eq 0) {
        return $null
    }

    Write-Info "Executable candidates found:"
    $allCandidates |
        Sort-Object -Property Length -Descending |
        ForEach-Object {
            $size = Format-FileSizeMB $_.Length
            Write-Host ("  - {0} | {1}" -f $_.FullName, $size) -ForegroundColor DarkGray
        }

    $best = $allCandidates |
        Sort-Object -Property Length -Descending |
        Select-Object -First 1

    return $best
}

# =========================
# Start
# =========================

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " MyCompanyApp.Wpf Offline Update Started" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # =========================
    # Step 1: Validate paths
    # =========================

    Write-Info "Step 1/5: Validating required files and paths..."

    if (-not (Test-Path -LiteralPath $projectRoot)) {
        Write-Fail "Project root not found: $projectRoot"
        exit 1
    }

    Write-Ok "Project root found: $projectRoot"

    if (-not (Test-Path -LiteralPath $myaPackagePath)) {
        Write-Fail "Update package not found: $myaPackagePath"
        Write-Warn "Expected package name: $myaPackageName"
        exit 1
    }

    Write-Ok "Update package found: $myaPackagePath"

    if (-not (Test-Path -LiteralPath $sevenZipExe)) {
        Write-Fail "7-Zip executable not found: $sevenZipExe"
        Write-Warn "Install 7-Zip or update the sevenZipExe variable in this script."
        exit 1
    }

    Write-Ok "7-Zip found: $sevenZipExe"

    # =========================
    # Step 2: Prepare temp folder
    # =========================

    Write-Info "Step 2/5: Preparing temporary extraction folder..."

    Remove-DirectoryIfExists $tempExtract
    Ensure-Directory $tempExtract

    Write-Ok "Temporary folder ready: $tempExtract"

    # =========================
    # Step 3: Extract package
    # =========================

    Write-Info "Step 3/5: Extracting update package..."

    $extractArgs = @(
        "x",
        $myaPackagePath,
        "-o$tempExtract",
        "-y"
    )

    Write-Info "Running 7-Zip extraction..."

    $process = Start-Process `
        -FilePath $sevenZipExe `
        -ArgumentList $extractArgs `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($process.ExitCode -ne 0) {
        Write-Fail "7-Zip extraction failed. ExitCode: $($process.ExitCode)"
        exit 1
    }

    Write-Ok "Package extracted successfully."

    # =========================
    # Step 4: Copy files to target
    # =========================

    Write-Info "Step 4/5: Copying extracted files to target directory..."

    Ensure-Directory $targetDir

    $extractedItems = Get-ChildItem -LiteralPath $tempExtract -Force -ErrorAction SilentlyContinue

    if (-not $extractedItems -or $extractedItems.Count -eq 0) {
        Write-Fail "Extraction folder is empty: $tempExtract"
        exit 1
    }

    Copy-Item -Path (Join-Path $tempExtract "*") -Destination $targetDir -Recurse -Force

    Write-Ok "Files copied to: $targetDir"

    # =========================
    # Step 5: Find and run main exe
    # =========================

    Write-Info "Step 5/5: Finding main executable..."

    $searchRoots = @()
    $searchRoots += $targetDir

    if ($alsoSearchProjectRoot -eq $true) {
        $searchRoots += $projectRoot
    }

    $bestCandidate = Get-BestExeCandidate -SearchRoots $searchRoots -ExeName $mainExeName

    if ($null -eq $bestCandidate) {
        Write-Fail "No executable named '$mainExeName' was found."
        Write-Warn "Checked paths:"
        foreach ($root in $searchRoots) {
            Write-Host "  - $root" -ForegroundColor Yellow
        }
        exit 1
    }

    $mainExePath = $bestCandidate.FullName
    $mainExeDir = Split-Path -Path $mainExePath -Parent
    $mainExeSize = Format-FileSizeMB $bestCandidate.Length

    Write-Ok "Best executable selected:"
    Write-Host "  Path: $mainExePath" -ForegroundColor Green
    Write-Host "  Size: $mainExeSize" -ForegroundColor Green
    Write-Host "  WorkingDirectory: $mainExeDir" -ForegroundColor Green

    Write-Info "Cleaning temporary folder..."
    Remove-DirectoryIfExists $tempExtract
    Write-Ok "Temporary folder cleaned."

    Write-Info "Starting application..."

    Start-Process -FilePath $mainExePath -WorkingDirectory $mainExeDir

    Write-Ok "Application started."

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " Update completed successfully." -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""

    exit 0
}
catch {
    Write-Fail "Unexpected error:"
    Write-Host $_.Exception.Message -ForegroundColor Red

    Write-Warn "Trying to clean temporary folder..."
    Remove-DirectoryIfExists $tempExtract

    exit 1
}
