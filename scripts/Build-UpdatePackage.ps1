param(
    [Parameter(Mandatory=$true)]
    [string]$Customer,

    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

Write-Host "========== Enterprise Update Package Builder ==========" -ForegroundColor Cyan
Write-Host "Customer : $Customer"
Write-Host "Version  : $Version"
Write-Host "======================================================="

$root = Get-Location
$publishDir = "$root\artifacts\publish"
$workDir = "$root\artifacts\work"
$packageDir = "$root\Deployment\Packages"

$appProject = "$root\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"

# Clean old artifacts
Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

New-Item $publishDir -ItemType Directory | Out-Null
New-Item $workDir -ItemType Directory | Out-Null
New-Item $packageDir -ItemType Directory -Force | Out-Null

Write-Host "[1/5] Publishing main application..."
dotnet publish $appProject `
    -c Release `
    -r win-x64 `
    --self-contained false `
    -o $publishDir

Write-Host "[2/5] Preparing payload..."
$payloadDir = "$workDir\payload"
New-Item $payloadDir -ItemType Directory | Out-Null
Copy-Item "$publishDir\*" $payloadDir -Recurse

Write-Host "[3/5] Generating metadata.json..."
$metadata = @{
    product = "MyCompanyApp"
    customer = $Customer
    version = $Version
    buildDateUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$metadataPath = "$workDir\metadata.json"
$metadata | ConvertTo-Json -Depth 5 | Set-Content $metadataPath -Encoding UTF8

Write-Host "[4/5] Generating checksums.sha256..."
$checksumFile = "$workDir\checksums.sha256"
Get-ChildItem $payloadDir -Recurse -File | ForEach-Object {
    $hash = Get-FileHash $_.FullName -Algorithm SHA256
    $relative = $_.FullName.Substring($payloadDir.Length + 1)
    "$($hash.Hash)  $relative" | Out-File $checksumFile -Append -Encoding utf8
}

Write-Host "[5/5] Creating final ZIP package..."
Copy-Item $metadataPath $workDir
Copy-Item $checksumFile $workDir

$finalZip = "$packageDir\MyCompanyApp_${Customer}_Update_v${Version}.zip"

if (Test-Path $finalZip) { Remove-Item $finalZip -Force }

Compress-Archive -Path "$workDir\*" -DestinationPath $finalZip

Write-Host ""
Write-Host "✅ PACKAGE CREATED SUCCESSFULLY:" -ForegroundColor Green
Write-Host $finalZip
