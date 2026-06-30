$ErrorActionPreference = "Stop"

Write-Host "======================================="
Write-Host " MyCompanyApp Offline Update Builder"
Write-Host "======================================="

# --------------------------------------------------
# Paths
# --------------------------------------------------

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = "$Root\src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$PublishDir = "$Root\Publish"
$UpdateWork = "$Root\UpdateWork"
$OutputDir = "$Root\InstallerPackage\updates"

# --------------------------------------------------
# Version
# --------------------------------------------------

$Version = Get-Date -Format "yyyy.MM.dd.HHmm"

# --------------------------------------------------
# Cleanup
# --------------------------------------------------

Write-Host "Cleaning old folders..."

Remove-Item $PublishDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $UpdateWork -Recurse -Force -ErrorAction SilentlyContinue

New-Item $PublishDir -ItemType Directory | Out-Null
New-Item $UpdateWork -ItemType Directory | Out-Null
New-Item $OutputDir -ItemType Directory -Force | Out-Null

# --------------------------------------------------
# Publish
# --------------------------------------------------

Write-Host "Publishing application..."

dotnet publish $Project `
    -c Release `
    -r win-x64 `
    --self-contained false `
    -o $PublishDir

Write-Host "Publish completed."

# --------------------------------------------------
# Create app.zip
# --------------------------------------------------

$AppZip = "$UpdateWork\app.zip"

Write-Host "Creating application package..."

Compress-Archive `
    -Path "$PublishDir\*" `
    -DestinationPath $AppZip `
    -Force

# --------------------------------------------------
# Generate SHA256
# --------------------------------------------------

Write-Host "Generating SHA256..."

$Hash = Get-FileHash $AppZip -Algorithm SHA256
$HashFile = "$UpdateWork\app.zip.sha256"

$Hash.Hash | Out-File $HashFile -Encoding ascii

# --------------------------------------------------
# Create update.json
# --------------------------------------------------

Write-Host "Creating update manifest..."

$Manifest = @{
    product = "MyCompanyApp"
    version = $Version
    releaseDate = (Get-Date).ToString("yyyy-MM-dd")
    package = "app.zip"
    hash = "app.zip.sha256"
}

$Manifest | ConvertTo-Json -Depth 5 | Out-File "$UpdateWork\update.json" -Encoding utf8

# --------------------------------------------------
# Create MCU package
# --------------------------------------------------

$MCU = "$OutputDir\MyCompanyApp-$Version.mcu"

Write-Host "Building MCU update package..."

Compress-Archive `
    -Path "$UpdateWork\*" `
    -DestinationPath $MCU `
    -Force

# --------------------------------------------------
# Finish
# --------------------------------------------------

Write-Host ""
Write-Host "======================================="
Write-Host " Update Package Created Successfully"
Write-Host "======================================="
Write-Host ""
Write-Host "Version: $Version"
Write-Host "File:"
Write-Host $MCU
Write-Host ""
