$ErrorActionPreference="Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Solution = Join-Path $Root "MyCompanyApp.sln"

Write-Host ""
Write-Host "=== CLEAN BUILD ===" -ForegroundColor Cyan
Write-Host ""

# delete bin/obj
Get-ChildItem $Root -Recurse -Directory |
Where-Object { $_.Name -eq "bin" -or $_.Name -eq "obj" } |
ForEach-Object {
 Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Restore..."
dotnet restore $Solution

if($LASTEXITCODE -ne 0){
 throw "restore failed"
}

Write-Host "Build..."
dotnet build $Solution -c Debug --no-restore

if($LASTEXITCODE -ne 0){
 throw "build failed"
}

Write-Host "Test..."
dotnet test $Solution -c Debug --no-build

Write-Host ""
Write-Host "BUILD SUCCESSFUL" -ForegroundColor Green
