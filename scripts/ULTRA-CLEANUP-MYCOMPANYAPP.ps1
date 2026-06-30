param(
    [string]$Root = "."
)

$ErrorActionPreference = "SilentlyContinue"
$Root = Resolve-Path $Root

Write-Host ""
Write-Host "============================================"
Write-Host "   MYCOMPANYAPP ULTRA CLEANUP ENGINE"
Write-Host "============================================"
Write-Host "Root:" $Root
Write-Host ""

# ------------------------------------------------
# 1 REMOVE BUILD ARTIFACTS
# ------------------------------------------------
Write-Host "Cleaning build artifacts..."
Get-ChildItem $Root -Recurse -Directory -Include bin,obj |
Remove-Item -Recurse -Force

# ------------------------------------------------
# 2 REMOVE PUBLISH OUTPUT
# ------------------------------------------------
if (Test-Path "$Root\artifacts") {
    Remove-Item "$Root\artifacts" -Recurse -Force
}

# ------------------------------------------------
# 3 REMOVE BACKUPS (ALL RECURSIVE)
# ------------------------------------------------
Write-Host "Removing backup folders..."
Get-ChildItem $Root -Recurse -Directory |
Where-Object {
    $_.Name -like "backup*" -or
    $_.Name -like "_backup*" -or
    $_.Name -like "WPF_Cleanup_Backup*" -or
    $_.FullName -match "backup-before-hr-cleanup"
} |
Remove-Item -Recurse -Force

# ------------------------------------------------
# 4 REMOVE LEGACY WPF
# ------------------------------------------------
if (Test-Path "$Root\legacy") {
    Remove-Item "$Root\legacy" -Recurse -Force
}

# ------------------------------------------------
# 5 REMOVE OLD STRUCTURE
# Keep ONLY src/MyCompanyApp.*
# ------------------------------------------------
$srcPath = "$Root\src"

if (Test-Path $srcPath) {

    Get-ChildItem $srcPath -Directory |
    Where-Object {
        $_.Name -notmatch "^MyCompanyApp\."
    } |
    ForEach-Object {
        Write-Host "Removing duplicate project folder:" $_.FullName
        Remove-Item $_.FullName -Recurse -Force
    }
}

# ------------------------------------------------
# 6 REMOVE EXTRA ROOT PROJECTS (KEEP src ONLY)
# ------------------------------------------------
Get-ChildItem $Root -Directory |
Where-Object {
    $_.Name -match "^MyCompanyApp\." -and
    $_.FullName -notmatch "\\src\\"
} |
Remove-Item -Recurse -Force

# ------------------------------------------------
# 7 REMOVE ALL SOLUTIONS
# ------------------------------------------------
Get-ChildItem $Root -Filter *.sln |
Remove-Item -Force

# ------------------------------------------------
# 8 REGENERATE CLEAN SOLUTION
# ------------------------------------------------
Write-Host "Generating clean solution..."

dotnet new sln -n MyCompanyApp

Get-ChildItem "$Root\src" -Recurse -Filter *.csproj |
ForEach-Object {
    dotnet sln add $_.FullName
}

if (Test-Path "$Root\tests") {
    Get-ChildItem "$Root\tests" -Recurse -Filter *.csproj |
    ForEach-Object {
        dotnet sln add $_.FullName
    }
}

# ------------------------------------------------
# 9 RESTORE & BUILD
# ------------------------------------------------
Write-Host ""
Write-Host "Running restore..."
dotnet restore

Write-Host ""
Write-Host "Running build..."
dotnet build -c Release

Write-Host ""
Write-Host "============================================"
Write-Host " ✅ ULTRA CLEANUP COMPLETE"
Write-Host "============================================"
Write-Host ""
