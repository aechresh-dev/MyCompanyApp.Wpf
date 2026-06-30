$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectFile = Join-Path $ProjectRoot "src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$OutputDir   = Join-Path $ProjectRoot "artifacts\publish\win-x64"

if (!(Test-Path $ProjectFile)) {
    Write-Host "Main WPF project not found: $ProjectFile" -ForegroundColor Red
    exit 1
}

dotnet publish $ProjectFile `
    -c Release `
    -r win-x64 `
    --self-contained true `
    /p:PublishSingleFile=false `
    /p:PublishTrimmed=false `
    -o $OutputDir

Write-Host ""
Write-Host "Publish completed: $OutputDir" -ForegroundColor Green
