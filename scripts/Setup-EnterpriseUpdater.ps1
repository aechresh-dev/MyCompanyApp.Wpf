#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RootPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf",
    [string]$SolutionPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\MyCompanyApp.sln",
    [string]$WpfProjectPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj",
    [string]$UpdaterProjectPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\MyCompanyApp.Updater\MyCompanyApp.Updater.csproj",
    [string]$PublishDir = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\Publish",
    [string]$ArtifactsDir = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\artifacts",
    [string]$PackageName = "MyCompanyApp-offline-update.zip",
    [string]$RuntimeIdentifier = "win-x64",
    [string]$Configuration = "Release",
    [switch]$SkipBuild,
    [switch]$SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor DarkGray
}

function Write-Ok {
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

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Patch-WpfProjectForOfflinePublish {
    param(
        [string]$ProjectFile,
        [string]$RuntimeId
    )

    Assert-PathExists -Path $ProjectFile -Description "WPF project file"

    $original = Get-Content -LiteralPath $ProjectFile -Raw

    $insertBlock = @"
  <PropertyGroup Condition="'`$(Configuration)|`$(Platform)'=='Release|AnyCPU'">
    <RuntimeIdentifier>$RuntimeId</RuntimeIdentifier>
    <SelfContained>true</SelfContained>
    <PublishSingleFile>false</PublishSingleFile>
    <PublishTrimmed>false</PublishTrimmed>
    <DebugType>portable</DebugType>
    <DebugSymbols>true</DebugSymbols>
  </PropertyGroup>

"@

    $hasRuntimeId = $original -match '<RuntimeIdentifier>'
    $hasSelfContained = $original -match '<SelfContained>'
    $hasTrimmed = $original -match '<PublishTrimmed>'
    $hasSingleFile = $original -match '<PublishSingleFile>'

    $patched = $original

    if (-not ($hasRuntimeId -and $hasSelfContained -and $hasTrimmed -and $hasSingleFile)) {
        if ($patched -match '</Project>') {
            $patched = $patched -replace '</Project>', ($insertBlock + '</Project>')
        } else {
            throw "Invalid csproj file format. Missing closing </Project>."
        }
    }

    $backupPath = "$ProjectFile.bak"
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Set-Content -LiteralPath $backupPath -Value $original -Encoding UTF8
    }

    Set-Content -LiteralPath $ProjectFile -Value $patched -Encoding UTF8
    Write-Ok "Patched project file for offline self-contained publish"
}

function Restore-ProjectIfNeeded {
    param([string]$ProjectFile)

    $backupPath = "$ProjectFile.bak"
    if (Test-Path -LiteralPath $backupPath) {
        Copy-Item -LiteralPath $backupPath -Destination $ProjectFile -Force
        Write-Ok "Restored project file from backup"
    }
}

function Invoke-DotNetPublish {
    param(
        [string]$ProjectFile,
        [string]$Configuration,
        [string]$RuntimeId,
        [string]$PublishDir
    )

    New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null

    $args = @(
        "publish",
        $ProjectFile,
        "-c", $Configuration,
        "-r", $RuntimeId,
        "--self-contained", "true",
        "-o", $PublishDir
    )

    Write-Host "dotnet $($args -join ' ')" -ForegroundColor DarkGray
    & dotnet @args

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish failed with exit code $LASTEXITCODE"
    }

    Write-Ok "Publish completed successfully"
}

function Test-MandatoryFiles {
    param([string]$PublishDir)

    $required = @(
        "*.exe",
        "*.dll",
        "*.deps.json",
        "*.runtimeconfig.json"
    )

    foreach ($pattern in $required) {
        $items = Get-ChildItem -Path $PublishDir -Filter $pattern -File -ErrorAction SilentlyContinue
        if (-not $items -or $items.Count -eq 0) {
            throw "Mandatory file pattern missing in publish output: $pattern"
        }
    }

    Write-Ok "Mandatory publish files verified"
}

function New-PackageZip {
    param(
        [string]$SourceDir,
        [string]$ArtifactsDir,
        [string]$PackageName
    )

    New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
    $packagePath = Join-Path $ArtifactsDir $PackageName

    if (Test-Path -LiteralPath $packagePath) {
        Remove-Item -LiteralPath $packagePath -Force
    }

    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        Compress-Archive -Path (Join-Path $SourceDir '*') -DestinationPath $packagePath -Force
    } else {
        throw "Compress-Archive is unavailable in this PowerShell environment"
    }

    if (-not (Test-Path -LiteralPath $packagePath)) {
        throw "Package was not created: $packagePath"
    }

    $hash = Get-Sha256 -Path $packagePath
    $hashFile = "$packagePath.sha256.txt"
    Set-Content -LiteralPath $hashFile -Value $hash -Encoding ASCII

    Write-Ok "Package created: $packagePath"
    Write-Ok "SHA256 saved: $hashFile"

    return $packagePath
}

function Write-PublishManifest {
    param(
        [string]$PublishDir,
        [string]$ArtifactsDir
    )

    $manifestPath = Join-Path $ArtifactsDir "publish-manifest.txt"
    $files = Get-ChildItem -Path $PublishDir -File -Recurse | Sort-Object FullName
    $lines = foreach ($f in $files) {
        $hash = Get-Sha256 -Path $f.FullName
        "{0}`t{1}`t{2}" -f $hash, $f.Length, ($f.FullName.Substring($PublishDir.Length + 1))
    }

    Set-Content -LiteralPath $manifestPath -Value $lines -Encoding UTF8
    Write-Ok "Manifest written: $manifestPath"
}

try {
    Write-Section "Enterprise Offline Updater Setup"

    Assert-PathExists -Path $RootPath -Description "Solution root"
    Assert-PathExists -Path $SolutionPath -Description "Solution file"
    Assert-PathExists -Path $WpfProjectPath -Description "WPF project"
    Assert-PathExists -Path $UpdaterProjectPath -Description "Updater project"

    Push-Location $RootPath

    try {
        Write-Section "Patch Project"
        Patch-WpfProjectForOfflinePublish -ProjectFile $WpfProjectPath -RuntimeId $RuntimeIdentifier

        if (-not $SkipBuild) {
            Write-Section "Publish Application"
            Invoke-DotNetPublish -ProjectFile $WpfProjectPath -Configuration $Configuration -RuntimeId $RuntimeIdentifier -PublishDir $PublishDir
        } else {
            Write-Warn "Build/publish skipped by user switch"
        }

        Write-Section "Validate Output"
        Test-MandatoryFiles -PublishDir $PublishDir
        Write-PublishManifest -PublishDir $PublishDir -ArtifactsDir $ArtifactsDir

        if (-not $SkipZip) {
            Write-Section "Create Offline Package"
            $pkg = New-PackageZip -SourceDir $PublishDir -ArtifactsDir $ArtifactsDir -PackageName $PackageName
            Write-Host ""
            Write-Host "Final package: $pkg" -ForegroundColor Green
        } else {
            Write-Warn "ZIP creation skipped by user switch"
        }

        Write-Section "Done"
        Write-Ok "Enterprise offline setup finished successfully"
    }
    finally {
        Pop-Location
        Restore-ProjectIfNeeded -ProjectFile $WpfProjectPath
    }
}
catch {
    Write-Fail $_.Exception.Message
    throw
}
