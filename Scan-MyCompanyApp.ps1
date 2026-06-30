param(
    [string]$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf",
    [string]$ZipPath     = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\New Compressed (zipped) Folder.zip",
    [switch]$Build,
    [switch]$Run
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 90) -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 90) -ForegroundColor DarkGray
}

function Ensure-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }
}

function Get-TextSafe {
    param([string]$Path)
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-ZipListing {
    param([string]$ZipFile)
    Ensure-Path $ZipFile

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
    try {
        $entries = foreach ($e in $zip.Entries) {
            [pscustomobject]@{
                FullName = $e.FullName
                Name     = $e.Name
                Length   = $e.Length
            }
        }
        return $entries
    }
    finally {
        $zip.Dispose()
    }
}

function Get-ProjectTree {
    param([string]$RootPath)
    Ensure-Path $RootPath

    $files = Get-ChildItem -LiteralPath $RootPath -Recurse -File | ForEach-Object {
        [pscustomobject]@{
            FullName = $_.FullName
            Name     = $_.Name
            Ext      = $_.Extension
        }
    }
    return $files
}

function Find-ProjectFiles {
    param($Items)

    $appFiles = $Items | Where-Object { $_.Name -ieq "App.xaml.cs" } | Sort-Object FullName
    $slnFiles = $Items | Where-Object { $_.Name -like "*.sln" } | Sort-Object FullName
    $csprojFiles = $Items | Where-Object { $_.Name -like "*.csproj" } | Sort-Object FullName

    [pscustomobject]@{
        AppXamlCs = $appFiles
        SlnFiles  = $slnFiles
        CsprojFiles = $csprojFiles
    }
}

function Find-ActiveAppFile {
    param(
        [object[]]$AppFiles,
        [object[]]$CsprojFiles,
        [string]$RootPath
    )

    $active = $null

    foreach ($proj in $CsprojFiles) {
        if ($proj.FullName -like "*MyCompanyApp.Wpf.csproj") {
            $projDir = Split-Path -Parent $proj.FullName
            $candidate = Join-Path $projDir "App.xaml.cs"
            if (Test-Path -LiteralPath $candidate) {
                $active = $candidate
                break
            }
        }
    }

    if (-not $active -and $AppFiles.Count -gt 0) {
        $active = $AppFiles[0].FullName
    }

    return $active
}

function Show-List {
    param(
        [string]$Label,
        [object[]]$Items,
        [scriptblock]$Formatter
    )
    Write-Section $Label
    if (-not $Items -or $Items.Count -eq 0) {
        Write-Host "(none found)" -ForegroundColor Yellow
        return
    }

    foreach ($item in $Items) {
        & $Formatter $item
    }
}

function Build-Project {
    param([string]$CsprojPath)

    Write-Section "RESTORE"
    dotnet restore "$CsprojPath"

    Write-Section "BUILD"
    dotnet build "$CsprojPath" -c Debug
}

function Run-Project {
    param([string]$CsprojPath)

    Write-Section "RUN"
    dotnet run --project "$CsprojPath" -c Debug
}

# ---------------- MAIN ----------------

Write-Section "INPUT CHECK"
Write-Host "ProjectRoot : $ProjectRoot"
Write-Host "ZipPath     : $ZipPath"
Write-Host "Build       : $Build"
Write-Host "Run         : $Run"

$sourceItems = $null
$sourceKind = $null

if (Test-Path -LiteralPath $ProjectRoot) {
    $sourceItems = Get-ProjectTree -RootPath $ProjectRoot
    $sourceKind = "ProjectTree"
}
elseif (Test-Path -LiteralPath $ZipPath) {
    $sourceItems = Get-ZipListing -ZipFile $ZipPath
    $sourceKind = "ZipListing"
}
else {
    throw "Neither ProjectRoot nor ZipPath exists."
}

Write-Section "SOURCE KIND"
Write-Host $sourceKind -ForegroundColor Green

$found = Find-ProjectFiles -Items $sourceItems
$activeApp = Find-ActiveAppFile -AppFiles $found.AppXamlCs -CsprojFiles $found.CsprojFiles -RootPath $ProjectRoot

Write-Section "APP.XAML.CS FILES"
if ($found.AppXamlCs.Count -eq 0) {
    Write-Host "No App.xaml.cs files found." -ForegroundColor Yellow
}
else {
    foreach ($f in $found.AppXamlCs) {
        Write-Host $f.FullName
    }
}

Write-Section "SOLUTION FILES"
if ($found.SlnFiles.Count -eq 0) {
    Write-Host "No .sln files found." -ForegroundColor Yellow
}
else {
    foreach ($f in $found.SlnFiles) {
        Write-Host $f.FullName
    }
}

Write-Section "CSPROJ FILES"
if ($found.CsprojFiles.Count -eq 0) {
    Write-Host "No .csproj files found." -ForegroundColor Yellow
}
else {
    foreach ($f in $found.CsprojFiles) {
        Write-Host $f.FullName
    }
}

Write-Section "ACTIVE APP.XAML.CS"
if ($activeApp) {
    Write-Host $activeApp -ForegroundColor Green
}
else {
    Write-Host "Could not determine active App.xaml.cs" -ForegroundColor Yellow
}

# Report to file
$reportPath = Join-Path $ProjectRoot "docs\AppScanReport.txt"
$reportDir = Split-Path -Parent $reportPath
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$report = @()
$report += "SourceKind: $sourceKind"
$report += ""
$report += "App.xaml.cs files:"
$report += ($found.AppXamlCs | ForEach-Object { $_.FullName })
$report += ""
$report += "Sln files:"
$report += ($found.SlnFiles | ForEach-Object { $_.FullName })
$report += ""
$report += "Csproj files:"
$report += ($found.CsprojFiles | ForEach-Object { $_.FullName })
$report += ""
$report += "ActiveAppXamlCs:"
$report += $activeApp

$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Section "REPORT WRITTEN"
Write-Host $reportPath -ForegroundColor Green

if ($Build -or $Run) {
    $mainCsproj = $found.CsprojFiles | Where-Object { $_.Name -eq "MyCompanyApp.Wpf.csproj" } | Select-Object -First 1
    if (-not $mainCsproj) {
        throw "MyCompanyApp.Wpf.csproj not found, cannot build/run."
    }

    if ($Build) {
        Build-Project -CsprojPath $mainCsproj.FullName
    }

    if ($Run) {
        Run-Project -CsprojPath $mainCsproj.FullName
    }
}
