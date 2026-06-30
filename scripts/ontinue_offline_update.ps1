$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# =========================================================
# ROOT PATHS
# =========================================================
$Root = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$SolutionPath = Join-Path $Root "MyCompanyApp.sln"
$WpfProjectPath = Join-Path $Root "src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$UpdaterProjectPath = Join-Path $Root "MyCompanyApp.Updater\MyCompanyApp.Updater.csproj"
$PublishRoot = Join-Path $Root "Publish"
$OfflinePackageRoot = Join-Path $Root "DevOfflinePackages"
$SamplePackageRoot = Join-Path $OfflinePackageRoot "SamplePackage"
$SampleZipPath = Join-Path $OfflinePackageRoot "MyCompanyApp.OfflineUpdate.Sample.zip"

# =========================================================
# HELPERS
# =========================================================
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERR ] $msg" -ForegroundColor Red }

function Ensure-Dir {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) {
        $bak = "$Path.bak"
        Copy-Item $Path $bak -Force
        Write-Info "Backup created: $bak"
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    Ensure-Dir (Split-Path $Path -Parent)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Patch-Csproj {
    param([Parameter(Mandatory)][string]$CsprojPath)

    if (-not (Test-Path $CsprojPath)) {
        Write-Warn "csproj not found: $CsprojPath"
        return
    }

    Backup-File $CsprojPath

    $content = Get-Content $CsprojPath -Raw

    if ($content -notmatch "<Nullable>enable</Nullable>") {
        $content = $content -replace "<PropertyGroup>", "<PropertyGroup>`r`n    <Nullable>enable</Nullable>"
    }

    if ($content -notmatch "<ImplicitUsings>enable</ImplicitUsings>") {
        $content = $content -replace "<PropertyGroup>", "<PropertyGroup>`r`n    <ImplicitUsings>enable</ImplicitUsings>"
    }

    # WPF requirement for the updater project
    if ($CsprojPath -match "MyCompanyApp\.Updater\.csproj" -and $content -notmatch "<UseWPF>true</UseWPF>") {
        $content = $content -replace "<PropertyGroup>", "<PropertyGroup>`r`n    <UseWPF>true</UseWPF>"
    }

    Write-Utf8NoBom -Path $CsprojPath -Content $content
    Write-Ok "Patched csproj: $CsprojPath"
}

function Build-Project {
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$OutputDir
    )

    Ensure-Dir $OutputDir
    Write-Info "Building: $ProjectPath"
    dotnet build $ProjectPath -c $Configuration -o $OutputDir
    Write-Ok "Build complete: $ProjectPath"
}

function Publish-Project {
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$OutputDir
    )

    Ensure-Dir $OutputDir
    Write-Info "Publishing: $ProjectPath"
    dotnet publish $ProjectPath -c $Configuration -o $OutputDir
    Write-Ok "Publish complete: $ProjectPath"
}

function New-Sha256 {
    param([Parameter(Mandatory)][string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToUpperInvariant()
}

function New-ZipFromFolder {
    param(
        [Parameter(Mandatory)][string]$SourceFolder,
        [Parameter(Mandatory)][string]$ZipPath
    )

    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }

    if (Test-Path $SourceFolder) {
        Compress-Archive -Path (Join-Path $SourceFolder "*") -DestinationPath $ZipPath -Force
        Write-Ok "ZIP created: $ZipPath"
    }
    else {
        throw "Source folder not found: $SourceFolder"
    }
}

# =========================================================
# CHECK BASIC STRUCTURE
# =========================================================
if (-not (Test-Path $Root)) {
    throw "Root path not found: $Root"
}

if (-not (Test-Path $SolutionPath)) {
    Write-Warn "Solution file not found: $SolutionPath"
}

Ensure-Dir $PublishRoot
Ensure-Dir $OfflinePackageRoot
Ensure-Dir $SamplePackageRoot

# =========================================================
# PATCH PROJECTS
# =========================================================
Write-Info "Patching csproj files..."
Patch-Csproj -CsprojPath $WpfProjectPath
Patch-Csproj -CsprojPath $UpdaterProjectPath

# =========================================================
# RESTORE + BUILD
# =========================================================
Write-Info "Restoring solution..."
dotnet restore $SolutionPath

Write-Info "Building main WPF project..."
Build-Project -ProjectPath $WpfProjectPath -Configuration "Release" -OutputDir (Join-Path $PublishRoot "Wpf")

Write-Info "Building updater project..."
Build-Project -ProjectPath $UpdaterProjectPath -Configuration "Release" -OutputDir (Join-Path $PublishRoot "Updater")

# =========================================================
# PUBLISH UPDATER TO PUBLISH FOLDER
# =========================================================
Write-Info "Publishing updater..."
Publish-Project -ProjectPath $UpdaterProjectPath -Configuration "Release" -OutputDir (Join-Path $PublishRoot "UpdaterPublish")

# =========================================================
# CREATE SAMPLE OFFLINE PACKAGE STRUCTURE
# =========================================================
Write-Info "Preparing sample offline package folder..."

$SampleFilesDir = Join-Path $SamplePackageRoot "files"
Ensure-Dir $SampleFilesDir

# Copy published WPF output as sample payload
$WpfPublishDir = Join-Path $PublishRoot "Wpf"
if (Test-Path $WpfPublishDir) {
    Copy-Item -Path (Join-Path $WpfPublishDir "*") -Destination $SampleFilesDir -Recurse -Force
    Write-Ok "Copied WPF publish output into sample package files/"
}
else {
    Write-Warn "WPF publish output not found, sample package will only contain manifest."
}

# Create manifest.json
$ManifestPath = Join-Path $SamplePackageRoot "manifest.json"
$CurrentExe = "MyCompanyApp.Wpf.exe"

$wpfExe = Get-ChildItem -Path $SampleFilesDir -Filter "*.exe" -File -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -like "*Wpf*.exe" -or $_.Name -like "MyCompanyApp*.exe" } |
          Select-Object -First 1

if ($wpfExe) {
    $CurrentExe = $wpfExe.Name
}

$SampleZipHash = ""
$ManifestContent = @{
    version = "1.0.1"
    packageName = "MyCompanyApp.OfflineUpdate.Sample.zip"
    sha256 = ""
    changelog = "Sample offline update package generated locally for testing."
    force = $false
    entryExe = $CurrentExe
} | ConvertTo-Json -Depth 5

Write-Utf8NoBom -Path $ManifestPath -Content $ManifestContent
Write-Ok "Manifest created: $ManifestPath"

# Create zip
New-ZipFromFolder -SourceFolder $SamplePackageRoot -ZipPath $SampleZipPath

# Calculate SHA256 and update manifest
$SampleZipHash = New-Sha256 -FilePath $SampleZipPath
Write-Info "SHA256: $SampleZipHash"

$ManifestContent2 = @{
    version = "1.0.1"
    packageName = "MyCompanyApp.OfflineUpdate.Sample.zip"
    sha256 = $SampleZipHash
    changelog = "Sample offline update package generated locally for testing."
    force = $false
    entryExe = $CurrentExe
} | ConvertTo-Json -Depth 5

Write-Utf8NoBom -Path $ManifestPath -Content $ManifestContent2
Write-Ok "Manifest updated with SHA256."

# Recreate zip so manifest inside zip matches hash workflow if needed
New-ZipFromFolder -SourceFolder $SamplePackageRoot -ZipPath $SampleZipPath

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Offline update pipeline finished successfully" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "Sample ZIP: $SampleZipPath" -ForegroundColor Yellow
Write-Host "Updater publish: $(Join-Path $PublishRoot "UpdaterPublish")" -ForegroundColor Yellow
Write-Host "WPF build: $(Join-Path $PublishRoot "Wpf")" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next step: connect a button/menu in your WPF UI to open OfflineUpdateWindow." -ForegroundColor Cyan
