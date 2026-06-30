$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectPath = 'G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf'
$LogDir      = Join-Path $ProjectPath 'artifacts\logs'
$TimeStamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile     = Join-Path $LogDir "build_run_$TimeStamp.log"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message,[string]$Color='White')
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line
}

try {
    Write-Log "========== MyCompanyApp.Wpf | Build & Run ==========" 'Cyan'

    if (-not (Test-Path $ProjectPath)) { throw "مسیر پروژه پیدا نشد: $ProjectPath" }

    Set-Location $ProjectPath
    Write-Log "Project Path: $ProjectPath" 'Yellow'
    Write-Log "Log File: $LogFile" 'DarkGray'

    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCmd) { throw ".NET SDK نصب نیست یا dotnet در PATH در دسترس نیست." }

    $sdkVersion = & dotnet --version 2>&1
    Write-Log ".NET SDK Version: $sdkVersion" 'Green'

    $solution = Get-ChildItem -Path $ProjectPath -Filter *.sln -File | Select-Object -First 1
    $allProjects = Get-ChildItem -Path $ProjectPath -Recurse -Filter *.csproj -File

    if ($solution) {
        $buildTarget = $solution.FullName
        Write-Log "Solution found: $($solution.FullName)" 'Yellow'
    } else {
        $firstProject = $allProjects | Select-Object -First 1
        if (-not $firstProject) { throw "هیچ فایل .sln یا .csproj پیدا نشد." }
        $buildTarget = $firstProject.FullName
        Write-Log "No solution found. Using project: $($firstProject.FullName)" 'Yellow'
    }

    $runProject = $allProjects | Where-Object { $_.Name -notmatch 'Test|Tests' } | Select-Object -First 1
    if (-not $runProject) { $runProject = $allProjects | Select-Object -First 1 }
    if (-not $runProject) { throw "هیچ فایل csproj برای اجرا پیدا نشد." }

    Write-Log "Run Project: $($runProject.FullName)" 'Yellow'

    Write-Log "[1/4] Restore started..." 'Cyan'
    & dotnet restore $buildTarget *>&1 | Tee-Object -FilePath $LogFile -Append
    if ($LASTEXITCODE -ne 0) { throw "Restore ناموفق بود." }
    Write-Log "Restore completed successfully." 'Green'

    Write-Log "[2/4] Clean started..." 'Cyan'
    & dotnet clean $buildTarget -c Release *>&1 | Tee-Object -FilePath $LogFile -Append
    if ($LASTEXITCODE -ne 0) { throw "Clean ناموفق بود." }
    Write-Log "Clean completed successfully." 'Green'

    Write-Log "[3/4] Build started..." 'Cyan'
    & dotnet build $buildTarget -c Release --no-restore *>&1 | Tee-Object -FilePath $LogFile -Append
    if ($LASTEXITCODE -ne 0) { throw "Build ناموفق بود." }
    Write-Log "Build completed successfully." 'Green'

    Write-Log "[4/4] Run started in separate process..." 'Cyan'
    $runArgs = "run --project `"$($runProject.FullName)`" -c Release --no-build"
    Start-Process -FilePath "dotnet" -ArgumentList $runArgs -WorkingDirectory $ProjectPath

    Write-Log "Application started successfully in separate process." 'Green'
    Write-Log "PowerShell window remains open." 'Green'
    Write-Log "========== DONE ==========" 'Cyan'
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" 'Red'
    Write-Log "جزئیات کامل در لاگ ذخیره شد: $LogFile" 'Yellow'
}

Write-Host ""
Write-Host "برای بستن این پنجره Enter بزن..." -ForegroundColor DarkGray
Read-Host
