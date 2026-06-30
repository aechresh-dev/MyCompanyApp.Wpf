param(
    [string]$Version = "1.0.1",
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$WpfProject = Join-Path $Root "src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$UpdaterProject = Join-Path $Root "MyCompanyApp.Updater\MyCompanyApp.Updater.csproj"

$PublishRoot = Join-Path $Root "Publish"
$PackageWork = Join-Path $PublishRoot "package_work"
$PayloadDir = Join-Path $PackageWork "payload"
$UpdaterPublish = Join-Path $PublishRoot "updater_publish"

$EntryExe = "MyCompanyApp.Wpf.exe"
$UpdaterExe = "MyCompanyApp.Updater.exe"
$PackageName = "MyCompanyApp_Update_v$Version.zip"
$PackagePath = Join-Path $PublishRoot $PackageName

function Ensure-EmptyDirectory {
    param([string]$Path)

    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-PayloadHash {
    param([string]$PayloadPath)

    $sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        $files = Get-ChildItem -Path $PayloadPath -Recurse -File |
            Sort-Object { $_.FullName.Substring($PayloadPath.Length).TrimStart('\','/').Replace('\','/').ToLowerInvariant() }

        foreach ($file in $files) {
            $relative = $file.FullName.Substring($PayloadPath.Length).TrimStart('\','/').Replace('\','/')

            $nameBytes = [System.Text.Encoding]::UTF8.GetBytes($relative)
            $zero = [byte[]](0)
            $contentBytes = [System.IO.File]::ReadAllBytes($file.FullName)

            [void]$sha.TransformBlock($nameBytes, 0, $nameBytes.Length, $null, 0)
            [void]$sha.TransformBlock($zero, 0, 1, $null, 0)
            [void]$sha.TransformBlock($contentBytes, 0, $contentBytes.Length, $null, 0)
            [void]$sha.TransformBlock($zero, 0, 1, $null, 0)
        }

        [void]$sha.TransformFinalBlock([byte[]]::new(0), 0, 0)
        return ([System.BitConverter]::ToString($sha.Hash)).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

Write-Host "=== Generating Offline Update Package ===" -ForegroundColor Cyan
Write-Host "Version: $Version"
Write-Host "Configuration: $Configuration"

Ensure-EmptyDirectory -Path $PackageWork
Ensure-EmptyDirectory -Path $UpdaterPublish
New-Item -ItemType Directory -Path $PayloadDir -Force | Out-Null

Write-Host "Publishing WPF application..." -ForegroundColor Green
dotnet publish $WpfProject -c $Configuration -o $PayloadDir

Write-Host "Publishing updater..." -ForegroundColor Green
dotnet publish $UpdaterProject -c $Configuration -o $UpdaterPublish

$UpdaterSource = Join-Path $UpdaterPublish $UpdaterExe
if (!(Test-Path $UpdaterSource)) {
    throw "Updater exe not found after publish: $UpdaterSource"
}

Copy-Item $UpdaterSource (Join-Path $PayloadDir $UpdaterExe) -Force

if (!(Test-Path (Join-Path $PayloadDir $EntryExe))) {
    throw "Entry exe not found in payload: $EntryExe"
}

Write-Host "Computing payload SHA256..." -ForegroundColor Yellow
$PayloadHash = Get-PayloadHash -PayloadPath $PayloadDir

$Manifest = [ordered]@{
    version = $Version
    entryExe = $EntryExe
    packageName = $PackageName
    sha256 = $PayloadHash
    createdAtUtc = [DateTime]::UtcNow.ToString("O")
    force = $false
}

$ManifestPath = Join-Path $PackageWork "manifest.json"
$Manifest | ConvertTo-Json -Depth 10 | Set-Content $ManifestPath -Encoding UTF8

if (Test-Path $PackagePath) {
    Remove-Item $PackagePath -Force
}

Write-Host "Creating update zip..." -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $PackageWork "payload"), $ManifestPath -DestinationPath $PackagePath -Force

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "Package: $PackagePath" -ForegroundColor Green
Write-Host "SHA256 : $PayloadHash" -ForegroundColor Green
Write-Host ""
Write-Host "Zip structure:"
Write-Host "  manifest.json"
Write-Host "  payload\..."
