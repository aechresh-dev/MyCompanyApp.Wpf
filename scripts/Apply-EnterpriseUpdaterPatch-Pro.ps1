param(
    [string]$RootPath = (Get-Location).Path,
    [string]$UpdaterProjectRelativePath = "MyCompanyApp.Updater",
    [string]$AppExeName = "MyCompanyApp.Wpf.exe",
    [string]$ProductFolderName = "MyCompanyApp",
    [switch]$BuildAfterPatch
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkCyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor DarkCyan
}

function Ensure-Dir {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory) {
        Ensure-Dir $directory
    }

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Patch-CSharpProject {
    param([string]$ProjectPath)

    [xml]$projectXml = Get-Content -Path $ProjectPath -Raw

    $propertyGroup = $projectXml.Project.PropertyGroup | Select-Object -First 1
    if (-not $propertyGroup) {
        throw "No PropertyGroup found in project file: $ProjectPath"
    }

    if (-not $propertyGroup.ImplicitUsings) {
        $node = $projectXml.CreateElement("ImplicitUsings")
        $node.InnerText = "enable"
        $propertyGroup.AppendChild($node) | Out-Null
    }

    if (-not $propertyGroup.Nullable) {
        $node = $projectXml.CreateElement("Nullable")
        $node.InnerText = "enable"
        $propertyGroup.AppendChild($node) | Out-Null
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)

    $writer = [System.Xml.XmlWriter]::Create($ProjectPath, $settings)
    try {
        $projectXml.Save($writer)
    }
    finally {
        $writer.Dispose()
    }
}

$root = (Resolve-Path -LiteralPath $RootPath).Path
$updaterDir = Join-Path $root $UpdaterProjectRelativePath

if (-not (Test-Path -LiteralPath $updaterDir)) {
    throw "Updater project directory not found: $updaterDir"
}

$csproj = Get-ChildItem -Path $updaterDir -Filter *.csproj | Select-Object -First 1
if (-not $csproj) {
    throw "No .csproj file found in updater directory: $updaterDir"
}

$modelsDir = Join-Path $updaterDir "Models"
$servicesDir = Join-Path $updaterDir "Services"

Ensure-Dir $modelsDir
Ensure-Dir $servicesDir

Write-Step "1) Writing updater models"

$updateMetadataCs = @'
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
'@

Write-Utf8File -Path (Join-Path $modelsDir "UpdateMetadata.cs") -Content $updateMetadataCs

$updateStateCs = @'
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
    public DateTime UpdatedAtUtc { get; set; }
    public bool PackageExtracted { get; set; }
    public bool PackageValidated { get; set; }
    public bool VersionValidated { get; set; }
    public bool AppStopped { get; set; }
    public bool InstallBackedUp { get; set; }
    public bool DatabaseBackedUp { get; set; }
    public bool FilesSwapped { get; set; }
    public bool HealthChecked { get; set; }
    public bool Completed { get; set; }
}
'@

Write-Utf8File -Path (Join-Path $modelsDir "UpdateState.cs") -Content $updateStateCs

Write-Step "2) Writing updater services"

$updateStateStoreCs = @'
using System;
using System.IO;
using System.Text.Json;
using MyCompanyApp.Updater.Models;

namespace MyCompanyApp.Updater.Services;

public sealed class UpdateStateStore
{
    private readonly string _statePath;

    public UpdateStateStore(string statePath)
    {
        if (string.IsNullOrWhiteSpace(statePath))
            throw new ArgumentException("State path is required.", nameof(statePath));

        _statePath = statePath;
    }

    public void Save(UpdateState state)
    {
        state.UpdatedAtUtc = DateTime.UtcNow;

        var directory = Path.GetDirectoryName(_statePath);
        if (!string.IsNullOrWhiteSpace(directory))
            Directory.CreateDirectory(directory);

        var json = JsonSerializer.Serialize(state, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        File.WriteAllText(_statePath, json);
    }

    public UpdateState? Load()
    {
        if (!File.Exists(_statePath))
            return null;

        var json = File.ReadAllText(_statePath);
        return JsonSerializer.Deserialize<UpdateState>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
    }

    public void Delete()
    {
        if (File.Exists(_statePath))
            File.Delete(_statePath);
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "UpdateStateStore.cs") -Content $updateStateStoreCs

$packageReaderCs = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Text.Json;
using MyCompanyApp.Updater.Models;

namespace MyCompanyApp.Updater.Services;

public static class PackageReaderService
{
    public static string ExtractToStaging(string packageZipPath)
    {
        if (string.IsNullOrWhiteSpace(packageZipPath))
            throw new ArgumentException("Package path is required.", nameof(packageZipPath));

        if (!File.Exists(packageZipPath))
            throw new FileNotFoundException("Package zip not found.", packageZipPath);

        var stagingRoot = Path.Combine(Path.GetTempPath(), "MyCompanyAppUpdater");
        Directory.CreateDirectory(stagingRoot);

        var stagingDirectory = Path.Combine(stagingRoot, "staging_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fff"));
        Directory.CreateDirectory(stagingDirectory);

        ZipFile.ExtractToDirectory(packageZipPath, stagingDirectory);
        return stagingDirectory;
    }

    public static UpdateMetadata ReadMetadata(string extractedRoot)
    {
        var metadataPath = Path.Combine(extractedRoot, "metadata.json");
        if (!File.Exists(metadataPath))
            throw new FileNotFoundException("metadata.json not found in package.", metadataPath);

        var json = File.ReadAllText(metadataPath);

        return JsonSerializer.Deserialize<UpdateMetadata>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? throw new InvalidOperationException("metadata.json could not be deserialized.");
    }

    public static string GetPayloadDirectory(string extractedRoot)
    {
        var payloadDirectory = Path.Combine(extractedRoot, "Payload");
        if (!Directory.Exists(payloadDirectory))
            throw new DirectoryNotFoundException("Payload directory not found: " + payloadDirectory);

        return payloadDirectory;
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "PackageReaderService.cs") -Content $packageReaderCs

$hashValidationCs = @'
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
            Console.WriteLine("checksums.sha256 not found. Hash validation skipped.");
            return;
        }

        var payloadDirectory = Path.Combine(extractedRoot, "Payload");
        if (!Directory.Exists(payloadDirectory))
            throw new DirectoryNotFoundException("Payload directory not found: " + payloadDirectory);

        foreach (var line in File.ReadAllLines(checksumFile).Where(x => !string.IsNullOrWhiteSpace(x)))
        {
            var parts = line.Trim().Split(new[] { "  " }, 2, StringSplitOptions.None);
            if (parts.Length != 2)
                throw new FormatException("Invalid checksum line: " + line);

            var expectedHash = parts[0].Trim();
            var relativePath = parts[1].Trim().Replace('/', Path.DirectorySeparatorChar);
            var fullPath = Path.Combine(payloadDirectory, relativePath);

            if (!File.Exists(fullPath))
                throw new FileNotFoundException("File listed in checksums.sha256 was not found.", fullPath);

            var actualHash = ComputeSha256(fullPath);

            if (!string.Equals(expectedHash, actualHash, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Checksum mismatch: " + relativePath);
        }
    }

    public static string ComputeSha256(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        using var sha256 = SHA256.Create();
        return Convert.ToHexString(sha256.ComputeHash(stream)).ToLowerInvariant();
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "HashValidationService.cs") -Content $hashValidationCs

$versionServiceCs = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace MyCompanyApp.Updater.Services;

public static class VersionService
{
    public static string? ReadInstalledVersion(string installDirectory, string exeName)
    {
        var exePath = Path.Combine(installDirectory, exeName);

        if (!File.Exists(exePath))
            return null;

        try
        {
            var info = FileVersionInfo.GetVersionInfo(exePath);

            if (!string.IsNullOrWhiteSpace(info.ProductVersion))
                return NormalizeVersion(info.ProductVersion);

            if (!string.IsNullOrWhiteSpace(info.FileVersion))
                return NormalizeVersion(info.FileVersion);

            return null;
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

        var current = ParseVersion(installedVersion);
        var incoming = ParseVersion(incomingVersion);

        if (incoming < current)
            throw new InvalidOperationException("Downgrade blocked. Current=" + current + ", Incoming=" + incoming);

        if (incoming == current)
            throw new InvalidOperationException("Same version blocked. Current=" + current + ", Incoming=" + incoming);
    }

    private static Version ParseVersion(string version)
    {
        var normalized = NormalizeVersion(version);
        return Version.Parse(normalized);
    }

    private static string NormalizeVersion(string version)
    {
        var normalized = version.Trim();

        var plusIndex = normalized.IndexOf('+');
        if (plusIndex >= 0)
            normalized = normalized[..plusIndex];

        var dashIndex = normalized.IndexOf('-');
        if (dashIndex >= 0)
            normalized = normalized[..dashIndex];

        var numericPart = new string(normalized.TakeWhile(c => char.IsDigit(c) || c == '.').ToArray());

        if (string.IsNullOrWhiteSpace(numericPart))
            throw new FormatException("Invalid version: " + version);

        return numericPart;
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "VersionService.cs") -Content $versionServiceCs

$processHelperCs = @'
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
                Console.WriteLine("Stopping running process: " + process.ProcessName + " / PID=" + process.Id);
                process.Kill(true);
                process.WaitForExit(15000);
            }
            catch
            {
            }
            finally
            {
                process.Dispose();
            }
        }

        Thread.Sleep(1000);
    }

    public static void EnsureFileUnlocked(string filePath, int retries = 15, int delayMs = 1000)
    {
        for (var attempt = 1; attempt <= retries; attempt++)
        {
            try
            {
                using var stream = new FileStream(filePath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
                return;
            }
            catch
            {
                if (attempt == retries)
                    throw;

                Thread.Sleep(delayMs);
            }
        }
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "ProcessHelper.cs") -Content $processHelperCs

$installationBackupCs = @'
using System;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class InstallationBackupService
{
    public static string BackupInstallation(string installDirectory)
    {
        if (string.IsNullOrWhiteSpace(installDirectory))
            throw new ArgumentException("Install directory is required.", nameof(installDirectory));

        if (!Directory.Exists(installDirectory))
            throw new DirectoryNotFoundException("Install directory not found: " + installDirectory);

        var parentDirectory = Directory.GetParent(installDirectory)?.FullName
            ?? throw new InvalidOperationException("Could not resolve parent directory for: " + installDirectory);

        var backupDirectory = Path.Combine(
            parentDirectory,
            Path.GetFileName(installDirectory).TrimEnd(Path.DirectorySeparatorChar) + "_backup_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmmss"));

        CopyDirectory(installDirectory, backupDirectory, true);

        return backupDirectory;
    }

    public static void CopyDirectory(string sourceDirectory, string destinationDirectory, bool overwrite)
    {
        var source = new DirectoryInfo(sourceDirectory);

        if (!source.Exists)
            throw new DirectoryNotFoundException("Source directory not found: " + sourceDirectory);

        Directory.CreateDirectory(destinationDirectory);

        foreach (var file in source.GetFiles())
        {
            var destinationPath = Path.Combine(destinationDirectory, file.Name);
            file.CopyTo(destinationPath, overwrite);
        }

        foreach (var directory in source.GetDirectories())
        {
            var destinationPath = Path.Combine(destinationDirectory, directory.Name);
            CopyDirectory(directory.FullName, destinationPath, overwrite);
        }
    }

    public static void ReplaceDirectory(string sourceDirectory, string destinationDirectory)
    {
        var tempOldDirectory = destinationDirectory + "_old_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fff");

        if (Directory.Exists(tempOldDirectory))
            Directory.Delete(tempOldDirectory, true);

        if (Directory.Exists(destinationDirectory))
            Directory.Move(destinationDirectory, tempOldDirectory);

        try
        {
            CopyDirectory(sourceDirectory, destinationDirectory, true);
            Directory.Delete(tempOldDirectory, true);
        }
        catch
        {
            if (Directory.Exists(destinationDirectory))
                Directory.Delete(destinationDirectory, true);

            if (Directory.Exists(tempOldDirectory))
                Directory.Move(tempOldDirectory, destinationDirectory);

            throw;
        }
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "InstallationBackupService.cs") -Content $installationBackupCs

$databaseBackupCs = @'
using System;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class DatabaseBackupService
{
    public static string? ResolveDatabasePath(string installDirectory, string productFolderName)
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

        var candidates = new[]
        {
            Path.Combine(localAppData, productFolderName, "main.db"),
            Path.Combine(localAppData, "MyCompanyApp", "main.db"),
            Path.Combine(installDirectory, "Data", "main.db"),
            Path.Combine(installDirectory, "main.db")
        };

        foreach (var candidate in candidates)
        {
            if (File.Exists(candidate))
                return candidate;
        }

        return candidates[0];
    }

    public static string? BackupSqliteIfExists(string? databasePath)
    {
        if (string.IsNullOrWhiteSpace(databasePath))
            return null;

        if (!File.Exists(databasePath))
            return null;

        var databaseDirectory = Path.GetDirectoryName(databasePath);
        if (string.IsNullOrWhiteSpace(databaseDirectory))
            throw new InvalidOperationException("Could not resolve database directory: " + databasePath);

        var backupDirectory = Path.Combine(databaseDirectory, "backup");
        Directory.CreateDirectory(backupDirectory);

        var fileName = Path.GetFileNameWithoutExtension(databasePath);
        var extension = Path.GetExtension(databasePath);
        var backupPath = Path.Combine(backupDirectory, fileName + "_backup_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmmss") + extension);

        File.Copy(databasePath, backupPath, true);

        return backupPath;
    }

    public static void RestoreSqlite(string backupPath, string databasePath)
    {
        if (!File.Exists(backupPath))
            throw new FileNotFoundException("SQLite backup not found.", backupPath);

        var targetDirectory = Path.GetDirectoryName(databasePath);
        if (!string.IsNullOrWhiteSpace(targetDirectory))
            Directory.CreateDirectory(targetDirectory);

        File.Copy(backupPath, databasePath, true);
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "DatabaseBackupService.cs") -Content $databaseBackupCs

$rollbackServiceCs = @'
using System;
using System.IO;

namespace MyCompanyApp.Updater.Services;

public static class RollbackService
{
    public static void RestoreInstallation(string? installBackupDirectory, string installDirectory)
    {
        if (string.IsNullOrWhiteSpace(installBackupDirectory))
            return;

        if (!Directory.Exists(installBackupDirectory))
            return;

        if (Directory.Exists(installDirectory))
            Directory.Delete(installDirectory, true);

        InstallationBackupService.CopyDirectory(installBackupDirectory, installDirectory, true);
    }

    public static void RestoreDatabase(string? databaseBackupPath, string? databasePath)
    {
        if (string.IsNullOrWhiteSpace(databaseBackupPath))
            return;

        if (string.IsNullOrWhiteSpace(databasePath))
            return;

        if (!File.Exists(databaseBackupPath))
            return;

        DatabaseBackupService.RestoreSqlite(databaseBackupPath, databasePath);
    }
}
'@

Write-Utf8File -Path (Join-Path $servicesDir "RollbackService.cs") -Content $rollbackServiceCs

$safeUpdateOrchestratorCs = @"
using System;
using System.IO;
using MyCompanyApp.Updater.Models;

namespace MyCompanyApp.Updater.Services;

public sealed class SafeUpdateOrchestrator
{
    public void Apply(string packageZipPath, string installDirectory, string productFolderName)
    {
        if (string.IsNullOrWhiteSpace(packageZipPath))
            throw new ArgumentException("Package zip path is required.", nameof(packageZipPath));

        if (string.IsNullOrWhiteSpace(installDirectory))
            throw new ArgumentException("Install directory is required.", nameof(installDirectory));

        if (string.IsNullOrWhiteSpace(productFolderName))
            throw new ArgumentException("Product folder name is required.", nameof(productFolderName));

        Directory.CreateDirectory(installDirectory);

        var statePath = Path.Combine(installDirectory, "update_state.json");
        var stateStore = new UpdateStateStore(statePath);

        var state = new UpdateState
        {
            PackageZipPath = packageZipPath,
            InstallDirectory = installDirectory,
            ProductFolderName = productFolderName,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };

        string? stagingDirectory = null;

        try
        {
            stateStore.Save(state);

            stagingDirectory = PackageReaderService.ExtractToStaging(packageZipPath);
            state.StagingDirectory = stagingDirectory;
            state.PackageExtracted = true;
            stateStore.Save(state);

            var metadata = PackageReaderService.ReadMetadata(stagingDirectory);
            var appExeName = string.IsNullOrWhiteSpace(metadata.AppExeName) ? "$AppExeName" : metadata.AppExeName;

            state.AppExeName = appExeName;
            state.IncomingVersion = metadata.Version;
            stateStore.Save(state);

            HashValidationService.ValidatePayloadChecksums(stagingDirectory);
            state.PackageValidated = true;
            stateStore.Save(state);

            var installedVersion = VersionService.ReadInstalledVersion(installDirectory, appExeName);
            state.PreviousVersion = installedVersion;

            VersionService.EnsureNotDowngrade(installedVersion, metadata.Version);
            state.VersionValidated = true;
            stateStore.Save(state);

            ProcessHelper.StopRunningApplication(appExeName);
            state.AppStopped = true;
            stateStore.Save(state);

            var exePath = Path.Combine(installDirectory, appExeName);
            if (File.Exists(exePath))
                ProcessHelper.EnsureFileUnlocked(exePath);

            state.InstallBackupDirectory = InstallationBackupService.BackupInstallation(installDirectory);
            state.InstallBackedUp = true;
            stateStore.Save(state);

            state.DatabasePath = DatabaseBackupService.ResolveDatabasePath(installDirectory, productFolderName);
            state.DatabaseBackupPath = DatabaseBackupService.BackupSqliteIfExists(state.DatabasePath);
            state.DatabaseBackedUp = !string.IsNullOrWhiteSpace(state.DatabaseBackupPath);
            stateStore.Save(state);

            var payloadDirectory = PackageReaderService.GetPayloadDirectory(stagingDirectory);

            InstallationBackupService.ReplaceDirectory(payloadDirectory, installDirectory);
            state.FilesSwapped = true;
            stateStore.Save(state);

            var installedExePath = Path.Combine(installDirectory, appExeName);
            if (!File.Exists(installedExePath))
                throw new FileNotFoundException("Health check failed. Main executable was not found after update.", installedExePath);

            state.HealthChecked = true;
            state.Completed = true;
            stateStore.Save(state);

            stateStore.Delete();
        }
        catch
        {
            try
            {
                RollbackService.RestoreInstallation(state.InstallBackupDirectory, installDirectory);
            }
            catch
            {
            }

            try
            {
                RollbackService.RestoreDatabase(state.DatabaseBackupPath, state.DatabasePath);
            }
            catch
            {
            }

            throw;
        }
        finally
        {
            TryDeleteDirectory(stagingDirectory);
        }
    }

    private static void TryDeleteDirectory(string? directory)
    {
        try
        {
            if (!string.IsNullOrWhiteSpace(directory) && Directory.Exists(directory))
                Directory.Delete(directory, true);
        }
        catch
        {
        }
    }
}
"@

Write-Utf8File -Path (Join-Path $servicesDir "SafeUpdateOrchestrator.cs") -Content $safeUpdateOrchestratorCs

Write-Step "3) Writing Program.cs"

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
            Console.WriteLine("Update failed:");
            Console.WriteLine(ex);
            return -1;
        }
    }
}
"@

Write-Utf8File -Path (Join-Path $updaterDir "Program.cs") -Content $programCs

Write-Step "4) Patching updater project"

Patch-CSharpProject -ProjectPath $csproj.FullName

if ($BuildAfterPatch) {
    Write-Step "5) Building updater"

    Push-Location $updaterDir
    try {
        dotnet build $csproj.FullName -c Release

        if ($LASTEXITCODE -ne 0) {
            throw "Build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Enterprise updater patch completed successfully." -ForegroundColor Green
Write-Host "Updater project: $($csproj.FullName)" -ForegroundColor Green
