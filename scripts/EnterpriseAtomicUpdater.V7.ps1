[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$CreatePackage,
    [switch]$Install,
    [switch]$Rollback,
    [switch]$HealthCheck,
    [switch]$ShowReleaseNotes,
    [switch]$Clean,
    [string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host "[$Title]" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor DarkGray
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Get-ScriptRootSafe {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    return (Get-Location).Path
}

$ScriptRoot = Get-ScriptRootSafe

$EngineScriptPath = Join-Path $ScriptRoot 'EnterpriseAtomicUpdater.V6.ps1'

$InstallRoot      = 'G:\Program Files\MyCompanyApp'
$VersionsRoot     = Join-Path $InstallRoot 'versions'
$CurrentLinkPath  = Join-Path $InstallRoot 'current.txt'
$PreviousLinkPath = Join-Path $InstallRoot 'previous.txt'

$ProgramDataRoot  = 'G:\ProgramData\MyCompanyApp'
$BackupRoot       = Join-Path $ProgramDataRoot 'PreUpdateBackups'
$LogRoot          = Join-Path $ProgramDataRoot 'Logs'
$LockPath         = Join-Path $ProgramDataRoot 'update.lock'

$BackupRetention  = 10

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Read-LinkText {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    $text = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text.Trim()
}

function Get-DirectorySizeBytes {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return 0
    }

    $sum = 0L

    Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
        $sum += $_.Length
    }

    return $sum
}

function Get-FileCountSafe {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return 0
    }

    return @(Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue).Count
}

function Test-FreeSpaceForBackup {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )

    if (-not (Test-Path $SourcePath)) {
        Write-Warn "Install root does not exist yet. Backup space check skipped."
        return
    }

    $sourceSize = Get-DirectorySizeBytes -Path $SourcePath
    $requiredBytes = [int64]($sourceSize * 1.25 + 512MB)

    $targetRoot = [System.IO.Path]::GetPathRoot($TargetPath)
    $driveName = $targetRoot.TrimEnd('\').TrimEnd(':')

    $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    if (-not $drive) {
        Write-Warn "Could not detect drive $driveName for backup free-space check."
        return
    }

    $freeBytes = [int64]$drive.Free
    $sourceGB = [math]::Round($sourceSize / 1GB, 2)
    $requiredGB = [math]::Round($requiredBytes / 1GB, 2)
    $freeGB = [math]::Round($freeBytes / 1GB, 2)

    Write-Info "Current install size: $sourceGB GB"
    Write-Info "Estimated backup space required: $requiredGB GB"
    Write-Info "Free space on drive $driveName : $freeGB GB"

    if ($freeBytes -lt $requiredBytes) {
        throw "Not enough free disk space for pre-update backup. Required=$requiredGB GB, Available=$freeGB GB"
    }
}

function New-PreUpdateBackup {
    Write-Section "Pre-Update Backup"

    Ensure-Directory -Path $ProgramDataRoot
    Ensure-Directory -Path $BackupRoot
    Ensure-Directory -Path $LogRoot

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $BackupRoot "PreUpdateBackup_$timestamp"

    Ensure-Directory -Path $backupPath

    $currentVersion = Read-LinkText -Path $CurrentLinkPath
    $previousVersion = Read-LinkText -Path $PreviousLinkPath

    if ([string]::IsNullOrWhiteSpace($currentVersion)) {
        $currentVersion = ''
    }

    if ([string]::IsNullOrWhiteSpace($previousVersion)) {
        $previousVersion = ''
    }

    Test-FreeSpaceForBackup -SourcePath $InstallRoot -TargetPath $BackupRoot

    $manifest = [ordered]@{
        BackupType      = 'PreUpdateFullBackup'
        CreatedAtLocal  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        CreatedAtUtc    = (Get-Date).ToUniversalTime().ToString('o')
        MachineName     = $env:COMPUTERNAME
        UserName        = $env:USERNAME
        InstallRoot     = $InstallRoot
        VersionsRoot    = $VersionsRoot
        CurrentVersion  = $currentVersion
        PreviousVersion = $previousVersion
        BackupPath      = $backupPath
        EngineScript    = $EngineScriptPath
        OfflineMode     = $true
    }

    $manifestPath = Join-Path $backupPath 'backup-manifest.json'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

    if (Test-Path $InstallRoot) {
        Write-Info "Creating full pre-update backup:"
        Write-Info $backupPath

        $installBackupPath = Join-Path $backupPath 'InstallRoot'
        Ensure-Directory -Path $installBackupPath

        Get-ChildItem -Path $InstallRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $installBackupPath -Recurse -Force -ErrorAction Stop
        }

        $fileCount = Get-FileCountSafe -Path $installBackupPath
        $backupSizeBytes = Get-DirectorySizeBytes -Path $installBackupPath
        $backupSizeGB = [math]::Round($backupSizeBytes / 1GB, 3)

        $summary = [ordered]@{
            BackupCompletedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            FileCount            = $fileCount
            BackupSizeBytes      = $backupSizeBytes
            BackupSizeGB         = $backupSizeGB
            Status               = 'Completed'
        }

        $summary | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $backupPath 'backup-summary.json') -Encoding UTF8

        Write-Success "Pre-update backup completed"
        Write-Info "Backup file count: $fileCount"
        Write-Info "Backup size: $backupSizeGB GB"
    }
    else {
        Write-Warn "Install root does not exist. This looks like a first install. Empty backup manifest created."
        $summary = [ordered]@{
            BackupCompletedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            FileCount            = 0
            BackupSizeBytes      = 0
            BackupSizeGB         = 0
            Status               = 'SkippedBecauseInstallRootDoesNotExist'
        }

        $summary | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $backupPath 'backup-summary.json') -Encoding UTF8
    }

    Remove-OldPreUpdateBackups

    return $backupPath
}

function Remove-OldPreUpdateBackups {
    if (-not (Test-Path $BackupRoot)) {
        return
    }

    $dirs = @(Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending)

    if ($dirs.Count -le $BackupRetention) {
        return
    }

    $dirs | Select-Object -Skip $BackupRetention | ForEach-Object {
        Write-Info "Removing old pre-update backup: $($_.FullName)"
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Acquire-UpdateLock {
    Write-Section "Update Lock"

    Ensure-Directory -Path $ProgramDataRoot

    if (Test-Path $LockPath) {
        $lockText = Get-Content -Path $LockPath -Raw -ErrorAction SilentlyContinue
        Write-Warn "Existing update lock detected:"
        Write-Warn $LockPath

        if (-not [string]::IsNullOrWhiteSpace($lockText)) {
            Write-Warn $lockText
        }

        throw "Another update operation may already be running. Lock file exists: $LockPath"
    }

    $lockData = [ordered]@{
        CreatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        MachineName  = $env:COMPUTERNAME
        UserName     = $env:USERNAME
        ProcessId    = $PID
        Script       = $PSCommandPath
    }

    $lockData | ConvertTo-Json -Depth 10 | Set-Content -Path $LockPath -Encoding UTF8

    Write-Success "Update lock acquired"
}

function Release-UpdateLock {
    if (Test-Path $LockPath) {
        Remove-Item -Path $LockPath -Force -ErrorAction SilentlyContinue
        Write-Success "Update lock released"
    }
}

function Assert-EngineExists {
    if (-not (Test-Path $EngineScriptPath)) {
        throw "Updater engine not found: $EngineScriptPath"
    }
}

function Invoke-Engine {
    Assert-EngineExists

    $argsList = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', $EngineScriptPath
    )

    if ($Build) {
        $argsList += '-Build'
    }

    if ($CreatePackage) {
        $argsList += '-CreatePackage'
    }

    if ($Install) {
        $argsList += '-Install'
    }

    if ($Rollback) {
        $argsList += '-Rollback'
    }

    if ($HealthCheck) {
        $argsList += '-HealthCheck'
    }

    if ($ShowReleaseNotes) {
        $argsList += '-ShowReleaseNotes'
    }

    if ($Clean) {
        $argsList += '-Clean'
    }

    if (-not [string]::IsNullOrWhiteSpace($Configuration)) {
        $argsList += '-Configuration'
        $argsList += $Configuration
    }

    Write-Section "Run Updater Engine"
    Write-Info "Engine: $EngineScriptPath"
    Write-Info "Offline note: Install/Rollback/HealthCheck do not need internet. Build/Restore may need local NuGet cache if packages are not already restored."

    & powershell.exe @argsList

    $exitCode = $LASTEXITCODE

    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    if ($exitCode -ne 0) {
        throw "Updater engine failed with exit code $exitCode"
    }

    Write-Success "Updater engine completed successfully"
}

try {
    Ensure-Directory -Path $ProgramDataRoot
    Ensure-Directory -Path $BackupRoot
    Ensure-Directory -Path $LogRoot

    $needsLock = $Build -or $CreatePackage -or $Install -or $Rollback -or $Clean

    if ($needsLock) {
        Acquire-UpdateLock
    }

    if ($Install) {
        $backupPath = New-PreUpdateBackup
        Write-Info "Pre-update backup path: $backupPath"
    }

    Invoke-Engine

    Write-Success "V7 wrapper completed successfully."
}
catch {
    Write-Fail $_.Exception.Message
    throw
}
finally {
    if ($Build -or $CreatePackage -or $Install -or $Rollback -or $Clean) {
        Release-UpdateLock
    }
}
