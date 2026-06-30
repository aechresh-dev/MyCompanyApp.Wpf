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
    if ($PSScriptRoot) { return $PSScriptRoot }
    return (Get-Location).Path
}

$ScriptRoot = Get-ScriptRootSafe

$RootPath           = $ScriptRoot
$SolutionPath       = Join-Path $RootPath 'MyCompanyApp.sln'
$WpfProjectPath     = Join-Path $RootPath 'src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj'
$UpdaterProjectPath = Join-Path $RootPath 'MyCompanyApp.Updater\MyCompanyApp.Updater.csproj'

$PublishRoot        = Join-Path $RootPath 'Publish'
$PublishAppRoot     = Join-Path $PublishRoot 'App'
$PublishUpdaterRoot = Join-Path $PublishRoot 'Updater'
$PackagePath        = Join-Path $PublishRoot 'update.zip'
$PackageHashPath    = Join-Path $PublishRoot 'update.zip.sha256'
$ManifestPath       = Join-Path $PublishRoot 'manifest.json'
$ReleaseNotesPath   = Join-Path $PublishRoot 'release-notes.txt'
$StatePath          = Join-Path $PublishRoot 'update.state.json'

$InstallRoot        = 'G:\Program Files\MyCompanyApp'
$VersionsRoot       = Join-Path $InstallRoot 'versions'
$CurrentLinkPath    = Join-Path $InstallRoot 'current.txt'
$PreviousLinkPath   = Join-Path $InstallRoot 'previous.txt'
$AppExeRelative     = 'App\MyCompanyApp.Wpf.exe'

$BackupRoot         = 'G:\ProgramData\MyCompanyApp\Backups'
$MinimumFreeSpaceGB = 2
$BackupRetention    = 5

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Ensure-Directories {
    @($PublishRoot, $InstallRoot, $VersionsRoot, $BackupRoot) | ForEach-Object {
        Ensure-Directory -Path $_
    }
}

function Save-State {
    param(
        [string]$CurrentPhase,
        [bool]$RecoveryNeeded = $false,
        [string]$RecoveryReason = '',
        [string]$LastError = ''
    )

    Ensure-Directory -Path $PublishRoot

    $state = [ordered]@{
        CurrentPhase   = $CurrentPhase
        RecoveryNeeded = $RecoveryNeeded
        RecoveryReason = $RecoveryReason
        LastError      = $LastError
        TimestampUtc   = (Get-Date).ToUniversalTime().ToString('o')
    }

    $state | ConvertTo-Json -Depth 8 | Set-Content -Path $StatePath -Encoding UTF8
}

function Load-State {
    if (-not (Test-Path $StatePath)) { return $null }
    try {
        return (Get-Content $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Clear-State {
    if (Test-Path $StatePath) {
        Remove-Item $StatePath -Force -ErrorAction SilentlyContinue
    }
}

function Test-IsInstallPipelineAction {
    return ($Build -or $CreatePackage -or $Install -or $Clean)
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $RootPath
    )

    $cmdText = "$FilePath $($Arguments -join ' ')".Trim()
    Write-Info "Running: $cmdText"

    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }

        if ($exitCode -ne 0) {
            throw "Command failed with exit code ${exitCode} : $cmdText"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-DotNet {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = $RootPath
    )
    Invoke-External -FilePath 'dotnet' -Arguments $Arguments -WorkingDirectory $WorkingDirectory
}

function Normalize-Version {
    param([string]$VersionText)

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return [version]'0.0.0.0'
    }

    $clean = $VersionText.Trim()

    if ($clean -match '^\d+(\.\d+){1,3}$') {
        switch (($clean -split '\.').Count) {
            2 { return [version]($clean + '.0.0') }
            3 { return [version]($clean + '.0') }
            default { return [version]$clean }
        }
    }

    if ($clean -match '^(\d+\.\d+\.\d+)(?:[+-].*)?$') {
        return [version]($Matches[1] + '.0')
    }

    if ($clean -match '^(\d+\.\d+)(?:[+-].*)?$') {
        return [version]($Matches[1] + '.0.0')
    }

    if ($clean -match '^(\d+)(?:[+-].*)?$') {
        return [version]($Matches[1] + '.0.0.0')
    }

    return [version]'0.0.0.0'
}

function Get-ExeVersionInfo {
    param([Parameter(Mandatory = $true)][string]$ExePath)

    if (-not (Test-Path $ExePath)) {
        throw "Executable not found: $ExePath"
    }

    $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath)

    return [pscustomobject]@{
        FilePath       = $ExePath
        ProductVersion = $vi.ProductVersion
        FileVersion    = $vi.FileVersion
        CompanyName    = $vi.CompanyName
        Description    = $vi.FileDescription
    }
}

function Get-PublishedExePath {
    $candidate1 = Join-Path $PublishAppRoot 'MyCompanyApp.Wpf.exe'
    if (Test-Path $candidate1) { return $candidate1 }

    $candidate2 = Join-Path $PublishRoot 'MyCompanyApp.Wpf.exe'
    if (Test-Path $candidate2) { return $candidate2 }

    $candidate3 = Get-ChildItem -Path $PublishRoot -Recurse -Filter 'MyCompanyApp.Wpf.exe' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($candidate3) { return $candidate3.FullName }

    throw "Published executable not found under $PublishRoot"
}

function Get-PublishedVersion {
    $exePath = Get-PublishedExePath
    $info = Get-ExeVersionInfo -ExePath $exePath
    if (-not [string]::IsNullOrWhiteSpace($info.ProductVersion)) { return $info.ProductVersion.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($info.FileVersion)) { return $info.FileVersion.Trim() }
    return '0.0.0.0'
}

function Test-FreeSpace {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][double]$MinimumGB
    )

    $root = [System.IO.Path]::GetPathRoot($Path)
    if ([string]::IsNullOrWhiteSpace($root)) {
        return
    }

    $driveName = $root.TrimEnd('\').TrimEnd(':')
    $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    if (-not $drive) {
        return
    }

    $freeGB = [math]::Round(($drive.Free / 1GB), 2)
    Write-Info "Free space on drive $driveName : $freeGB GB"

    if ($freeGB -lt $MinimumGB) {
        throw "Insufficient free disk space on drive $driveName. Required >= $MinimumGB GB, available = $freeGB GB"
    }
}

function Test-Health {
    param([Parameter(Mandatory = $true)][string]$InstallPath)

    $exe = Join-Path $InstallPath $AppExeRelative
    if (-not (Test-Path $exe)) {
        throw "Health check failed: missing exe $exe"
    }

    $info = Get-ExeVersionInfo -ExePath $exe
    if ([string]::IsNullOrWhiteSpace($info.ProductVersion) -and [string]::IsNullOrWhiteSpace($info.FileVersion)) {
        throw "Health check failed: version info unavailable for $exe"
    }

    Write-Success "Health check passed for $exe"
}

function Get-InstallVersionPath {
    param([Parameter(Mandatory = $true)][string]$VersionText)
    return (Join-Path $VersionsRoot $VersionText)
}

function Read-LinkText {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) { return $null }

    $text = Get-Content $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    return $text.Trim()
}

function Write-LinkText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Value
    )

    if ($null -eq $Value) {
        '' | Set-Content -Path $Path -Encoding UTF8
    }
    else {
        $Value | Set-Content -Path $Path -Encoding UTF8
    }
}

function Get-LatestInstalledVersion {
    $current = Read-LinkText -Path $CurrentLinkPath
    if ($current) { return $current }

    if (Test-Path $VersionsRoot) {
        $dirs = Get-ChildItem -Path $VersionsRoot -Directory -ErrorAction SilentlyContinue
        if ($dirs) {
            $sorted = $dirs | Sort-Object {
                try { Normalize-Version $_.Name } catch { [version]'0.0.0.0' }
            } -Descending
            $first = $sorted | Select-Object -First 1
            if ($first) { return $first.Name }
        }
    }

    return $null
}

function Backup-CurrentInstall {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $BackupRoot "Backup_$stamp"
    Ensure-Directory -Path $backupPath

    if (Test-Path $InstallRoot) {
        Write-Info "Creating backup: $backupPath"
        Get-ChildItem -Path $InstallRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    return $backupPath
}

function Remove-OldBackups {
    $dirs = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending
    if ($dirs -and $dirs.Count -gt $BackupRetention) {
        $dirs | Select-Object -Skip $BackupRetention | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Stop-RunningApplication {
    Write-Section "Stop Running Application"

    $processNames = @(
        'MyCompanyApp.Wpf',
        'MyCompanyApp'
    )

    foreach ($name in $processNames) {
        $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            try {
                Write-Info "Attempting graceful close for process $($proc.ProcessName) PID=$($proc.Id)"
                $null = $proc.CloseMainWindow()
                Start-Sleep -Seconds 5
                if (-not $proc.HasExited) {
                    Write-Warn "Force terminating process $($proc.ProcessName) PID=$($proc.Id)"
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Warn "Could not stop process $name : $($_.Exception.Message)"
            }
        }
    }
}

function Build-Projects {
    Write-Section "Build"
    Save-State -CurrentPhase 'BuildStarted' -RecoveryNeeded $true -RecoveryReason 'Build in progress'
    Invoke-DotNet -Arguments @('restore', $SolutionPath)
    Invoke-DotNet -Arguments @('build', $SolutionPath, '-c', $Configuration, '--no-restore')
    Write-Success "Build completed"
}

function Publish-Projects {
    Write-Section "Publish"

    if (Test-Path $PublishAppRoot) {
        Remove-Item $PublishAppRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $PublishUpdaterRoot) {
        Remove-Item $PublishUpdaterRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Ensure-Directory -Path $PublishAppRoot
    Ensure-Directory -Path $PublishUpdaterRoot

    Save-State -CurrentPhase 'WpfPublishStarted' -RecoveryNeeded $true -RecoveryReason 'WPF publish in progress'
    Invoke-DotNet -Arguments @('publish', $WpfProjectPath, '-c', $Configuration, '-o', $PublishAppRoot)
    Write-Success "WPF publish completed"

    Save-State -CurrentPhase 'UpdaterPublishStarted' -RecoveryNeeded $true -RecoveryReason 'Updater publish in progress'
    Invoke-DotNet -Arguments @('publish', $UpdaterProjectPath, '-c', $Configuration, '-o', $PublishUpdaterRoot)
    Write-Success "Updater publish completed"
}

function Create-Package {
    Write-Section "Package"

    if (Test-Path $PackagePath)      { Remove-Item $PackagePath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $PackageHashPath)  { Remove-Item $PackageHashPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $ManifestPath)     { Remove-Item $ManifestPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $ReleaseNotesPath) { Remove-Item $ReleaseNotesPath -Force -ErrorAction SilentlyContinue }

    Save-State -CurrentPhase 'PackageStarted' -RecoveryNeeded $true -RecoveryReason 'Packaging in progress'

    $currentVersion = Get-PublishedVersion
    $publishExe = Get-PublishedExePath
    $notes = @"
MyCompanyApp.Wpf
Version: $currentVersion

Improvements and fixes:
- Stability hardening
- Recovery-aware update flow
- Pre/post install health verification
- Versioned deployment and safer rollback
- PowerShell 5.1 sync execution fix
"@
    $notes | Set-Content -Path $ReleaseNotesPath -Encoding UTF8

    $manifest = [ordered]@{
        AppName            = 'MyCompanyApp.Wpf'
        Version            = $currentVersion
        CreatedUtc         = (Get-Date).ToUniversalTime().ToString('o')
        PublishExe         = $publishExe
        PublishAppRoot     = $PublishAppRoot
        PublishUpdaterRoot = $PublishUpdaterRoot
    }

    $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $ManifestPath -Encoding UTF8

    if (-not (Test-Path $PublishAppRoot)) {
        throw "WPF publish output not found: $PublishAppRoot"
    }

    $stagingRoot = Join-Path $PublishRoot 'PackageStaging'
    if (Test-Path $stagingRoot) {
        Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Ensure-Directory -Path $stagingRoot
    Ensure-Directory -Path (Join-Path $stagingRoot 'App')
    Ensure-Directory -Path (Join-Path $stagingRoot 'Updater')

    Copy-Item -Path (Join-Path $PublishAppRoot '*') -Destination (Join-Path $stagingRoot 'App') -Recurse -Force
    if (Test-Path $PublishUpdaterRoot) {
        Copy-Item -Path (Join-Path $PublishUpdaterRoot '*') -Destination (Join-Path $stagingRoot 'Updater') -Recurse -Force
    }

    Copy-Item -Path $ManifestPath -Destination (Join-Path $stagingRoot 'manifest.json') -Force
    Copy-Item -Path $ReleaseNotesPath -Destination (Join-Path $stagingRoot 'release-notes.txt') -Force

    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $PackagePath -Force

    $hash = (Get-FileHash -Path $PackagePath -Algorithm SHA256).Hash
    $hash | Set-Content -Path $PackageHashPath -Encoding UTF8

    if (Test-Path $stagingRoot) {
        Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Clear-State
    Write-Success "Package created: $PackagePath"
    Write-Success "Checksum created: $PackageHashPath"
}

function Install-Package {
    Write-Section "Install"

    if (-not (Test-Path $PackagePath)) {
        throw "Package not found: $PackagePath"
    }

    if (-not (Test-Path $PackageHashPath)) {
        throw "Package checksum not found: $PackageHashPath"
    }

    Save-State -CurrentPhase 'ExtractStarted' -RecoveryNeeded $true -RecoveryReason 'Extract in progress'

    Test-FreeSpace -Path $InstallRoot -MinimumGB $MinimumFreeSpaceGB

    $packageHash = (Get-FileHash -Path $PackagePath -Algorithm SHA256).Hash
    $storedHash = (Get-Content $PackageHashPath -Raw -Encoding UTF8).Trim()
    if ($packageHash -ne $storedHash) {
        throw "Checksum verification failed for package"
    }

    $tempExtract = Join-Path $env:TEMP ("MyCompanyApp_" + [guid]::NewGuid().ToString('N'))
    Ensure-Directory -Path $tempExtract

    try {
        Expand-Archive -Path $PackagePath -DestinationPath $tempExtract -Force
        Save-State -CurrentPhase 'ExtractCompleted' -RecoveryNeeded $true -RecoveryReason 'Extraction complete'

        $manifestExtracted = Join-Path $tempExtract 'manifest.json'
        if (-not (Test-Path $manifestExtracted)) {
            throw "Extracted manifest not found: $manifestExtracted"
        }

        $manifest = Get-Content $manifestExtracted -Raw -Encoding UTF8 | ConvertFrom-Json
        $incomingVersion = [string]$manifest.Version

        if ([string]::IsNullOrWhiteSpace($incomingVersion)) {
            throw "Incoming package version is missing in manifest"
        }

        $installVersionPath = Get-InstallVersionPath -VersionText $incomingVersion

        $currentInstalledVersion = Get-LatestInstalledVersion
        if ($currentInstalledVersion) {
            $incomingNorm = Normalize-Version $incomingVersion
            $currentNorm  = Normalize-Version $currentInstalledVersion
            if ($incomingNorm -lt $currentNorm) {
                throw "Downgrade blocked. Current=$currentInstalledVersion, Incoming=$incomingVersion"
            }
        }

        Stop-RunningApplication

        $backupPath = Backup-CurrentInstall
        Save-State -CurrentPhase 'BackupCompleted' -RecoveryNeeded $true -RecoveryReason "Backup completed: $backupPath"

        Save-State -CurrentPhase 'DeployStarted' -RecoveryNeeded $true -RecoveryReason 'Deployment in progress'

        if (Test-Path $installVersionPath) {
            Remove-Item $installVersionPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Ensure-Directory -Path $installVersionPath

        $extractedAppRoot = Join-Path $tempExtract 'App'
        if (-not (Test-Path $extractedAppRoot)) {
            throw "Extracted App folder not found: $extractedAppRoot"
        }

        Ensure-Directory -Path (Join-Path $installVersionPath 'App')
        Copy-Item -Path (Join-Path $extractedAppRoot '*') -Destination (Join-Path $installVersionPath 'App') -Recurse -Force

        $extractedUpdaterRoot = Join-Path $tempExtract 'Updater'
        if (Test-Path $extractedUpdaterRoot) {
            Ensure-Directory -Path (Join-Path $installVersionPath 'Updater')
            Copy-Item -Path (Join-Path $extractedUpdaterRoot '*') -Destination (Join-Path $installVersionPath 'Updater') -Recurse -Force
        }

        if ($currentInstalledVersion -and ($currentInstalledVersion -ne $incomingVersion)) {
            Write-LinkText -Path $PreviousLinkPath -Value $currentInstalledVersion
        }
        elseif (-not (Test-Path $PreviousLinkPath)) {
            Write-LinkText -Path $PreviousLinkPath -Value ''
        }

        Write-LinkText -Path $CurrentLinkPath -Value $incomingVersion

        Save-State -CurrentPhase 'HealthCheckStarted' -RecoveryNeeded $true -RecoveryReason 'Health validation in progress'
        Test-Health -InstallPath $installVersionPath

        Clear-State
        Remove-OldBackups

        Write-Success "Installation completed successfully"
        Write-Info "Installed version: $incomingVersion"
        Write-Info "Install path: $installVersionPath"

        $notesPath = Join-Path $tempExtract 'release-notes.txt'
        if (Test-Path $notesPath) {
            Write-Section "Release Notes"
            Get-Content $notesPath -Encoding UTF8 | ForEach-Object { Write-Host $_ }
        }
    }
    catch {
        Write-Warn "Install failed. Attempting rollback."
        try {
            Invoke-Rollback -SilentIfUnavailable
        }
        catch {
            Write-Warn "Rollback attempt failed: $($_.Exception.Message)"
        }
        throw
    }
    finally {
        if (Test-Path $tempExtract) {
            Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-Rollback {
    param(
        [switch]$SilentIfUnavailable
    )

    Write-Section "Rollback"

    $previous = Read-LinkText -Path $PreviousLinkPath
    if ([string]::IsNullOrWhiteSpace($previous)) {
        if ($SilentIfUnavailable) {
            Write-Warn "No previous version recorded for rollback. Skipping rollback."
            return
        }

        Write-Warn "No previous version recorded for rollback."
        return
    }

    $previousPath = Get-InstallVersionPath -VersionText $previous
    if (-not (Test-Path $previousPath)) {
        if ($SilentIfUnavailable) {
            Write-Warn "Previous version path not found for rollback: $previousPath"
            return
        }

        throw "Previous version path not found: $previousPath"
    }

    Write-LinkText -Path $CurrentLinkPath -Value $previous
    Write-Success "Rollback switched to version $previous"
    Test-Health -InstallPath $previousPath
    Clear-State
}

function Show-Notes {
    Write-Section "Release Notes"
    if (Test-Path $ReleaseNotesPath) {
        Get-Content $ReleaseNotesPath -Encoding UTF8 | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Warn "No release notes found"
    }
}

function Recover-IfNeeded {
    $state = Load-State
    if (-not $state) {
        Write-Info "No previous state found."
        return
    }

    $recoverablePhases = @(
        'BuildStarted',
        'WpfPublishStarted',
        'UpdaterPublishStarted',
        'PackageStarted',
        'ExtractStarted',
        'ExtractCompleted',
        'BackupCompleted',
        'DeployStarted',
        'HealthCheckStarted'
    )

    if (-not ($recoverablePhases -contains [string]$state.CurrentPhase)) {
        Clear-State
        Write-Info "Ignoring stale state file."
        return
    }

    Write-Section "Recovery Check"
    Write-Info ("Last phase: " + [string]$state.CurrentPhase)
    Write-Info ("Recovery needed: " + [string]$state.RecoveryNeeded)
    Write-Info ("Reason: " + [string]$state.RecoveryReason)

    if ($state.RecoveryNeeded -eq $true) {
        switch ([string]$state.CurrentPhase) {
            'DeployStarted' {
                Write-Warn "Previous deployment was interrupted. Attempting rollback-safe recovery."
                Invoke-Rollback -SilentIfUnavailable
            }
            'HealthCheckStarted' {
                Write-Warn "Previous health check was interrupted. Re-running health check."
                $current = Read-LinkText -Path $CurrentLinkPath
                if ($current) {
                    Test-Health -InstallPath (Get-InstallVersionPath -VersionText $current)
                    Clear-State
                }
                else {
                    Write-Warn "Current version not found during recovery."
                }
            }
            'PackageStarted' {
                Write-Warn "Previous packaging state detected. Clearing stale package state."
                Clear-State
            }
            default {
                Write-Warn "Incomplete prior run detected. State preserved for safety."
            }
        }
    }
}

try {
    Ensure-Directories

    if (Test-IsInstallPipelineAction) {
        Recover-IfNeeded
    }

    if ($Clean) {
        Write-Section "Clean"
        if (Test-Path $PublishRoot) {
            Remove-Item $PublishRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        Ensure-Directories
        Clear-State
        Write-Success "Clean completed"
    }

    if ($Build) {
        Build-Projects
    }

    if ($CreatePackage) {
        Publish-Projects
        Create-Package
    }

    if ($Install) {
        Install-Package
    }

    if ($Rollback) {
        Invoke-Rollback
    }

    if ($HealthCheck) {
        Write-Section "Health Check"
        $current = Read-LinkText -Path $CurrentLinkPath
        if ($current) {
            Test-Health -InstallPath (Get-InstallVersionPath -VersionText $current)
        }
        else {
            $exePath = Get-PublishedExePath
            $appRoot = Split-Path $exePath -Parent
            $publishVersionRoot = Split-Path $appRoot -Parent
            Test-Health -InstallPath $publishVersionRoot
        }
    }

    if ($ShowReleaseNotes) {
        Show-Notes
    }

    Write-Success "All requested operations completed successfully."
}
catch {
    $message = $_.Exception.Message
    Write-Fail $message

    if (Test-IsInstallPipelineAction) {
        Save-State -CurrentPhase 'Failed' -RecoveryNeeded $true -RecoveryReason 'Execution failed' -LastError $message
    }

    throw
}
