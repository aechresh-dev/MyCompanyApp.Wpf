$ErrorActionPreference = "Continue"

$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$Docs = Join-Path $ProjectRoot "Docs"
$ReportPath = Join-Path $Docs "AI_AUTOMATED_ANALYSIS_REPORT.md"

Write-Host ""
Write-Host "AI Project Analyzer Running..."
Write-Host ""

if (!(Test-Path $Docs)) {
New-Item -ItemType Directory -Path $Docs | Out-Null
}

Write-Host "Scanning solution..."

$Solutions = Get-ChildItem $ProjectRoot -Filter *.sln -Recurse -ErrorAction SilentlyContinue
$Projects = Get-ChildItem $ProjectRoot -Filter *.csproj -Recurse -ErrorAction SilentlyContinue
$CsFiles = Get-ChildItem $ProjectRoot -Filter *.cs -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.FullName -notmatch "\\bin\\|\\obj\\" }

Write-Host "Running restore/build..."

Set-Location $ProjectRoot

$RestoreOutput = dotnet restore 2>&1 | Out-String
$BuildOutput = dotnet build 2>&1 | Out-String

$Lines = @()

$Lines += "# AI_AUTOMATED_ANALYSIS_REPORT"
$Lines += ""
$Lines += "Generated: $(Get-Date)"
$Lines += ""

$Lines += "## Solutions"

if ($Solutions) {
foreach ($s in $Solutions) {
$Lines += "- $($s.FullName)"
}
}
else {
$Lines += "- No solution file found"
}

$Lines += ""

$Lines += "## Projects"

if ($Projects) {
foreach ($p in $Projects) {
$Lines += "- $($p.FullName)"
}
}
else {
$Lines += "- No project file found"
}

$Lines += ""

$Lines += "## CSharp File Count"
$Lines += "$($CsFiles.Count)"
$Lines += ""

$Lines += "## Restore Output"
$Lines += "------------------------------------"
$Lines += $RestoreOutput
$Lines += ""

$Lines += "## Build Output"
$Lines += "------------------------------------"
$Lines += $BuildOutput
$Lines += ""

$Lines += "## AI Architecture Review Checklist"
$Lines += "- Check Platform / Modules / Apps separation"
$Lines += "- Check EF Core infrastructure existence"
$Lines += "- Check SQLite multi-user safety settings"
$Lines += "- Check advanced audit logging design"
$Lines += "- Check MVVM boundaries"
$Lines += "- Check missing database schema decisions"
$Lines += "- Ask clarification questions before coding"

Set-Content $ReportPath $Lines -Encoding UTF8

Write-Host ""
Write-Host "Analysis report created:"
Write-Host $ReportPath
Write-Host ""
