param(
    [string]$RootPath = (Get-Location).Path,
    [string]$UpdaterProjectRelativePath = "src\MyCompanyApp.Updater",
    [string]$AppExeName = "MyCompanyApp.Wpf.exe",
    [string]$ProductFolderName = "MyCompanyApp",
    [switch]$BuildAfterPatch
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkCyan
    Write-Host $msg -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor DarkCyan
}

function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $dir = Split-Path $Path -Parent
    if ($dir) { Ensure-Dir $dir }

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $RootPath).Path
$updaterDir = Join-Path $root $UpdaterProjectRelativePath

if (-not (Test-Path $updaterDir)) {
    throw "Updater project directory not found: $updaterDir"
}

$csproj = Get-ChildItem -Path $updaterDir -Filter *.csproj | Select-Object -First 1
if (-not $csproj) {
    throw "No csproj found in: $updaterDir"
}

$modelsDir = Join-Path $updaterDir "Models"
$servicesDir = Join-Path $updaterDir "Services"
Ensure-Dir $modelsDir
Ensure-Dir $servicesDir

Write-Step "1) Writing source files"

$programCs = @"
using System;
using MyCompanyApp.Updater.Services;

namespace MyCompanyApp.Updater;

internal static class Program
{
    public static int Main(string[] args)
    {
        try
        {
            if (args.Length < 2)
            {
                Console.WriteLine("Usage:");
                Console.WriteLine("  MyCompanyApp.Updater.exe <packageZipPath> <installDirectory> [productFolderName]");
                return 1;
            }

            var packageZipPath = args[0];
            var installDirectory = args[1];
            var productFolderName = args.Length >= 3 ? args[2] : "$ProductFolderName";

            Console.WriteLine("Starting enterprise-safe update...");
            Console.WriteLine("Package: " + packageZipPath);
            Console.WriteLine("InstallDirectory: " + installDirectory);
            Console.WriteLine("ProductFolderName: " + productFolderName);

            var orchestrator = new SafeUpdateOrchestrator();
            orchestrator.Apply(packageZipPath, installDirectory, productFolderName);

            Console.WriteLine("Update completed successfully.");
            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine("FATAL: " + ex);
            return -1;
        }
    }
}
"@

Write-Utf8File -Path (Join-Path $updaterDir "Program.cs") -Content $programCs

$updateMetadataCs = @"
using System.Text.Json.Serialization;

namespace MyCompanyApp.Updater.Models;

public sealed class UpdateMetadata
{
    [JsonPropertyName("customerId")]
    public string? CustomerId { get; set; }

    [JsonPropertyName("displayName")]
    public string? DisplayName { get; set; }

    [JsonPropertyName("productName")]
    public string? ProductName { get; set; }

    [JsonPropertyName("version")]
    public string? Version { get; set; }

    [JsonPropertyName("appExeName")]
    public string? AppExeName { get; set; }

    [JsonPropertyName("packageId")]
    public string? PackageId { get; set; }

    [JsonPropertyName("releasedAtUtc")]
    public string? ReleasedAtUtc { get; set; }
}
"@

Write-Utf8File -Path (Join-Path $modelsDir "UpdateMetadata.cs") -Content $updateMetadataCs

$updateStateCs = @"
using System;

namespace MyCompanyApp.Updater.Models;

public sealed class UpdateState
{
    public string? PackageZipPath { get; set; }
    public string? InstallDirectory { get; set; }
    public string? StagingDirectory { get; set; }
    public string? InstallBackupDirectory { get; set; }
    public string? DatabasePath { get; set; }
    public string? DatabaseBackupPath { get; set; }
    public string? PreviousVersion { get; set; }
    public string? IncomingVersion { get; set; }
    public string? AppExeName { get; set; }
    public string? ProductFolderName { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool PackageValidated { get; set; }
    public bool AppStopped { get; set; }
    public bool InstallBackedUp { get; set; }
    public bool DatabaseBackedUp { get; set; }
    public bool FilesSwapped { get; set; }
    public bool Completed { get; set; }
}
"@

Write-Utf8File -Path (Join-Path $modelsDir "UpdateState.cs") -Content $updateStateCs

$dbBackupCs = @"
using System;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class DatabaseBackupService
{
    public static string BackupSqlite(string dbPath)
    {
        if (string.IsNullOrWhiteSpace(dbPath))
            throw new ArgumentException("Database path is required.", nameof(dbPath));

        if (!File.Exists(dbPath))
            throw new FileNotFoundException("Database not found.", dbPath);

        var dbDir = Path.GetDirectoryName(dbPath)!;
        var backupDir = Path.Combine(dbDir, "backup");
        Directory.CreateDirectory(backupDir);

        var fileName = Path.GetFileNameWithoutExtension(dbPath);
        var extension = Path.GetExtension(dbPath);
        var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");

        var backupPath = Path.Combine(backupDir, fileName + "_backup_" + timestamp + extension);
        File.Copy(dbPath, backupPath, true);

        return backupPath;
    }

    public static void RestoreSqlite(string backupPath, string dbPath)
    {
        if (!File.Exists(backupPath))
            throw new FileNotFoundException("SQLite backup not found.", backupPath);

        var dir = Path.GetDirectoryName(dbPath);
        if (!string.IsNullOrWhiteSpace(dir))
            Directory.CreateDirectory(dir);

        File.Copy(backupPath, dbPath, true);
    }

    public static string? ResolveDatabasePath(string installDir, string productFolderName)
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

        var candidates = new[]
        {
            Path.Combine(localAppData, productFolderName, "main.db"),
            Path.Combine(localAppData, "MyCompanyApp", "main.db"),
            Path.Combine(installDir, "Data", "main.db"),
            Path.Combine(installDir, "main.db")
        };

        foreach (var candidate in candidates)
        {
            if (File.Exists(candidate))
                return candidate;
        }

        return candidates[0];
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "DatabaseBackupService.cs") -Content $dbBackupCs

$installBackupCs = @"
using System;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class InstallationBackupService
{
    public static string BackupInstallation(string installDir)
    {
        if (string.IsNullOrWhiteSpace(installDir))
            throw new ArgumentException("Install directory is required.", nameof(installDir));

        if (!Directory.Exists(installDir))
            throw new DirectoryNotFoundException("Install directory not found: " + installDir);

        var parent = Directory.GetParent(installDir)?.FullName
                     ?? throw new InvalidOperationException("Cannot determine parent directory for: " + installDir);

        var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
        var backupDir = Path.Combine(parent, Path.GetFileName(installDir) + "_backup_" + timestamp);

        CopyDirectory(installDir, backupDir);
        return backupDir;
    }

    public static void CopyDirectory(string sourceDir, string destinationDir)
    {
        var source = new DirectoryInfo(sourceDir);
        if (!source.Exists)
            throw new DirectoryNotFoundException("Source directory not found: " + sourceDir);

        Directory.CreateDirectory(destinationDir);

        foreach (var file in source.GetFiles())
        {
            file.CopyTo(Path.Combine(destinationDir, file.Name), true);
        }

        foreach (var subDir in source.GetDirectories())
        {
            CopyDirectory(subDir.FullName, Path.Combine(destinationDir, subDir.Name));
        }
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "InstallationBackupService.cs") -Content $installBackupCs

$rollbackCs = @"
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class RollbackService
{
    public static void RestoreDatabase(string backupDbPath, string databasePath)
    {
        if (!File.Exists(backupDbPath))
            throw new FileNotFoundException(backupDbPath);

        var dir = Path.GetDirectoryName(databasePath);
        if (!string.IsNullOrWhiteSpace(dir))
            Directory.CreateDirectory(dir);

        File.Copy(backupDbPath, databasePath, true);
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "RollbackService.cs") -Content $rollbackCs

$hashValidationCs = @"
using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;

namespace MyCompanyApp.Updater.Services;

public static class HashValidationService
{
    public static void ValidatePayloadChecksums(string extractedRoot)
    {
        var checksumFile = Path.Combine(extractedRoot, "checksums.sha256");
        if (!File.Exists(checksumFile))
        {
            Console.WriteLine("checksums.sha256 not found. Skipping payload hash validation.");
            return;
        }

        var payloadDir = Path.Combine(extractedRoot, "Payload");
        if (!Directory.Exists(payloadDir))
            throw new DirectoryNotFoundException("Payload folder not found: " + payloadDir);

        foreach (var line in File.ReadAllLines(checksumFile).Where(x => !string.IsNullOrWhiteSpace(x)))
        {
            var parts = line.Trim().Split(new[] { "  " }, 2, StringSplitOptions.None);
            if (parts.Length != 2)
                throw new FormatException("Invalid checksum line: " + line);

            var expectedHash = parts[0].Trim();
            var relativePath = parts[1].Trim().Replace('/', Path.DirectorySeparatorChar);
            var fullPath = Path.Combine(payloadDir, relativePath);

            if (!File.Exists(fullPath))
                throw new FileNotFoundException("File listed in checksum not found.", fullPath);

            var actualHash = ComputeSha256(fullPath);

            if (!string.Equals(expectedHash, actualHash, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException($"Checksum mismatch for '{relativePath}'.");
        }
    }

    public static string ComputeSha256(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        using var sha = SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(stream)).ToLowerInvariant();
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "HashValidationService.cs") -Content $hashValidationCs

$packageReaderCs = @"
using System;
using System.IO;
using System.IO.Compression;
using System.Text.Json;
using MyCompanyApp.Updater.Models;

namespace MyCompanyApp.Updater.Services;

public static class PackageReaderService
{
    public static string ExtractToTemp(string packageZipPath)
    {
        if (!File.Exists(packageZipPath))
            throw new FileNotFoundException("Package zip not found.", packageZipPath);

        var tempRoot = Path.Combine(Path.GetTempPath(), "MyCompanyAppUpdater");
        Directory.CreateDirectory(tempRoot);

        var extractDir = Path.Combine(tempRoot, "pkg_" + DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));
        Directory.CreateDirectory(extractDir);

        ZipFile.ExtractToDirectory(packageZipPath, extractDir);
        return extractDir;
    }

    public static UpdateMetadata ReadMetadata(string extractedRoot)
    {
        var metadataPath = Path.Combine(extractedRoot, "metadata.json");
        if (!File.Exists(metadataPath))
            throw new FileNotFoundException("metadata.json not found.", metadataPath);

        var json = File.ReadAllText(metadataPath);
        return JsonSerializer.Deserialize<UpdateMetadata>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? throw new InvalidOperationException("Failed to deserialize metadata.json");
    }

    public static string GetPayloadDirectory(string extractedRoot)
    {
        var payloadDir = Path.Combine(extractedRoot, "Payload");
        if (!Directory.Exists(payloadDir))
            throw new DirectoryNotFoundException("Payload directory not found: " + payloadDir);

        return payloadDir;
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "PackageReaderService.cs") -Content $packageReaderCs

$versionServiceCs = @"
using System;
using System.Diagnostics;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class VersionService
{
    public static string? ReadInstalledVersion(string installDir, string exeName)
    {
        var exePath = Path.Combine(installDir, exeName);
        if (!File.Exists(exePath))
            return null;

        try
        {
            var info = FileVersionInfo.GetVersionInfo(exePath);
            return string.IsNullOrWhiteSpace(info.FileVersion) ? null : NormalizeVersion(info.FileVersion);
        }
        catch
        {
            return null;
        }
    }

    public static void EnsureNotDowngrade(string? installedVersion, string? incomingVersion)
    {
        if (string.IsNullOrWhiteSpace(incomingVersion))
            throw new InvalidOperationException("Incoming package version is missing.");

        if (string.IsNullOrWhiteSpace(installedVersion))
            return;

        var current = Version.Parse(NormalizeVersion(installedVersion));
        var incoming = Version.Parse(NormalizeVersion(incomingVersion));

        if (incoming < current)
            throw new InvalidOperationException("Downgrade blocked.");
        if (incoming == current)
            throw new InvalidOperationException("Same version blocked.");
    }

    private static string NormalizeVersion(string v)
    {
        v = v.Trim();
        var plus = v.IndexOf('+');
        if (plus >= 0) v = v.Substring(0, plus);
        var dash = v.IndexOf('-');
        if (dash >= 0) v = v.Substring(0, dash);
        return v.Trim();
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "VersionService.cs") -Content $versionServiceCs

$processHelperCs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace MyCompanyApp.Updater.Services;

public static class ProcessHelper
{
    public static void StopRunningApplication(string exeName)
    {
        var processName = Path.GetFileNameWithoutExtension(exeName);

        foreach (var process in Process.GetProcessesByName(processName))
        {
            try
            {
                process.Kill(true);
                process.WaitForExit(15000);
            }
            catch
            {
            }
        }

        Thread.Sleep(1000);
    }

    public static void EnsureFileUnlocked(string filePath, int retries = 15, int delayMs = 1000)
    {
        for (var i = 0; i < retries; i++)
        {
            try
            {
                using var stream = new FileStream(filePath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
                return;
            }
            catch
            {
                Thread.Sleep(delayMs);
            }
        }

        throw new IOException("File remained locked after retries: " + filePath);
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "ProcessHelper.cs") -Content $processHelperCs

$safeOrchestratorCs = @"
using System;
using System.IO;
using System.Text.Json;
using MyCompanyApp.Updater.Models;

namespace MyCompanyApp.Updater.Services;

public sealed class SafeUpdateOrchestrator
{
    public void Apply(string packageZipPath, string installDirectory, string productFolderName)
    {
        string? extractedRoot = null;
        string? installBackupDir = null;
        string? databasePath = null;
        string? databaseBackupPath = null;
        string? appExeName = null;

        var statePath = Path.Combine(installDirectory, "update_state.json");

        try
        {
            Directory.CreateDirectory(installDirectory);

            extractedRoot = PackageReaderService.ExtractToTemp(packageZipPath);
            var metadata = PackageReaderService.ReadMetadata(extractedRoot);

            appExeName = string.IsNullOrWhiteSpace(metadata.AppExeName) ? "$AppExeName" : metadata.AppExeName;

            HashValidationService.ValidatePayloadChecksums(extractedRoot);

            var incomingVersion = metadata.Version;
            var currentVersion = VersionService.ReadInstalledVersion(installDirectory, appExeName);
            VersionService.EnsureNotDowngrade(currentVersion, incomingVersion);

            ProcessHelper.StopRunningApplication(appExeName);

            installBackupDir = InstallationBackupService.BackupInstallation(installDirectory);

            databasePath = DatabaseBackupService.ResolveDatabasePath(installDirectory, productFolderName);
            if (!string.IsNullOrWhiteSpace(databasePath) && File.Exists(databasePath))
            {
                databaseBackupPath = DatabaseBackupService.BackupSqlite(databasePath);
            }

            var payloadDir = PackageReaderService.GetPayloadDirectory(extractedRoot);

            if (Directory.Exists(installDirectory))
                Directory.Delete(installDirectory, true);

            InstallationBackupService.CopyDirectory(payloadDir, installDirectory);

            if (!File.Exists(Path.Combine(installDirectory, appExeName)))
                throw new FileNotFoundException("Health check failed. Main executable not found.");

            TryDeleteFile(statePath);
        }
        catch
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(installBackupDir) && Directory.Exists(installBackupDir))
                {
                    if (Directory.Exists(installDirectory))
                        Directory.Delete(installDirectory, true);

                    Directory.Move(installBackupDir, installDirectory);
                }
            }
            catch { }

            try
            {
                if (!string.IsNullOrWhiteSpace(databaseBackupPath) &&
                    !string.IsNullOrWhiteSpace(databasePath) &&
                    File.Exists(databaseBackupPath))
                {
                    RollbackService.RestoreDatabase(databaseBackupPath, databasePath);
                }
            }
            catch { }

            throw;
        }
        finally
        {
            TryDeleteDirectory(extractedRoot);
        }
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
                File.Delete(path);
        }
        catch { }
    }

    private static void TryDeleteDirectory(string? path)
    {
        try
        {
            if (!string.IsNullOrWhiteSpace(path) && Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch { }
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "SafeUpdateOrchestrator.cs") -Content $safeOrchestratorCs

Write-Step "2) Patching csproj"

$csprojText = Get-Content -Path $csproj.FullName -Raw
if ($csprojText -notmatch "<ImplicitUsings>") {
    $csprojText = $csprojText -replace "</PropertyGroup>", "  <ImplicitUsings>enable</ImplicitUsings>`r`n  <Nullable>enable</Nullable>`r`n</PropertyGroup>"
    [System.IO.File]::WriteAllText($csproj.FullName, $csprojText, [System.Text.UTF8Encoding]::new($false))
}

if ($BuildAfterPatch) {
    Write-Step "3) Build"
    Push-Location $updaterDir
    try {
        dotnet build $csproj.FullName -c Release
        if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }
}

Write-Host "Done." -ForegroundColor Green
