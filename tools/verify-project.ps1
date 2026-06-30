$ErrorActionPreference="Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Solution = Join-Path $Root "MyCompanyApp.sln"

Write-Host ""
Write-Host "=== PROJECT VERIFICATION ===" -ForegroundColor Cyan
Write-Host ""

function Fail($msg){
 Write-Host "[ERROR] $msg" -ForegroundColor Red
 exit 1
}

function Warn($msg){
 Write-Host "[WARNING] $msg" -ForegroundColor Yellow
}

function Info($msg){
 Write-Host "[INFO] $msg" -ForegroundColor Gray
}

if(!(Test-Path $Solution)){
 Fail "Solution not found"
}

# Collect projects
$projects = Get-ChildItem $Root -Recurse -Filter *.csproj |
Where-Object {
 $_.FullName -notmatch "\\bin\\" -and
 $_.FullName -notmatch "\\obj\\" -and
 $_.FullName -notmatch "_backup" -and
 $_.FullName -notmatch "_quarantine"
}

Info "Projects: $($projects.Count)"

# Duplicate project detection
$groups = $projects | Group-Object Name

foreach($g in $groups){
 if($g.Count -gt 1){
  Warn "Duplicate project: $($g.Name)"
  foreach($p in $g.Group){
   Warn $p.FullName
  }
 }
}

# Domain dependency scan
$domainFiles = Get-ChildItem "$Root\src\MyCompanyApp.Domain" -Recurse -Filter *.cs -ErrorAction SilentlyContinue

foreach($file in $domainFiles){

 $text = Get-Content $file.FullName -Raw

 if($text -match "MyCompanyApp.Application" -or
    $text -match "MyCompanyApp.Infrastructure" -or
    $text -match "MyCompanyApp.Persistence" -or
    $text -match "MyCompanyApp.Reporting" -or
    $text -match "MyCompanyApp.Wpf")
 {
   Fail "Domain layer dependency violation: $($file.FullName)"
 }
}

# Application UI scan
$appFiles = Get-ChildItem "$Root\src\MyCompanyApp.Application" -Recurse -Filter *.cs -ErrorAction SilentlyContinue

foreach($file in $appFiles){

 $text = Get-Content $file.FullName -Raw

 if($text -match "System.Windows" -or
    $text -match "CommandManager" -or
    $text -match "Window" -or
    $text -match "UserControl")
 {
   Fail "WPF code inside Application: $($file.FullName)"
 }
}

# Build validation
Info "Running restore"
dotnet restore $Solution

if($LASTEXITCODE -ne 0){
 Fail "restore failed"
}

Info "Running build"
dotnet build $Solution -c Debug --no-restore

if($LASTEXITCODE -ne 0){
 Fail "build failed"
}

Info "Running tests"
dotnet test $Solution -c Debug --no-build

if($LASTEXITCODE -ne 0){
 Warn "tests failed"
}

Write-Host ""
Write-Host "PROJECT VERIFICATION PASSED" -ForegroundColor Green
