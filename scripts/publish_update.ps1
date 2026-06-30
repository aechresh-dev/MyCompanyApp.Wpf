param(
[string]$version
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$publishDir = "$root\Publish\$version"

dotnet publish "$root\src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj" `
-c Release `
-o $publishDir `
-r win-x64 `
--self-contained false

Compress-Archive $publishDir "$root\Publish\update.zip" -Force

Write-Host "Publish completed"
