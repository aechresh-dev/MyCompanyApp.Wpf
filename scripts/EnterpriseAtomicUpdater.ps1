<#
.SYNOPSIS
    Enterprise Offline Atomic Updater for MyCompanyApp.Wpf
    Compatibility: Windows PowerShell 5.1+
    Version: 4.0.0
    Features:
      - Build / Publish / Package / Install
      - Atomic backup + rollback
      - Recovery after crash/power-loss
      - Health check
      - Checksum generation
      - Manifest generation
      - Backup retention
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)][switch]$Build,
    [Parameter(Mandatory=$false)][switch]$CreatePackage,
    [Parameter(Mandatory=$false)][switch]$Install,
    [Parameter(Mandatory=$false)][string]$PackagePath,
    [Parameter(Mandatory=$false)][switch]$Force,

    [string]$RepoRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf",
    [string]$LogDir = "G:\ProgramData\MyCompanyApp\Logs",
    [string]$BackupRoot = "G:\ProgramData\MyCompanyApp\Backups",
    [string]$InstallDir = "G:\Program Files\MyCompanyApp",
    [string]$StagingDirBase = "C:\Temp\MyCompanyApp_Atomic_Stage",
    [int]$BackupRetentionDays = 14
)

# -----------------------------
# Static paths
# -----------------------------
$SolutionPath = Join-Path $RepoRoot "MyCompanyApp.sln"
$WpfProjectPath = Join-Path $RepoRoot "src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$UpdaterProjectPath = Join-Path $RepoRoot "MyCompanyApp.Updater\MyCompanyApp.Updater.csproj"
$DefaultPackageDir = Join-Path $RepoRoot "Publish"
$DefaultPackageName = "update.zip"

$LogFileName = "update.log"
$LockFileName = "update.lock"
$StateFileName = "update.state.json"
$InstallMarkerFileName = "install.ok"
$ManifestFileName = "manifest.json"
$ChecksumFileName = "update.zip.sha256"

$AppExeName = "MyCompanyApp.Wpf.exe"

# -----------------------------
# Helpers
# -----------------------------
function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    Ensure-Directory -Path $LogDir

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$timestamp] [$Level] $Message"
    $logFile = Join-Path $LogDir $LogFileName
    $msg | Out-File -FilePath $logFile -Append -Encoding UTF8

    $color = "White"
    if ($Level -eq "ERROR") {
        $color = "Red"
    }
    elseif ($Level -eq "WARN") {
        $color = "Yellow"
    }
    elseif ($Level -eq "SUCCESS") {
        $color = "Green"
    }
    elseif ($Level -eq "RECOVERY") {
        $color = "Cyan"
    }

    Write-Host $msg -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Assert-PathExists {
    param(
        [Parameter(Mandatory=$true)][string]$PathValue,
        [Parameter(Mandatory=$true)][string]$Description
    )

    if (-not (Test-Path $PathValue)) {
        throw "$Description not found: $PathValue"
    }
}

function Get-StateFilePath {
    Ensure-Directory -Path $LogDir
    return (Join-Path $LogDir $StateFileName)
}

function New-DefaultState {
    return @{
        Version = "4.0.0"
        UpdateInProgress = $false
        CurrentPhase = "Idle"
        StartedAt = $null
        LastUpdatedAt = $null
        BackupPath = $null
        StagingPath = $null
        PackagePath = $null
        InstallDir = $InstallDir
        RecoveryNeeded = $false
        RecoveryReason = $null
        LastError = $null
    }
}

function Save-State {
    param(
        [hashtable]$State
    )

    $State.LastUpdatedAt = (Get-Date).ToString("s")
    $stateFile = Get-StateFilePath
    ($State | ConvertTo-Json -Depth 10) | Out-File -FilePath $stateFile -Encoding UTF8 -Force
}

function Load-State {
    $stateFile = Get-StateFilePath
    if (-not (Test-Path $stateFile)) {
        $state = New-DefaultState
        Save-State -State $state
        return $state
    }

    try {
        $raw = Get-Content -Path $stateFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $state = New-DefaultState
            Save-State -State $state
            return $state
        }

        $obj = $raw | ConvertFrom-Json
        $state = @{}
        $obj.PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value }

        if (-not $state.ContainsKey("Version")) { $state["Version"] = "4.0.0" }
        if (-not $state.ContainsKey("UpdateInProgress")) { $state["UpdateInProgress"] = $false }
        if (-not $state.ContainsKey("CurrentPhase")) { $state["CurrentPhase"] = "Idle" }
        if (-not $state.ContainsKey("BackupPath")) { $state["BackupPath"] = $null }
        if (-not $state.ContainsKey("StagingPath")) { $state["StagingPath"] = $null }
        if (-not $state.ContainsKey("PackagePath")) { $state["PackagePath"] = $null }
        if (-not $state.ContainsKey("InstallDir")) { $state["InstallDir"] = $InstallDir }
        if (-not $state.ContainsKey("RecoveryNeeded")) { $state["RecoveryNeeded"] = $false }
        if (-not $state.ContainsKey("RecoveryReason")) { $state["RecoveryReason"] = $null }
        if (-not $state.ContainsKey("LastError")) { $state["LastError"] = $null }

        return $state
    }
    catch {
        Write-Log "State file is corrupt. Recreating default state." "WARN"
        $state = New-DefaultState
        $state.RecoveryNeeded = $true
        $state.RecoveryReason = "Corrupt state file detected"
        Save-State -State $state
        return $state
    }
}

function Set-StatePhase {
    param(
        [hashtable]$State,
        [string]$Phase
    )

    $State.CurrentPhase = $Phase
    $State.UpdateInProgress = $true
    if (-not $State.StartedAt) {
        $State.StartedAt = (Get-Date).ToString("s")
    }
    Save-State -State $State
}

function Complete-State {
    param([hashtable]$State)

    $State.UpdateInProgress = $false
    $State.CurrentPhase = "Completed"
    $State.RecoveryNeeded = $false
    $State.RecoveryReason = $null
    $State.LastError = $null
    Save-State -State $State
}

function Fail-State {
    param(
        [hashtable]$State,
        [string]$ErrorMessage,
        [string]$Phase
    )

    $State.UpdateInProgress = $true
    $State.CurrentPhase = $Phase
    $State.RecoveryNeeded = $true
    $State.RecoveryReason = "Previous execution stopped unexpectedly during phase: $Phase"
    $State.LastError = $ErrorMessage
    Save-State -State $State
}

function Reset-State {
    param([hashtable]$State)

    $newState = New-DefaultState
    $State.Clear()
    foreach ($k in $newState.Keys) {
        $State[$k] = $newState[$k]
    }
    Save-State -State $State
}

function Lock-Update {
    Ensure-Directory -Path $InstallDir
    $lockFile = Join-Path $InstallDir $LockFileName

    if ((Test-Path $lockFile) -and (-not $Force)) {
        throw "Update process is locked. Existing lock file: $lockFile"
    }

    Get-Date | Out-File -FilePath $lockFile -Encoding UTF8
}

function Unlock-Update {
    $lockFile = Join-Path $InstallDir $LockFileName
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-LatestPublishDirectory {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectDirectory
    )

    $binReleasePath = Join-Path $ProjectDirectory "bin\Release"
    if (-not (Test-Path $binReleasePath)) {
        return $null
    }

    $publishDirs = Get-ChildItem -Path $binReleasePath -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "publish" } |
        Sort-Object LastWriteTime -Descending

    if ($publishDirs -and $publishDirs.Count -gt 0) {
        return $publishDirs[0].FullName
    }

    return $null
}

function Invoke-RobocopySafe {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    Ensure-Directory -Path $Destination

    & robocopy $Source $Destination /E /R:2 /W:3 /NFL /NDL /NJH /NJS | Out-Null
    $rc = $LASTEXITCODE

    if ($rc -gt 7) {
        throw "Robocopy failed with exit code $rc. Source=$Source Destination=$Destination"
    }
}

function Clear-DirectoryContents {
    param([Parameter(Mandatory=$true)][string]$TargetPath)

    if (-not (Test-Path $TargetPath)) {
        Ensure-Directory -Path $TargetPath
        return
    }

    Get-ChildItem -Path $TargetPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    if (-not (Test-Path $Source)) {
        throw "Source path does not exist: $Source"
    }

    Ensure-Directory -Path $Destination
    Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force -ErrorAction Stop
}

function Write-Manifest {
    param(
        [string]$TargetDirectory,
        [string]$WpfPublishDir,
        [string]$UpdaterPublishDir
    )

    $manifest = @{
        PackageVersion = "4.0.0"
        CreatedAt = (Get-Date).ToString("s")
        MachineName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        WpfPublishDir = $WpfPublishDir
        UpdaterPublishDir = $UpdaterPublishDir
        MainExe = $AppExeName
    }

    $manifestPath = Join-Path $TargetDirectory $ManifestFileName
    ($manifest | ConvertTo-Json -Depth 10) | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
}

function Write-PackageChecksum {
    param(
        [string]$ZipPath
    )

    $hash = Get-FileHash -Path $ZipPath -Algorithm SHA256
    $checksumPath = "$ZipPath.sha256"
    $hash.Hash | Out-File -FilePath $checksumPath -Encoding ascii -Force
    Write-Log "SHA256 checksum created at: $checksumPath"
}

function Remove-OldBackups {
    param([int]$RetentionDays)

    if (-not (Test-Path $BackupRoot)) {
        return
    }

    $cutoff = (Get-Date).AddDays(-1 * $RetentionDays)
    $oldDirs = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }

    foreach ($dir in $oldDirs) {
        try {
            Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction Stop
            Write-Log "Old backup removed: $($dir.FullName)"
        }
        catch {
            Write-Log "Failed to remove old backup: $($dir.FullName). $($_.Exception.Message)" "WARN"
        }
    }
}

function Write-InstallMarker {
    param([string]$TargetInstallDir)

    $markerPath = Join-Path $TargetInstallDir $InstallMarkerFileName
    $marker = @{
        InstalledAt = (Get-Date).ToString("s")
        MachineName = $env:COMPUTERNAME
        MainExe = $AppExeName
        Status = "OK"
    }

    ($marker | ConvertTo-Json -Depth 5) | Out-File -FilePath $markerPath -Encoding UTF8 -Force
}

function Test-HealthCheck {
    param([string]$TargetInstallDir)

    $exePath = Join-Path $TargetInstallDir $AppExeName
    $markerPath = Join-Path $TargetInstallDir $InstallMarkerFileName

    if (-not (Test-Path $exePath)) {
        Write-Log "Health check failed: main executable not found: $exePath" "ERROR"
        return $false
    }

    $fileInfo = Get-Item $exePath -ErrorAction SilentlyContinue
    if (-not $fileInfo) {
        Write-Log "Health check failed: could not access executable info." "ERROR"
        return $false
    }

    if ($fileInfo.Length -le 0) {
        Write-Log "Health check failed: executable size is zero." "ERROR"
        return $false
    }

    if (-not (Test-Path $markerPath)) {
        Write-Log "Health check failed: install marker not found." "ERROR"
        return $false
    }

    Write-Log "Health check passed for: $exePath" "SUCCESS"
    return $true
}

function Invoke-Rollback {
    param(
        [hashtable]$State
    )

    if (-not $State.BackupPath) {
        throw "Rollback requested but backup path is empty."
    }

    if (-not (Test-Path $State.BackupPath)) {
        throw "Rollback requested but backup path does not exist: $($State.BackupPath)"
    }

    Write-Log "Rollback started from backup: $($State.BackupPath)" "RECOVERY"
    Ensure-Directory -Path $InstallDir
    Clear-DirectoryContents -TargetPath $InstallDir
    Invoke-RobocopySafe -Source $State.BackupPath -Destination $InstallDir
    Write-Log "Rollback completed successfully." "RECOVERY"
}

function Resolve-IncompletePreviousExecution {
    param(
        [hashtable]$State
    )

    if (-not $State.UpdateInProgress -and -not $State.RecoveryNeeded) {
        return
    }

    Write-Log "An incomplete previous update execution was detected." "RECOVERY"
    if ($State.RecoveryReason) {
        Write-Log "Recovery reason: $($State.RecoveryReason)" "RECOVERY"
    }
    if ($State.LastError) {
        Write-Log "Last recorded error: $($State.LastError)" "RECOVERY"
    }
    Write-Log "Last known phase: $($State.CurrentPhase)" "RECOVERY"

    $stagingExists = $false
    $backupExists = $false
    if ($State.StagingPath -and (Test-Path $State.StagingPath)) { $stagingExists = $true }
    if ($State.BackupPath -and (Test-Path $State.BackupPath)) { $backupExists = $true }

    switch ($State.CurrentPhase) {
        "BackupCompleted" {
            Write-Log "Previous run stopped after backup. Safe to continue with a fresh install sequence." "RECOVERY"
        }
        "ExtractCompleted" {
            Write-Log "Previous run stopped after extraction. Staging files are expected." "RECOVERY"
            if (-not $stagingExists) {
                Write-Log "Expected staging directory is missing. Deployment cannot safely continue from old staging." "WARN"
            }
        }
        "DeployStarted" {
            Write-Log "Previous run stopped during deployment. Install directory may be partially updated." "RECOVERY"
            if ($backupExists) {
                Write-Log "Automatic rollback will be performed before continuing." "RECOVERY"
                Invoke-Rollback -State $State
            }
            else {
                Write-Log "No backup found for automatic rollback. A clean redeployment will be attempted." "WARN"
            }
        }
        "HealthCheckStarted" {
            Write-Log "Previous run stopped before health check completed." "RECOVERY"
            if (Test-HealthCheck -TargetInstallDir $InstallDir) {
                Write-Log "Installed application appears healthy. Marking previous run as recovered." "RECOVERY"
                Complete-State -State $State
                return
            }
            elseif ($backupExists) {
                Write-Log "Health check failed for previous deployment. Rolling back automatically." "RECOVERY"
                Invoke-Rollback -State $State
            }
        }
        "RollbackStarted" {
            Write-Log "Previous run stopped during rollback. Rollback will be completed now." "RECOVERY"
            if ($backupExists) {
                Invoke-Rollback -State $State
            }
            else {
                Write-Log "Rollback was needed but backup no longer exists." "WARN"
            }
        }
        default {
            Write-Log "Previous execution ended in phase '$($State.CurrentPhase)'. Script will continue safely." "RECOVERY"
        }
    }

    $State.UpdateInProgress = $false
    $State.RecoveryNeeded = $false
    $State.RecoveryReason = "Recovered from previous interrupted execution"
    Save-State -State $State
    Write-Log "Recovery analysis completed. A new run will continue now." "RECOVERY"
}

# -----------------------------
# Global error handling
# -----------------------------
$script:UpdaterState = $null

trap {
    $errMsg = $_.Exception.Message
    Write-Log "CRITICAL ERROR: $errMsg" "ERROR"

    if ($script:UpdaterState -ne $null) {
        $phase = $script:UpdaterState.CurrentPhase
        if ([string]::IsNullOrWhiteSpace($phase)) { $phase = "Unknown" }
        Fail-State -State $script:UpdaterState -ErrorMessage $errMsg -Phase $phase
    }

    Unlock-Update
    exit 1
}

# -----------------------------
# Load state and recover if needed
# -----------------------------
$script:UpdaterState = Load-State
Resolve-IncompletePreviousExecution -State $script:UpdaterState

# -----------------------------
# Preconditions
# -----------------------------
Write-Log "Validating environment..."
Assert-PathExists -PathValue $RepoRoot -Description "Repository root"
Assert-PathExists -PathValue $SolutionPath -Description "Solution file"

if (-not (Test-CommandExists -CommandName "dotnet")) {
    throw "dotnet CLI was not found in PATH."
}

Ensure-Directory -Path $DefaultPackageDir
Ensure-Directory -Path $BackupRoot
Ensure-Directory -Path $StagingDirBase
Ensure-Directory -Path $InstallDir

# -----------------------------
# Phase 1: Build & Publish
# -----------------------------
if ($Build -or $CreatePackage -or $Install) {
    Set-StatePhase -State $script:UpdaterState -Phase "BuildStarted"
    Write-Log "Starting Build phase..."
    & dotnet build $SolutionPath -c Release
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed."
    }
    Write-Log "Build completed." "SUCCESS"

    Set-StatePhase -State $script:UpdaterState -Phase "WpfPublishStarted"
    Write-Log "Publishing WPF project..."
    & dotnet publish $WpfProjectPath -c Release --no-build
    if ($LASTEXITCODE -ne 0) {
        throw "WPF publish failed."
    }
    Write-Log "WPF publish completed." "SUCCESS"

    Set-StatePhase -State $script:UpdaterState -Phase "UpdaterPublishStarted"
    Write-Log "Publishing Updater project..."
    & dotnet publish $UpdaterProjectPath -c Release --no-build
    if ($LASTEXITCODE -ne 0) {
        throw "Updater publish failed."
    }
    Write-Log "Updater publish completed." "SUCCESS"
}

# -----------------------------
# Detect actual publish folders
# -----------------------------
$WpfProjectDir = Split-Path $WpfProjectPath -Parent
$UpdaterProjectDir = Split-Path $UpdaterProjectPath -Parent

$WpfPublishDir = Get-LatestPublishDirectory -ProjectDirectory $WpfProjectDir
$UpdaterPublishDir = Get-LatestPublishDirectory -ProjectDirectory $UpdaterProjectDir

if (($CreatePackage -or $Install) -and (-not $WpfPublishDir)) {
    throw "Could not detect WPF publish directory."
}

if (($CreatePackage -or $Install) -and (-not $UpdaterPublishDir)) {
    Write-Log "Updater publish directory not found. Packaging will continue without updater files." "WARN"
}

if ($WpfPublishDir) {
    Write-Log "Detected WPF publish directory: $WpfPublishDir"
}
if ($UpdaterPublishDir) {
    Write-Log "Detected Updater publish directory: $UpdaterPublishDir"
}

# -----------------------------
# Phase 2: Create Package
# -----------------------------
if ($CreatePackage -or $Install) {
    Set-StatePhase -State $script:UpdaterState -Phase "PackageStarted"
    Write-Log "Creating update package..."

    $tempPackDir = Join-Path $StagingDirBase ("Pack_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    if (Test-Path $tempPackDir) {
        Remove-Item $tempPackDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Ensure-Directory -Path $tempPackDir

    Write-Log "Copying WPF published files into package staging..."
    Copy-DirectoryContents -Source $WpfPublishDir -Destination $tempPackDir

    if ($UpdaterPublishDir -and (Test-Path $UpdaterPublishDir)) {
        $updaterStageDir = Join-Path $tempPackDir "Updater"
        Ensure-Directory -Path $updaterStageDir
        Write-Log "Copying Updater published files into package staging..."
        Copy-DirectoryContents -Source $UpdaterPublishDir -Destination $updaterStageDir
    }
    else {
        Write-Log "Updater files were skipped because publish directory was not found." "WARN"
    }

    Write-Manifest -TargetDirectory $tempPackDir -WpfPublishDir $WpfPublishDir -UpdaterPublishDir $UpdaterPublishDir

    $zipPath = Join-Path $DefaultPackageDir $DefaultPackageName
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }

    Compress-Archive -Path (Join-Path $tempPackDir "*") -DestinationPath $zipPath -Force
    Write-Log "Package created at: $zipPath" "SUCCESS"
    Write-PackageChecksum -ZipPath $zipPath

    $script:UpdaterState.PackagePath = $zipPath
    Save-State -State $script:UpdaterState

    Remove-Item $tempPackDir -Recurse -Force -ErrorAction SilentlyContinue
}

# -----------------------------
# Phase 3: Atomic Install
# -----------------------------
if ($Install) {
    Write-Log "Starting Atomic Installation..."
    Lock-Update

    try {
        $pkg = $PackagePath
        if ([string]::IsNullOrWhiteSpace($pkg)) {
            if (-not [string]::IsNullOrWhiteSpace($script:UpdaterState.PackagePath)) {
                $pkg = $script:UpdaterState.PackagePath
            }
            else {
                $pkg = Join-Path $DefaultPackageDir $DefaultPackageName
            }
        }

        Assert-PathExists -PathValue $pkg -Description "Package file"
        $script:UpdaterState.PackagePath = $pkg
        Save-State -State $script:UpdaterState

        Set-StatePhase -State $script:UpdaterState -Phase "BackupStarted"
        $backupPath = Join-Path $BackupRoot ("Backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
        $script:UpdaterState.BackupPath = $backupPath
        Save-State -State $script:UpdaterState

        if (Test-Path $InstallDir) {
            Write-Log "Backing up current installation to $backupPath"
            Invoke-RobocopySafe -Source $InstallDir -Destination $backupPath
            Set-StatePhase -State $script:UpdaterState -Phase "BackupCompleted"
            Write-Log "Backup completed." "SUCCESS"
        }
        else {
            Write-Log "Install directory does not exist yet. Backup skipped." "WARN"
            Set-StatePhase -State $script:UpdaterState -Phase "BackupCompleted"
        }

        Set-StatePhase -State $script:UpdaterState -Phase "ExtractStarted"
        $staging = Join-Path $StagingDirBase ("Install_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
        $script:UpdaterState.StagingPath = $staging
        Save-State -State $script:UpdaterState

        if (Test-Path $staging) {
            Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        }
        Ensure-Directory -Path $staging

        Write-Log "Extracting package to staging..."
        Expand-Archive -Path $pkg -DestinationPath $staging -Force
        Set-StatePhase -State $script:UpdaterState -Phase "ExtractCompleted"
        Write-Log "Package extraction completed." "SUCCESS"

        Set-StatePhase -State $script:UpdaterState -Phase "DeployStarted"
        Write-Log "Deploying files to install directory..."
        Ensure-Directory -Path $InstallDir
        Clear-DirectoryContents -TargetPath $InstallDir
        Copy-DirectoryContents -Source $staging -Destination $InstallDir
        Write-InstallMarker -TargetInstallDir $InstallDir
        Write-Log "Deployment file copy completed." "SUCCESS"

        Set-StatePhase -State $script:UpdaterState -Phase "HealthCheckStarted"
        Write-Log "Running health check..."
        $healthOk = Test-HealthCheck -TargetInstallDir $InstallDir

        if (-not $healthOk) {
            throw "Health check failed after deployment."
        }

        Write-Log "Installation successful." "SUCCESS"

        if ($staging -and (Test-Path $staging)) {
            Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        }

        Remove-OldBackups -RetentionDays $BackupRetentionDays
        Complete-State -State $script:UpdaterState
    }
    catch {
        $deployErr = $_.Exception.Message
        Write-Log "Deployment failed: $deployErr" "ERROR"

        if ($script:UpdaterState -ne $null) {
            $script:UpdaterState.LastError = $deployErr
            $script:UpdaterState.RecoveryNeeded = $true
            Save-State -State $script:UpdaterState
        }

        if ($script:UpdaterState.BackupPath -and (Test-Path $script:UpdaterState.BackupPath)) {
            Set-StatePhase -State $script:UpdaterState -Phase "RollbackStarted"
            Write-Log "Attempting rollback from backup..."
            Invoke-Rollback -State $script:UpdaterState
            Write-Log "Rollback completed." "WARN"
        }

        throw
    }
    finally {
        Unlock-Update
    }
}

if (-not $Build -and -not $CreatePackage -and -not $Install) {
    Write-Log "No operation switches were provided. Nothing to do." "WARN"
}

Write-Log "All requested operations completed successfully." "SUCCESS"
