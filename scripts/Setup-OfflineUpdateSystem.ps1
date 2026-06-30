$ErrorActionPreference="Stop"

Write-Host ""
Write-Host "=== MyCompany Offline Update System Setup ===" -ForegroundColor Cyan

$Root = Get-Location

$ValidatorFile = Join-Path $Root "ValidateUpdate.ps1"
$UpdaterFile = Join-Path $Root "MyCompanyApp.Updater.ps1"
$CmdFile = Join-Path $Root "RunUpdate.cmd"

# -----------------------------
# VALIDATOR
# -----------------------------

$ValidatorContent = @'
param(
    [Parameter(Mandatory=$true)]
    [string]$Package
)

$ErrorActionPreference="Stop"

$temp = Join-Path $env:TEMP "UpdateCheck"

try{

    if(!(Test-Path $Package)){
        Write-Output "INVALID"
        exit
    }

    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

    Expand-Archive $Package -DestinationPath $temp -Force

    $manifest = Join-Path $temp "manifest.json"
    $checksums = Join-Path $temp "checksums.sha256"

    if(!(Test-Path $manifest) -or !(Test-Path $checksums)){
        Write-Output "INVALID"
        exit
    }

    $lines = Get-Content $checksums

    foreach($line in $lines){

        $parts = $line.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)

        $expectedHash = $parts[0]
        $file = Join-Path $temp $parts[1]

        if(!(Test-Path $file)){
            Write-Output "INVALID"
            exit
        }

        $actual = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()

        if($actual -ne $expectedHash){
            Write-Output "INVALID"
            exit
        }
    }

    Remove-Item $temp -Recurse -Force

    Write-Output "VALID"
}
catch{

    Write-Output "INVALID"
}
'@

Set-Content $ValidatorFile $ValidatorContent -Encoding UTF8
Write-Host "Created ValidateUpdate.ps1"

# -----------------------------
# UPDATER
# -----------------------------

$UpdaterContent = @'
param(
    [Parameter(Mandatory=$true)]
    [string]$Package
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $AppDir "backup"
$TempDir = Join-Path $env:TEMP "MyAppUpdate"

function Rollback {
    if (Test-Path $BackupDir) {
        Copy-Item "$BackupDir\*" $AppDir -Recurse -Force
        Remove-Item $BackupDir -Recurse -Force
    }
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "MyCompanyApp Updater"
$Form.Size = New-Object System.Drawing.Size(500,200)
$Form.StartPosition = "CenterScreen"

$Label = New-Object System.Windows.Forms.Label
$Label.Size = New-Object System.Drawing.Size(450,30)
$Label.Location = New-Object System.Drawing.Point(20,20)
$Form.Controls.Add($Label)

$Progress = New-Object System.Windows.Forms.ProgressBar
$Progress.Size = New-Object System.Drawing.Size(450,30)
$Progress.Location = New-Object System.Drawing.Point(20,60)
$Form.Controls.Add($Progress)

$Form.Add_Shown({

    try {

        $Label.Text = "در حال استخراج فایل بروزرسانی..."
        $Progress.Value = 10

        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive $Package -DestinationPath $TempDir -Force

        $Progress.Value = 30

        $Label.Text = "در حال ایجاد نسخه پشتیبان..."
        Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $BackupDir | Out-Null
        Copy-Item "$AppDir\*" $BackupDir -Recurse -Force

        $Progress.Value = 50

        $Label.Text = "در حال جایگزینی فایل‌ها..."
        Copy-Item "$TempDir\*" $AppDir -Recurse -Force

        $Progress.Value = 80

        Remove-Item $TempDir -Recurse -Force
        Remove-Item $BackupDir -Recurse -Force

        $Progress.Value = 100
        $Label.Text = "بروزرسانی با موفقیت انجام شد"

        Start-Sleep -Seconds 2
        $Form.Close()

        Start-Process "$AppDir\MyCompanyApp.exe"

    }
    catch {

        $Label.Text = "خطا رخ داد. بازگردانی نسخه قبلی..."

        Rollback

        Start-Sleep -Seconds 2
        $Form.Close()

        Start-Process "$AppDir\MyCompanyApp.exe"
    }

})

[System.Windows.Forms.Application]::EnableVisualStyles()
$Form.ShowDialog()
'@

Set-Content $UpdaterFile $UpdaterContent -Encoding UTF8
Write-Host "Created MyCompanyApp.Updater.ps1"

# -----------------------------
# CMD
# -----------------------------

$CmdContent = @'
@echo off
echo Running MyCompanyApp Update...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MyCompanyApp.Updater.ps1" %*
pause
'@

Set-Content $CmdFile $CmdContent -Encoding ASCII
Write-Host "Created RunUpdate.cmd"

Write-Host ""
Write-Host "Offline Update System Created Successfully." -ForegroundColor Green
