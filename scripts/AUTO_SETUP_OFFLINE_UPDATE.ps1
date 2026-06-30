$ErrorActionPreference = "Stop"

$Root = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$Src = Join-Path $Root "src"

$WpfProjectDir = Join-Path $Src "MyCompanyApp.Wpf"
$UpdaterProjectDir = Join-Path $Src "MyCompanyApp.Updater"

$WpfCsproj = Join-Path $WpfProjectDir "MyCompanyApp.Wpf.csproj"
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

function Ensure($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Path $p | Out-Null } }
function Clean($p){ if(Test-Path $p){ Remove-Item -Recurse -Force $p }; New-Item -ItemType Directory -Path $p | Out-Null }

Write-Host "STEP 1 - Create OfflineUpdate folder"
Ensure $OfflineUpdateDir

# ================= CREATE MANIFEST CLASS =================

@"
using System.Text.Json.Serialization;
namespace MyCompanyApp.Wpf.OfflineUpdate;
public sealed class OfflineUpdateManifest
{
    [JsonPropertyName(""version"")] public string Version { get; set; } = string.Empty;
    [JsonPropertyName(""entryExe"")] public string EntryExe { get; set; } = string.Empty;
    [JsonPropertyName(""packageName"")] public string PackageName { get; set; } = string.Empty;
    [JsonPropertyName(""sha256"")] public string Sha256 { get; set; } = string.Empty;
    [JsonPropertyName(""force"")] public bool Force { get; set; }
}
"@ | Set-Content (Join-Path $OfflineUpdateDir "OfflineUpdateManifest.cs") -Encoding UTF8

# ================= CREATE SERVICE =================

@"
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
        if (!File.Exists(zipPath))
            throw new FileNotFoundException(""Zip not found"", zipPath);

        var temp = Path.Combine(Path.GetTempPath(), ""offline_update_"" + Guid.NewGuid().ToString(""N""));
        Directory.CreateDirectory(temp);

        try
        {
            ZipFile.ExtractToDirectory(zipPath, temp, true);

            var manifestPath = Path.Combine(temp, ""manifest.json"");
            var json = File.ReadAllText(manifestPath);

            var manifest = JsonSerializer.Deserialize<OfflineUpdateManifest>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                ?? throw new Exception(""Invalid manifest"");

            var payloadDir = Path.Combine(temp, ""payload"");
            var actualHash = ComputePayloadHash(payloadDir);

            if (!actualHash.Equals(manifest.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new Exception(""SHA256 mismatch"");

            return manifest;
        }
        finally
        {
            if (Directory.Exists(temp))
                Directory.Delete(temp, true);
        }
    }

    public void Install(string zipPath)
    {
        var manifest = Validate(zipPath);

        var appDir = AppContext.BaseDirectory;
        var updater = Path.Combine(appDir, ""MyCompanyApp.Updater.exe"");

        Process.Start(new ProcessStartInfo
        {
            FileName = updater,
            Arguments = $""\""{zipPath}\"" \""{appDir}\"" \""{manifest.EntryExe}\""",
            UseShellExecute = true
        });

        System.Windows.Application.Current.Shutdown();
    }

    private static string ComputePayloadHash(string payloadDir)
    {
        var files = Directory.GetFiles(payloadDir, ""*"", SearchOption.AllDirectories)
            .OrderBy(x => Path.GetRelativePath(payloadDir, x));

        using var sha = SHA256.Create();

        foreach (var file in files)
        {
            var relative = Path.GetRelativePath(payloadDir, file).Replace('\\','/');
            var nameBytes = Encoding.UTF8.GetBytes(relative);
            var contentBytes = File.ReadAllBytes(file);

            sha.TransformBlock(nameBytes,0,nameBytes.Length,null,0);
            sha.TransformBlock(contentBytes,0,contentBytes.Length,null,0);
        }

        sha.TransformFinalBlock(Array.Empty<byte>(),0,0);
        return Convert.ToHexString(sha.Hash!);
    }
}
"@ | Set-Content (Join-Path $OfflineUpdateDir "OfflineUpdateService.cs") -Encoding UTF8

# ================= CREATE UPDATER =================

Ensure $UpdaterProjectDir

@"
<Project Sdk=""Microsoft.NET.Sdk"">
<PropertyGroup>
<TargetFramework>net8.0-windows</TargetFramework>
<OutputType>WinExe</OutputType>
<ImplicitUsings>enable</ImplicitUsings>
<Nullable>enable</Nullable>
<AssemblyName>MyCompanyApp.Updater</AssemblyName>
</PropertyGroup>
</Project>
"@ | Set-Content $UpdaterCsproj -Encoding UTF8

@"
using System.Diagnostics;
using System.IO.Compression;

if(args.Length<3) return;

var zip=args[0];
var appDir=args[1];
var exe=args[2];

Thread.Sleep(2000);

var temp=Path.Combine(Path.GetTempPath(),""install_""+Guid.NewGuid().ToString(""N""));
Directory.CreateDirectory(temp);

ZipFile.ExtractToDirectory(zip,temp,true);

var payload=Path.Combine(temp,""payload"");

foreach(var file in Directory.GetFiles(payload,""*"",
SearchOption.AllDirectories))
{
    var rel=Path.GetRelativePath(payload,file);
    var dest=Path.Combine(appDir,rel);
    Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
    File.Copy(file,dest,true);
}

Process.Start(new ProcessStartInfo{
    FileName=Path.Combine(appDir,exe),
    UseShellExecute=true
});
"@ | Set-Content (Join-Path $UpdaterProjectDir "Program.cs") -Encoding UTF8

Write-Host "STEP 2 - Build"

dotnet build $WpfCsproj -c Release
dotnet build $UpdaterCsproj -c Release

Write-Host "STEP 3 - Publish"

Clean $PublishRoot
Clean $PublishWpf
Clean $PublishUpdater
Clean $PackageDir
Clean $PayloadDir

dotnet publish $WpfCsproj -c Release -o $PublishWpf
dotnet publish $UpdaterCsproj -c Release -o $PublishUpdater

Copy-Item "$PublishUpdater\*" $PublishWpf -Recurse -Force
Copy-Item "$PublishWpf\*" $PayloadDir -Recurse -Force

$PayloadHash = (Get-ChildItem $PayloadDir -Recurse -File | 
Sort-Object FullName | 
ForEach-Object { $_.FullName }) | 
Out-String | 
Get-FileHash -Algorithm SHA256

$manifest = @{
version=$Version
entryExe=$EntryExe
packageName="MyCompanyApp_Update.zip"
sha256=$PayloadHash.Hash
force=$false
} | ConvertTo-Json -Depth 5

Set-Content (Join-Path $PackageDir "manifest.json") $manifest -Encoding UTF8

if(Test-Path $ZipPath){Remove-Item $ZipPath -Force}
Compress-Archive "$PackageDir\*" $ZipPath -Force

Write-Host "DONE"
Write-Host $ZipPath
