$ErrorActionPreference = "Stop"

# ==============================
# CONFIG
# ==============================

$Root = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"

$Src = Join-Path $Root "src"

$WpfProjectDir = Join-Path $Src "MyCompanyApp.Wpf"
$WpfCsproj = Join-Path $WpfProjectDir "MyCompanyApp.Wpf.csproj"

$UpdaterProjectDir = Join-Path $Src "MyCompanyApp.Updater"
$UpdaterCsproj = Join-Path $UpdaterProjectDir "MyCompanyApp.Updater.csproj"

$OfflineUpdateDir = Join-Path $WpfProjectDir "OfflineUpdate"

$PublishRoot = Join-Path $Root "Publish"
$PublishWpf = Join-Path $PublishRoot "Wpf"
$PublishUpdater = Join-Path $PublishRoot "Updater"

$PackageDir = Join-Path $Root "UpdatePackage"
$PayloadDir = Join-Path $PackageDir "payload"

$ZipPath = Join-Path $Root "MyCompanyApp_Update.zip"

$Version = "1.0.1"
$EntryExe = "MyCompanyApp.Wpf.exe"
$PackageName = "MyCompanyApp_Update.zip"

# ==============================
# HELPERS
# ==============================

function Ensure-Dir {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Clean-Dir {
    param([string]$Path)

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path | Out-Null
}

function Assert-File {
    param(
        [string]$Path,
        [string]$Message
    )

    if (!(Test-Path $Path)) {
        throw $Message
    }
}

function Write-Step {
    param([string]$Text)

    Write-Host ""
    Write-Host "========================================"
    Write-Host $Text
    Write-Host "========================================"
}

# ==============================
# PRECHECK
# ==============================

Write-Step "STEP 1 - Precheck project paths"

Assert-File $WpfCsproj "WPF project not found: $WpfCsproj"

Ensure-Dir $Src
Ensure-Dir $OfflineUpdateDir
Ensure-Dir $UpdaterProjectDir

Write-Host "Root: $Root"
Write-Host "WPF: $WpfCsproj"
Write-Host "Updater: $UpdaterCsproj"

# ==============================
# CREATE WPF OFFLINE UPDATE FILES
# ==============================

Write-Step "STEP 2 - Creating WPF OfflineUpdate files"

$OfflineManifestCode = @'
using System.Text.Json.Serialization;

namespace MyCompanyApp.Wpf.OfflineUpdate;

public sealed class OfflineUpdateManifest
{
    [JsonPropertyName("version")]
    public string Version { get; set; } = string.Empty;

    [JsonPropertyName("entryExe")]
    public string EntryExe { get; set; } = string.Empty;

    [JsonPropertyName("packageName")]
    public string PackageName { get; set; } = string.Empty;

    [JsonPropertyName("sha256")]
    public string Sha256 { get; set; } = string.Empty;

    [JsonPropertyName("force")]
    public bool Force { get; set; }
}
'@

$OfflineServiceCode = @'
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace MyCompanyApp.Wpf.OfflineUpdate;

public sealed class OfflineUpdateService
{
    public OfflineUpdateManifest Validate(string zipPath)
    {
        if (string.IsNullOrWhiteSpace(zipPath))
            throw new ArgumentException("Update zip path is empty.", nameof(zipPath));

        if (!File.Exists(zipPath))
            throw new FileNotFoundException("Update zip file not found.", zipPath);

        var tempRoot = Path.Combine(Path.GetTempPath(), "MyCompanyApp_OfflineUpdate_Validate_" + Guid.NewGuid().ToString("N"));

        Directory.CreateDirectory(tempRoot);

        try
        {
            ZipFile.ExtractToDirectory(zipPath, tempRoot, true);

            var manifestPath = Path.Combine(tempRoot, "manifest.json");

            if (!File.Exists(manifestPath))
                throw new InvalidOperationException("manifest.json was not found in update package.");

            var json = File.ReadAllText(manifestPath);

            var manifest = JsonSerializer.Deserialize<OfflineUpdateManifest>(
                json,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

            if (manifest is null)
                throw new InvalidOperationException("manifest.json is invalid.");

            if (string.IsNullOrWhiteSpace(manifest.Version))
                throw new InvalidOperationException("manifest.version is empty.");

            if (string.IsNullOrWhiteSpace(manifest.EntryExe))
                throw new InvalidOperationException("manifest.entryExe is empty.");

            if (string.IsNullOrWhiteSpace(manifest.PackageName))
                throw new InvalidOperationException("manifest.packageName is empty.");

            if (string.IsNullOrWhiteSpace(manifest.Sha256))
                throw new InvalidOperationException("manifest.sha256 is empty.");

            var payloadDir = Path.Combine(tempRoot, "payload");

            if (!Directory.Exists(payloadDir))
                throw new InvalidOperationException("payload folder was not found in update package.");

            var actualSha256 = ComputeSha256(zipPath);

            if (!actualSha256.Equals(manifest.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Update package SHA256 mismatch.");

            return manifest;
        }
        finally
        {
            TryDeleteDirectory(tempRoot);
        }
    }

    public void Install(string zipPath)
    {
        var manifest = Validate(zipPath);

        var appDir = AppContext.BaseDirectory;

        var updaterExe = Path.Combine(appDir, "MyCompanyApp.Updater.exe");

        if (!File.Exists(updaterExe))
            throw new FileNotFoundException("Updater executable not found.", updaterExe);

        var psi = new ProcessStartInfo
        {
            FileName = updaterExe,
            Arguments = $"\"{zipPath}\" \"{appDir}\" \"{manifest.EntryExe}\"",
            UseShellExecute = true,
            WorkingDirectory = appDir
        };

        Process.Start(psi);

        System.Windows.Application.Current.Shutdown();
    }

    private static string ComputeSha256(string filePath)
    {
        using var sha256 = SHA256.Create();
        using var stream = File.OpenRead(filePath);

        var hash = sha256.ComputeHash(stream);

        return Convert.ToHexString(hash);
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch
        {
            // Ignore cleanup errors.
        }
    }
}
'@

Set-Content -Path (Join-Path $OfflineUpdateDir "OfflineUpdateManifest.cs") -Value $OfflineManifestCode -Encoding UTF8
Set-Content -Path (Join-Path $OfflineUpdateDir "OfflineUpdateService.cs") -Value $OfflineServiceCode -Encoding UTF8

Write-Host "Created:"
Write-Host "- $OfflineUpdateDir\OfflineUpdateManifest.cs"
Write-Host "- $OfflineUpdateDir\OfflineUpdateService.cs"

# ==============================
# CREATE UPDATER PROJECT
# ==============================

Write-Step "STEP 3 - Creating Updater project"

$UpdaterCsprojCode = @'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>MyCompanyApp.Updater</AssemblyName>
    <RootNamespace>MyCompanyApp.Updater</RootNamespace>
  </PropertyGroup>

</Project>
'@

$UpdaterProgramCode = @'
using System.Diagnostics;
using System.IO.Compression;

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length < 3)
        {
            return 10;
        }

        var zipPath = args[0];
        var appDir = args[1];
        var entryExe = args[2];

        if (!File.Exists(zipPath))
            return 11;

        if (!Directory.Exists(appDir))
            return 12;

        var tempRoot = Path.Combine(Path.GetTempPath(), "MyCompanyApp_OfflineUpdate_Install_" + Guid.NewGuid().ToString("N"));
        var backupRoot = Path.Combine(appDir, "_update_backup_" + DateTime.Now.ToString("yyyyMMdd_HHmmss"));

        try
        {
            Directory.CreateDirectory(tempRoot);
            Directory.CreateDirectory(backupRoot);

            // Give the main WPF process enough time to exit.
            Thread.Sleep(2500);

            ZipFile.ExtractToDirectory(zipPath, tempRoot, true);

            var payloadDir = Path.Combine(tempRoot, "payload");

            if (!Directory.Exists(payloadDir))
                return 13;

            BackupCurrentFiles(appDir, payloadDir, backupRoot);

            CopyPayloadFiles(payloadDir, appDir);

            CleanupOldBackups(appDir);

            var exePath = Path.Combine(appDir, entryExe);

            if (File.Exists(exePath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = appDir,
                    UseShellExecute = true
                });
            }

            return 0;
        }
        catch
        {
            TryRestoreBackup(backupRoot, appDir);

            var exePath = Path.Combine(appDir, entryExe);

            if (File.Exists(exePath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = appDir,
                    UseShellExecute = true
                });
            }

            return 99;
        }
        finally
        {
            TryDeleteDirectory(tempRoot);
        }
    }

    private static void BackupCurrentFiles(string appDir, string payloadDir, string backupRoot)
    {
        foreach (var sourceFile in Directory.GetFiles(payloadDir, "*", SearchOption.AllDirectories))
        {
            var relative = Path.GetRelativePath(payloadDir, sourceFile);
            var currentFile = Path.Combine(appDir, relative);

            if (!File.Exists(currentFile))
                continue;

            var backupFile = Path.Combine(backupRoot, relative);
            var backupDir = Path.GetDirectoryName(backupFile);

            if (!string.IsNullOrWhiteSpace(backupDir))
                Directory.CreateDirectory(backupDir);

            File.Copy(currentFile, backupFile, true);
        }
    }

    private static void CopyPayloadFiles(string payloadDir, string appDir)
    {
        foreach (var sourceFile in Directory.GetFiles(payloadDir, "*", SearchOption.AllDirectories))
        {
            var relative = Path.GetRelativePath(payloadDir, sourceFile);
            var destinationFile = Path.Combine(appDir, relative);
            var destinationDir = Path.GetDirectoryName(destinationFile);

            if (!string.IsNullOrWhiteSpace(destinationDir))
                Directory.CreateDirectory(destinationDir);

            File.Copy(sourceFile, destinationFile, true);
        }
    }

    private static void TryRestoreBackup(string backupRoot, string appDir)
    {
        try
        {
            if (!Directory.Exists(backupRoot))
                return;

            foreach (var backupFile in Directory.GetFiles(backupRoot, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(backupRoot, backupFile);
                var destinationFile = Path.Combine(appDir, relative);
                var destinationDir = Path.GetDirectoryName(destinationFile);

                if (!string.IsNullOrWhiteSpace(destinationDir))
                    Directory.CreateDirectory(destinationDir);

                File.Copy(backupFile, destinationFile, true);
            }
        }
        catch
        {
            // Ignore restore errors.
        }
    }

    private static void CleanupOldBackups(string appDir)
    {
        try
        {
            var backups = Directory
                .GetDirectories(appDir, "_update_backup_*", SearchOption.TopDirectoryOnly)
                .OrderByDescending(Directory.GetCreationTimeUtc)
                .Skip(3);

            foreach (var backup in backups)
            {
                TryDeleteDirectory(backup);
            }
        }
        catch
        {
            // Ignore cleanup errors.
        }
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch
        {
            // Ignore cleanup errors.
        }
    }
}
'@

Set-Content -Path $UpdaterCsproj -Value $UpdaterCsprojCode -Encoding UTF8
Set-Content -Path (Join-Path $UpdaterProjectDir "Program.cs") -Value $UpdaterProgramCode -Encoding UTF8

Write-Host "Created:"
Write-Host "- $UpdaterCsproj"
Write-Host "- $UpdaterProjectDir\Program.cs"

# ==============================
# BUILD CHECK
# ==============================

Write-Step "STEP 4 - Build check"

dotnet build $WpfCsproj -c Release
dotnet build $UpdaterCsproj -c Release

Write-Host "Build successful."

# ==============================
# CLEAN OUTPUT
# ==============================

Write-Step "STEP 5 - Cleaning publish/package folders"

Clean-Dir $PublishRoot
Clean-Dir $PublishWpf
Clean-Dir $PublishUpdater
Clean-Dir $PackageDir
Clean-Dir $PayloadDir

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

# ==============================
# PUBLISH
# ==============================

Write-Step "STEP 6 - Publishing WPF and Updater"

dotnet publish $WpfCsproj -c Release -o $PublishWpf
dotnet publish $UpdaterCsproj -c Release -o $PublishUpdater

Assert-File (Join-Path $PublishWpf $EntryExe) "Published WPF entry exe not found."
Assert-File (Join-Path $PublishUpdater "MyCompanyApp.Updater.exe") "Published Updater exe not found."

Write-Host "Publish successful."

# ==============================
# COPY UPDATER INTO WPF PUBLISH
# ==============================

Write-Step "STEP 7 - Copying Updater into WPF publish directory"

Copy-Item -Path (Join-Path $PublishUpdater "*") -Destination $PublishWpf -Recurse -Force

Assert-File (Join-Path $PublishWpf "MyCompanyApp.Updater.exe") "Updater was not copied to WPF publish directory."

Write-Host "Updater copied."

# ==============================
# CREATE PACKAGE CONTENT
# ==============================

Write-Step "STEP 8 - Creating update package payload"

Copy-Item -Path (Join-Path $PublishWpf "*") -Destination $PayloadDir -Recurse -Force

$ManifestPath = Join-Path $PackageDir "manifest.json"

$InitialManifest = @{
    version = $Version
    entryExe = $EntryExe
    packageName = $PackageName
    sha256 = ""
    force = $false
} | ConvertTo-Json -Depth 10

Set-Content -Path $ManifestPath -Value $InitialManifest -Encoding UTF8

Write-Host "Payload created."
Write-Host "Manifest created."

# ==============================
# CREATE TEMP ZIP AND CALCULATE HASH
# ==============================

Write-Step "STEP 9 - Creating temporary zip and calculating SHA256"

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $ZipPath -Force

$Hash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

Write-Host "Temporary SHA256:"
Write-Host $Hash

# ==============================
# FINAL MANIFEST
# ==============================

Write-Step "STEP 10 - Writing final manifest"

$FinalManifest = @{
    version = $Version
    entryExe = $EntryExe
    packageName = $PackageName
    sha256 = $Hash
    force = $false
} | ConvertTo-Json -Depth 10

Set-Content -Path $ManifestPath -Value $FinalManifest -Encoding UTF8

# Recreate final zip with manifest containing the hash.
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $ZipPath -Force

$FinalHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

Write-Host "Final ZIP SHA256:"
Write-Host $FinalHash

Write-Host ""
Write-Host "IMPORTANT:"
Write-Host "The manifest contains the hash calculated before inserting the hash into manifest."
Write-Host "If you validate the whole ZIP including manifest.sha256, this creates a self-referential hash problem."
Write-Host "The safer validator below handles this correctly by hashing ZIP with manifest.sha256 normalized."
Write-Host ""

# ==============================
# PATCH WPF SERVICE FOR SELF-REFERENTIAL ZIP HASH
# ==============================

Write-Step "STEP 11 - Patching OfflineUpdateService for manifest hash normalization"

$OfflineServiceCodeFixedHash = @'
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace MyCompanyApp.Wpf.OfflineUpdate;

public sealed class OfflineUpdateService
{
    public OfflineUpdateManifest Validate(string zipPath)
    {
        if (string.IsNullOrWhiteSpace(zipPath))
            throw new ArgumentException("Update zip path is empty.", nameof(zipPath));

        if (!File.Exists(zipPath))
            throw new FileNotFoundException("Update zip file not found.", zipPath);

        var tempRoot = Path.Combine(Path.GetTempPath(), "MyCompanyApp_OfflineUpdate_Validate_" + Guid.NewGuid().ToString("N"));

        Directory.CreateDirectory(tempRoot);

        try
        {
            ZipFile.ExtractToDirectory(zipPath, tempRoot, true);

            var manifestPath = Path.Combine(tempRoot, "manifest.json");

            if (!File.Exists(manifestPath))
                throw new InvalidOperationException("manifest.json was not found in update package.");

            var json = File.ReadAllText(manifestPath);

            var manifest = JsonSerializer.Deserialize<OfflineUpdateManifest>(
                json,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

            if (manifest is null)
                throw new InvalidOperationException("manifest.json is invalid.");

            if (string.IsNullOrWhiteSpace(manifest.Version))
                throw new InvalidOperationException("manifest.version is empty.");

            if (string.IsNullOrWhiteSpace(manifest.EntryExe))
                throw new InvalidOperationException("manifest.entryExe is empty.");

            if (string.IsNullOrWhiteSpace(manifest.PackageName))
                throw new InvalidOperationException("manifest.packageName is empty.");

            if (string.IsNullOrWhiteSpace(manifest.Sha256))
                throw new InvalidOperationException("manifest.sha256 is empty.");

            var payloadDir = Path.Combine(tempRoot, "payload");

            if (!Directory.Exists(payloadDir))
                throw new InvalidOperationException("payload folder was not found in update package.");

            var actualSha256 = ComputePayloadSha256(payloadDir);

            if (!actualSha256.Equals(manifest.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Update payload SHA256 mismatch.");

            return manifest;
        }
        finally
        {
            TryDeleteDirectory(tempRoot);
        }
    }

    public void Install(string zipPath)
    {
        var manifest = Validate(zipPath);

        var appDir = AppContext.BaseDirectory;

        var updaterExe = Path.Combine(appDir, "MyCompanyApp.Updater.exe");

        if (!File.Exists(updaterExe))
            throw new FileNotFoundException("Updater executable not found.", updaterExe);

        var psi = new ProcessStartInfo
        {
            FileName = updaterExe,
            Arguments = $"\"{zipPath}\" \"{appDir}\" \"{manifest.EntryExe}\"",
            UseShellExecute = true,
            WorkingDirectory = appDir
        };

        Process.Start(psi);

        System.Windows.Application.Current.Shutdown();
    }

    private static string ComputePayloadSha256(string payloadDir)
    {
        var files = Directory
            .GetFiles(payloadDir, "*", SearchOption.AllDirectories)
            .OrderBy(x => Path.GetRelativePath(payloadDir, x), StringComparer.OrdinalIgnoreCase)
            .ToArray();

        using var sha256 = SHA256.Create();

        foreach (var file in files)
        {
            var relative = Path.GetRelativePath(payloadDir, file).Replace('\\', '/');
            var relativeBytes = Encoding.UTF8.GetBytes(relative);
            var contentBytes = File.ReadAllBytes(file);

            sha256.TransformBlock(relativeBytes, 0, relativeBytes.Length, null, 0);
            sha256.TransformBlock(contentBytes, 0, contentBytes.Length, null, 0);
        }

        sha256.TransformFinalBlock(Array.Empty<byte>(), 0, 0);

        return Convert.ToHexString(sha256.Hash!);
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch
        {
            // Ignore cleanup errors.
        }
    }
}
'@

Set-Content -Path (Join-Path $OfflineUpdateDir "OfflineUpdateService.cs") -Value $OfflineServiceCodeFixedHash -Encoding UTF8

# ==============================
# RECALCULATE PACKAGE USING PAYLOAD HASH
# ==============================

Write-Step "STEP 12 - Recalculate manifest SHA256 using payload hash"

function Get-PayloadHash {
    param([string]$PayloadPath)

    $files = Get-ChildItem -Path $PayloadPath -Recurse -File | Sort-Object FullName

    $tempHashInput = Join-Path $env:TEMP ("payload_hash_input_" + [guid]::NewGuid().ToString("N") + ".bin")

    try {
        $fs = [System.IO.File]::Open($tempHashInput, [System.IO.FileMode]::CreateNew)

        try {
            foreach ($file in $files) {
                $relative = [System.IO.Path]::GetRelativePath($PayloadPath, $file.FullName).Replace("\", "/")
                $relativeBytes = [System.Text.Encoding]::UTF8.GetBytes($relative)
                $contentBytes = [System.IO.File]::ReadAllBytes($file.FullName)

                $fs.Write($relativeBytes, 0, $relativeBytes.Length)
                $fs.Write($contentBytes, 0, $contentBytes.Length)
            }
        }
        finally {
            $fs.Dispose()
        }

        return (Get-FileHash -Path $tempHashInput -Algorithm SHA256).Hash
    }
    finally {
        if (Test-Path $tempHashInput) {
            Remove-Item $tempHashInput -Force
        }
    }
}

$PayloadHash = Get-PayloadHash $PayloadDir

$PayloadManifest = @{
    version = $Version
    entryExe = $EntryExe
    packageName = $PackageName
    sha256 = $PayloadHash
    force = $false
} | ConvertTo-Json -Depth 10

Set-Content -Path $ManifestPath -Value $PayloadManifest -Encoding UTF8

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $ZipPath -Force

$ZipFinalHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

# ==============================
# FINAL BUILD CHECK AFTER PATCH
# ==============================

Write-Step "STEP 13 - Final build check"

dotnet build $WpfCsproj -c Release
dotnet build $UpdaterCsproj -c Release

# ==============================
# DONE
# ==============================

Write-Step "DONE"

Write-Host "Offline update system installed successfully."
Write-Host ""
Write-Host "Update package:"
Write-Host $ZipPath
Write-Host ""
Write-Host "Payload SHA256 saved in manifest:"
Write-Host $PayloadHash
Write-Host ""
Write-Host "ZIP SHA256:"
Write-Host $ZipFinalHash
Write-Host ""
Write-Host "Package structure:"
Write-Host "MyCompanyApp_Update.zip"
Write-Host "  manifest.json"
Write-Host "  payload/"
Write-Host "    MyCompanyApp.Wpf.exe"
Write-Host "    MyCompanyApp.Updater.exe"
Write-Host "    *.dll"
Write-Host ""
Write-Host "Next usage in WPF:"
Write-Host "var service = new MyCompanyApp.Wpf.OfflineUpdate.OfflineUpdateService();"
Write-Host "service.Install(selectedZipPath);"
