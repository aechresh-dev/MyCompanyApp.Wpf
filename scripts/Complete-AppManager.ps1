<#
.SYNOPSIS
    Professional App Manager for MyCompanyApp.Wpf
    Handle Build, Update, and Execution.
#>

$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$InstallDir  = "C:\MyApp"
$PublishDir  = Join-Path $ProjectRoot "Publish"
$PackagePath = Join-Path $ProjectRoot "MyCompanyApp.Wpf.update.mya"
$SevenZip    = "C:\Program Files\7-Zip\7z.exe"
$AppName     = "MyCompanyApp.Wpf.exe"

function Show-Welcome {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   MyCompanyApp Manager - Amir Edition" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Invoke-BuildPackage {
    Write-Host "[*] Starting Build Process..." -ForegroundColor Yellow
    
    if (-not (Test-Path $PublishDir)) {
        Write-Error "Publish directory not found! Please Publish in VS first."
        return
    }

    # Clean old package
    if (Test-Path $PackagePath) { Remove-Item $PackagePath -Force }

    # Create Manifest simple (Avoiding complex XML parsing to prevent ItemGroup errors)
    $Manifest = @{
        BuildDate = (Get-Date).ToString()
        Version   = "1.0.0"
        Files     = (Get-ChildItem $PublishDir -Recurse).Count
    }
    $Manifest | ConvertTo-Json | Out-File (Join-Path $PublishDir "manifest.json")

    # Zip with 7Zip
    $Args = "a `"$PackagePath`" `"$PublishDir\*`" -tzip -mx9"
    Start-Process $SevenZip -ArgumentList $Args -Wait -NoNewWindow
    
    Write-Host "[OK] Package created: $PackagePath" -ForegroundColor Green
}

function Invoke-RunUpdate {
    Write-Host "[*] Starting Update and Run..." -ForegroundColor Yellow

    if (-not (Test-Path $PackagePath)) {
        Write-Error "Package not found at $PackagePath"
        return
    }

    # Prepare Install Dir
    if (-not (Test-Path $InstallDir)) { New-Item $InstallDir -ItemType Directory }

    # Extract
    Write-Host "[>] Extracting files..." -ForegroundColor Gray
    $Args = "x `"$PackagePath`" -o`"$InstallDir`" -y"
    Start-Process $SevenZip -ArgumentList $Args -Wait -NoNewWindow

    # Find EXE (Smart Search)
    $ExeFiles = Get-ChildItem -Path $InstallDir -Filter $AppName -Recurse | Sort-Object Length -Descending
    
    if ($ExeFiles) {
        $FinalExe = $ExeFiles[0].FullName
        Write-Host "[OK] Running: $FinalExe" -ForegroundColor Green
        Start-Process $FinalExe -WorkingDirectory (Split-Path $FinalExe)
    } else {
        Write-Error "Could not find $AppName in $InstallDir"
    }
}

# --- Main Logic ---
Show-Welcome
Write-Host "1. Build Update Package (.mya)"
Write-Host "2. Install/Update and Run App"
Write-Host "3. Exit"
$Choice = Read-Host "Select an option"

switch ($Choice) {
    "1" { Invoke-BuildPackage }
    "2" { Invoke-RunUpdate }
    "3" { exit }
    default { Write-Host "Invalid Choice" -ForegroundColor Red }
}
