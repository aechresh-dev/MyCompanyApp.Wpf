param(
    [string]$RootPath = (Get-Location).Path,
    [string]$UpdaterProjectRelativePath = "src\MyCompanyApp.Updater",
    [string]$AppExeName = "MyCompanyApp.Wpf.exe",
    [string]$ProductFolderName = "MyCompanyApp",
    [switch]$BuildAfterPatch = $true
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkCyan
    Write-Host $msg -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor DarkCyan
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )
    $dir = Split-Path $Path -Parent
    Ensure-Dir $dir
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

Write-Step "1) Writing updater source files"

# ---------------- Program.cs ----------------
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

# ---------------- Models/UpdateMetadata.cs ----------------
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

# ---------------- Models/UpdateState.cs ----------------
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

# ---------------- Services/DatabaseBackupService.cs ----------------
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

# ---------------- Services/InstallationBackupService.cs ----------------
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
            var targetPath = Path.Combine(destinationDir, file.Name);
            file.CopyTo(targetPath, true);
        }

        foreach (var subDir in source.GetDirectories())
        {
            var nextDest = Path.Combine(destinationDir, subDir.Name);
            CopyDirectory(subDir.FullName, nextDest);
        }
    }

    public static void ReplaceDirectory(string sourceDir, string destinationDir)
    {
        if (Directory.Exists(destinationDir))
            Directory.Delete(destinationDir, true);

        Directory.Move(sourceDir, destinationDir);
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "InstallationBackupService.cs") -Content $installBackupCs

# ---------------- Services/RollbackService.cs ----------------
$rollbackCs = @"
using System;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class RollbackService
{
    public static void RestoreInstallation(string backupDir, string installDir)
    {
        if (string.IsNullOrWhiteSpace(backupDir) || !Directory.Exists(backupDir))
            throw new DirectoryNotFoundException("Install backup directory not found: " + backupDir);

        if (Directory.Exists(installDir))
            Directory.Delete(installDir, true);

        Directory.Move(backupDir, installDir);
    }

    public static void RestoreDatabase(string backupDbPath, string databasePath)
    {
        if (string.IsNullOrWhiteSpace(backupDbPath) || !File.Exists(backupDbPath))
            throw new FileNotFoundException("Database backup not found.", backupDbPath);

        var dir = Path.GetDirectoryName(databasePath);
        if (!string.IsNullOrWhiteSpace(dir))
            Directory.CreateDirectory(dir);

        File.Copy(backupDbPath, databasePath, true);
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "RollbackService.cs") -Content $rollbackCs

# ---------------- Services/HashValidationService.cs ----------------
$hashValidationCs = @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

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
            throw new DirectoryNotFoundException("Payload folder not found in package: " + payloadDir);

        var lines = File.ReadAllLines(checksumFile)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .ToArray();

        foreach (var line in lines)
        {
            var parts = SplitChecksumLine(line);
            var expectedHash = parts.hash;
            var relativePath = parts.relativePath.Replace('/', Path.DirectorySeparatorChar);

            var fullPath = Path.Combine(payloadDir, relativePath);
            if (!File.Exists(fullPath))
                throw new FileNotFoundException("File listed in checksum not found.", fullPath);

            var actualHash = ComputeSha256(fullPath);

            if (!string.Equals(expectedHash, actualHash, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Checksum mismatch for file '" + relativePath + "'. Expected: " + expectedHash + ", Actual: " + actualHash);
            }
        }
    }

    private static (string hash, string relativePath) SplitChecksumLine(string line)
    {
        var normalized = line.Trim();

        var doubleSpaceIndex = normalized.IndexOf("  ", StringComparison.Ordinal);
        if (doubleSpaceIndex > 0)
        {
            var hash = normalized.Substring(0, doubleSpaceIndex).Trim();
            var path = normalized.Substring(doubleSpaceIndex).Trim();
            return (hash, path);
        }

        var singleSplit = normalized.Split(new[] { ' ' }, 2, StringSplitOptions.RemoveEmptyEntries);
        if (singleSplit.Length == 2)
            return (singleSplit[0].Trim(), singleSplit[1].Trim());

        throw new FormatException("Invalid checksum line: " + line);
    }

    public static string ComputeSha256(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(stream);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "HashValidationService.cs") -Content $hashValidationCs

# ---------------- Services/PackageReaderService.cs ----------------
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
            throw new FileNotFoundException("metadata.json not found in package.", metadataPath);

        var json = File.ReadAllText(metadataPath);
        var metadata = JsonSerializer.Deserialize<UpdateMetadata>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (metadata == null)
            throw new InvalidOperationException("Failed to deserialize metadata.json");

        return metadata;
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

# ---------------- Services/VersionService.cs ----------------
$versionServiceCs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

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
            if (!string.IsNullOrWhiteSpace(info.FileVersion))
                return NormalizeVersion(info.FileVersion);

            var assemblyName = AssemblyName.GetAssemblyName(exePath);
            if (assemblyName.Version != null)
                return assemblyName.Version.ToString();
        }
        catch
        {
        }

        return null;
    }

    public static void EnsureNotDowngrade(string? installedVersion, string? incomingVersion)
    {
        if (string.IsNullOrWhiteSpace(incomingVersion))
            throw new InvalidOperationException("Incoming package version is missing.");

        if (string.IsNullOrWhiteSpace(installedVersion))
        {
            Console.WriteLine("Installed version not found. Treating as first install/update.");
            return;
        }

        var current = ParseVersionLenient(installedVersion);
        var incoming = ParseVersionLenient(incomingVersion);

        if (incoming < current)
            throw new InvalidOperationException("Downgrade blocked. Installed=" + current + ", Incoming=" + incoming);

        if (incoming == current)
            throw new InvalidOperationException("Same version update blocked. Installed=" + current + ", Incoming=" + incoming);
    }

    private static Version ParseVersionLenient(string versionText)
    {
        versionText = NormalizeVersion(versionText);

        if (Version.TryParse(versionText, out var parsed))
            return parsed;

        throw new InvalidOperationException("Invalid version format: " + versionText);
    }

    private static string NormalizeVersion(string versionText)
    {
        versionText = versionText.Trim();

        var plus = versionText.IndexOf('+');
        if (plus >= 0)
            versionText = versionText.Substring(0, plus);

        var dash = versionText.IndexOf('-');
        if (dash >= 0)
            versionText = versionText.Substring(0, dash);

        return versionText.Trim();
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "VersionService.cs") -Content $versionServiceCs

# ---------------- Services/ProcessHelper.cs ----------------
$processHelperCs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;

namespace MyCompanyApp.Updater.Services;

public static class ProcessHelper
{
    public static void StopRunningApplication(string exeName)
    {
        if (string.IsNullOrWhiteSpace(exeName))
            throw new ArgumentException("exeName is required.", nameof(exeName));

        var processName = Path.GetFileNameWithoutExtension(exeName);

        var matching = Process.GetProcessesByName(processName);
        foreach (var process in matching)
        {
            try
            {
                Console.WriteLine("Stopping process: " + process.ProcessName + " (PID=" + process.Id + ")");
                process.Kill(true);
                process.WaitForExit(15000);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Warning: failed to stop PID " + process.Id + ": " + ex.Message);
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

# ---------------- Services/SafeUpdateOrchestrator.cs ----------------
$safeOrchestratorCs = @"
using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using MyCompanyApp.Updater.Models;

namespace MyCompanyApp.Updater.Services;

public sealed class SafeUpdateOrchestrator
{
    public void Apply(string packageZipPath, string installDirectory, string productFolderName)
    {
        if (string.IsNullOrWhiteSpace(packageZipPath))
            throw new ArgumentException("Package path is required.", nameof(packageZipPath));

        if (string.IsNullOrWhiteSpace(installDirectory))
            throw new ArgumentException("Install directory is required.", nameof(installDirectory));

        Directory.CreateDirectory(installDirectory);

        string? extractedRoot = null;
        string? stagingInstallDir = null;
        string? installBackupDir = null;
        string? databasePath = null;
        string? databaseBackupPath = null;
        string? appExeName = null;
        string? previousVersion = null;
        string? incomingVersion = null;

        var statePath = Path.Combine(installDirectory, "update_state.json");
        var state = new UpdateState
        {
            PackageZipPath = packageZipPath,
            InstallDirectory = installDirectory,
            ProductFolderName = productFolderName,
            CreatedAtUtc = DateTime.UtcNow
        };

        try
        {
            Console.WriteLine("[1/10] Extracting package...");
            extractedRoot = PackageReaderService.ExtractToTemp(packageZipPath);
            state.StagingDirectory = extractedRoot;
            SaveState(statePath, state);

            Console.WriteLine("[2/10] Reading metadata...");
            var metadata = PackageReaderService.ReadMetadata(extractedRoot);
            appExeName = string.IsNullOrWhiteSpace(metadata.AppExeName) ? "$AppExeName" : metadata.AppExeName;
            incomingVersion = metadata.Version;

            state.AppExeName = appExeName;
            state.IncomingVersion = incomingVersion;
            SaveState(statePath, state);

            Console.WriteLine("[3/10] Validating payload checksums...");
            HashValidationService.ValidatePayloadChecksums(extractedRoot);
            state.PackageValidated = true;
            SaveState(statePath, state);

            Console.WriteLine("[4/10] Checking installed version...");
            previousVersion = VersionService.ReadInstalledVersion(installDirectory, appExeName);
            state.PreviousVersion = previousVersion;
            VersionService.EnsureNotDowngrade(previousVersion, incomingVersion);
            SaveState(statePath, state);

            Console.WriteLine("[5/10] Stopping running application...");
            ProcessHelper.StopRunningApplication(appExeName);
            var installedExePath = Path.Combine(installDirectory, appExeName);
            if (File.Exists(installedExePath))
                ProcessHelper.EnsureFileUnlocked(installedExePath);
            state.AppStopped = true;
            SaveState(statePath, state);

            Console.WriteLine("[6/10] Backing up installation...");
            installBackupDir = InstallationBackupService.BackupInstallation(installDirectory);
            state.InstallBackupDirectory = installBackupDir;
            state.InstallBackedUp = true;
            SaveState(statePath, state);

            Console.WriteLine("[7/10] Resolving and backing up SQLite database...");
            databasePath = DatabaseBackupService.ResolveDatabasePath(installDirectory, productFolderName);
            state.DatabasePath = databasePath;

            if (!string.IsNullOrWhiteSpace(databasePath) && File.Exists(databasePath))
            {
                databaseBackupPath = DatabaseBackupService.BackupSqlite(databasePath);
                state.DatabaseBackupPath = databaseBackupPath;
                state.DatabaseBackedUp = true;
                SaveState(statePath, state);
                Console.WriteLine("Database backup created: " + databaseBackupPath);
            }
            else
            {
                Console.WriteLine("Database file not found. Continuing without DB backup. Expected path: " + databasePath);
                SaveState(statePath, state);
            }

            Console.WriteLine("[8/10] Preparing staged installation directory...");
            var payloadDir = PackageReaderService.GetPayloadDirectory(extractedRoot);
            stagingInstallDir = Path.Combine(Path.GetDirectoryName(installDirectory)!, Path.GetFileName(installDirectory) + "_new_" + DateTime.Now.ToString("yyyyMMdd_HHmmss"));
            InstallationBackupService.CopyDirectory(payloadDir, stagingInstallDir);

            Console.WriteLine("[9/10] Swapping directories...");
            if (Directory.Exists(installDirectory))
                Directory.Delete(installDirectory, true);

            Directory.Move(stagingInstallDir, installDirectory);
            state.FilesSwapped = true;
            SaveState(statePath, state);

            Console.WriteLine("[10/10] Running health check...");
            var newExePath = Path.Combine(installDirectory, appExeName);
            if (!File.Exists(newExePath))
                throw new FileNotFoundException("Health check failed. Main executable not found after update.", newExePath);

            state.Completed = true;
            SaveState(statePath, state);

            TryDeleteState(statePath);
            TryDeleteDirectory(extractedRoot);
            Console.WriteLine("Enterprise-safe update applied successfully.");
        }
        catch
        {
            Console.WriteLine("Update failed. Starting rollback...");

            try
            {
                if (!string.IsNullOrWhiteSpace(installBackupDir) && Directory.Exists(installBackupDir))
                {
                    if (Directory.Exists(installDirectory))
                        Directory.Delete(installDirectory, true);

                    Directory.Move(installBackupDir, installDirectory);
                    Console.WriteLine("Installation rollback completed.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Installation rollback failed: " + ex);
            }

            try
            {
                if (!string.IsNullOrWhiteSpace(databaseBackupPath) &&
                    !string.IsNullOrWhiteSpace(databasePath) &&
                    File.Exists(databaseBackupPath))
                {
                    RollbackService.RestoreDatabase(databaseBackupPath, databasePath);
                    Console.WriteLine("Database rollback completed.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Database rollback failed: " + ex);
            }

            throw;
        }
        finally
        {
            TryDeleteDirectory(stagingInstallDir);
            TryDeleteDirectory(extractedRoot);
        }
    }

    private static void SaveState(string statePath, UpdateState state)
    {
        var json = JsonSerializer.Serialize(state, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        File.WriteAllText(statePath, json);
    }

    private static void TryDeleteState(string statePath)
    {
        try
        {
            if (File.Exists(statePath))
                File.Delete(statePath);
        }
        catch
        {
        }
    }

    private static void TryDeleteDirectory(string? path)
    {
        try
        {
            if (!string.IsNullOrWhiteSpace(path) && Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch
        {
        }
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "SafeUpdateOrchestrator.cs") -Content $safeOrchestratorCs

Write-Host "Source files written successfully." -ForegroundColor Green

Write-Step "2) Checking updater csproj"

# Optional csproj patch for net8 and implicit usings / nullable if desired
$csprojText = Get-Content -Path $csproj.FullName -Raw

if ($csprojText -notmatch "<TargetFramework>") {
    throw "Updater csproj seems invalid: $($csproj.FullName)"
}

if ($csprojText -notmatch "<ImplicitUsings>") {
    $csprojText = $csprojText -replace "</PropertyGroup>", "  <ImplicitUsings>enable</ImplicitUsings>`r`n  <Nullable>enable</Nullable>`r`n</PropertyGroup>"
    [System.IO.File]::WriteAllText($csproj.FullName, $csprojText, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated csproj with ImplicitUsings/Nullable." -ForegroundColor Green
}
else {
    Write-Host "csproj already contains ImplicitUsings/Nullable or similar settings." -ForegroundColor Yellow
}

Write-Step "3) Building updater"

if ($BuildAfterPatch) {
    Push-Location $updaterDir
    try {
        dotnet build $csproj.FullName -c Release
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "Build succeeded." -ForegroundColor Green
    Write-Host "Updater project: $($csproj.FullName)" -ForegroundColor Yellow
    Write-Host "Release output examples:" -ForegroundColor Yellow

    Get-ChildItem -Path (Join-Path $updaterDir "bin\Release") -Recurse -File -Filter *.dll -ErrorAction SilentlyContinue |
        Select-Object -First 10 |
        ForEach-Object { Write-Host " - $($_.FullName)" -ForegroundColor Green }
}
else {
    Write-Host "BuildAfterPatch disabled; 