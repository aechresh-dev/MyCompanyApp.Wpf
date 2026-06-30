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
            throw new FileNotFoundException("Update zip not found.", zipPath);

        var temp = Path.Combine(Path.GetTempPath(), "offline_update_validate_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);

        try
        {
            ZipFile.ExtractToDirectory(zipPath, temp, true);

            var manifestPath = Path.Combine(temp, "manifest.json");
            if (!File.Exists(manifestPath))
                throw new InvalidDataException("manifest.json not found in update package.");

            var payloadDir = Path.Combine(temp, "payload");
            if (!Directory.Exists(payloadDir))
                throw new InvalidDataException("payload directory not found in update package.");

            var json = File.ReadAllText(manifestPath);

            var manifest = JsonSerializer.Deserialize<OfflineUpdateManifest>(
                json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }
            ) ?? throw new InvalidDataException("Invalid manifest.json.");

            if (string.IsNullOrWhiteSpace(manifest.EntryExe))
                throw new InvalidDataException("Manifest entryExe is empty.");

            if (string.IsNullOrWhiteSpace(manifest.Sha256))
                throw new InvalidDataException("Manifest sha256 is empty.");

            var actualHash = ComputePayloadHash(payloadDir);

            if (!actualHash.Equals(manifest.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"SHA256 mismatch. Expected={manifest.Sha256}, Actual={actualHash}");

            return manifest;
        }
        finally
        {
            try
            {
                if (Directory.Exists(temp))
                    Directory.Delete(temp, true);
            }
            catch
            {
                // ignore cleanup errors
            }
        }
    }

    public void Install(string zipPath)
    {
        var manifest = Validate(zipPath);

        var appDir = AppContext.BaseDirectory;
        var updater = Path.Combine(appDir, "MyCompanyApp.Updater.exe");

        if (!File.Exists(updater))
            throw new FileNotFoundException("Updater executable not found beside application.", updater);

        Process.Start(new ProcessStartInfo
        {
            FileName = updater,
            Arguments = $"\"{zipPath}\" \"{appDir}\" \"{manifest.EntryExe}\"",
            WorkingDirectory = appDir,
            UseShellExecute = true
        });

        System.Windows.Application.Current.Shutdown();
    }

    private static string ComputePayloadHash(string payloadDir)
    {
        var files = Directory
            .GetFiles(payloadDir, "*", SearchOption.AllDirectories)
            .OrderBy(x => Path.GetRelativePath(payloadDir, x).Replace('\\', '/'), StringComparer.OrdinalIgnoreCase)
            .ToList();

        using var sha = SHA256.Create();

        foreach (var file in files)
        {
            var relative = Path.GetRelativePath(payloadDir, file).Replace('\\', '/');

            var nameBytes = Encoding.UTF8.GetBytes(relative);
            var contentBytes = File.ReadAllBytes(file);

            sha.TransformBlock(nameBytes, 0, nameBytes.Length, null, 0);
            sha.TransformBlock(new byte[] { 0 }, 0, 1, null, 0);
            sha.TransformBlock(contentBytes, 0, contentBytes.Length, null, 0);
            sha.TransformBlock(new byte[] { 0 }, 0, 1, null, 0);
        }

        sha.TransformFinalBlock(Array.Empty<byte>(), 0, 0);

        return Convert.ToHexString(sha.Hash!);
    }
}
