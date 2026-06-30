param(
    [string]$Root = (Get-Location).Path,

    [string]$Configuration = "Release",

    [string]$Framework = "net8.0-windows",

    [string]$Runtime = "win-x64",

    [switch]$SelfContained,

    [switch]$SkipRestore,

    [switch]$SkipBuild,

    [switch]$SkipPublish,

    [switch]$SkipFirewallRule
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
    throw $Message
}

function BackupFile([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backup = "$Path.bak.$timestamp"
        Copy-Item -LiteralPath $Path -Destination $backup -Force
        Ok "Backup created: $backup"
    }
}

function EnsureDirectory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Ok "Directory created: $Path"
    }
}

function WriteUtf8NoBom([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
    Ok "Written: $Path"
}

function FindSolution([string]$RootPath) {
    $solutions = @(
        Get-ChildItem -Path $RootPath -Filter *.sln -File -ErrorAction SilentlyContinue
    )

    if ($solutions.Length -eq 0) {
        Fail "No .sln file found in root: $RootPath"
    }

    if ($solutions.Length -gt 1) {
        Warn "Multiple solution files found. Using first: $($solutions[0].FullName)"
    }

    return $solutions[0].FullName
}

function GetProjectFiles([string]$RootPath) {
    $projects = @(
        Get-ChildItem -Path $RootPath -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\bin\\' -and
            $_.FullName -notmatch '\\obj\\' -and
            $_.FullName -notmatch '\\.vs\\'
        }
    )

    return $projects
}

function FindWpfProject([string]$RootPath) {
    $projects = GetProjectFiles -RootPath $RootPath

    foreach ($project in $projects) {
        try {
            [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
            $useWpfNode = $xml.SelectSingleNode("//UseWPF")
            if ($null -ne $useWpfNode -and $useWpfNode.InnerText.Trim().ToLowerInvariant() -eq "true") {
                return $project.FullName
            }
        }
        catch {
            Warn "Could not parse project: $($project.FullName)"
        }
    }

    $fallback = @($projects | Where-Object { $_.FullName -match '\\src\\.*\.Wpf\\' -or $_.BaseName -match '\.Wpf$' })

    if ($fallback.Length -gt 0) {
        Warn "WPF project detected by name/path fallback: $($fallback[0].FullName)"
        return $fallback[0].FullName
    }

    Fail "Could not detect WPF project. Make sure a .csproj has <UseWPF>true</UseWPF>."
}

function GetProjectDirectory([string]$ProjectPath) {
    return Split-Path -Parent $ProjectPath
}

function EnsureDirectoryPackages([string]$RootPath) {
    $file = Join-Path $RootPath "Directory.Packages.props"
    BackupFile $file

    $lines = New-Object System.Collections.Generic.List[string]

    $packages = [ordered]@{}

    # WPF / MVVM / Hosting
    $packages["CommunityToolkit.Mvvm"] = "8.4.0"
    $packages["Microsoft.Extensions.Hosting"] = "8.0.1"
    $packages["Microsoft.Extensions.Configuration"] = "8.0.0"
    $packages["Microsoft.Extensions.Configuration.Json"] = "8.0.1"
    $packages["Microsoft.Extensions.Configuration.Binder"] = "8.0.2"
    $packages["Microsoft.Extensions.DependencyInjection"] = "8.0.1"
    $packages["Microsoft.Extensions.DependencyInjection.Abstractions"] = "8.0.2"
    $packages["Microsoft.Extensions.Logging"] = "8.0.1"
    $packages["Microsoft.Extensions.Logging.Console"] = "8.0.1"
    $packages["Microsoft.Extensions.Logging.Debug"] = "8.0.1"
    $packages["Microsoft.Extensions.Options"] = "8.0.2"
    $packages["Microsoft.Extensions.Options.ConfigurationExtensions"] = "8.0.0"

    # EF Core
    $packages["Microsoft.EntityFrameworkCore"] = "8.0.11"
    $packages["Microsoft.EntityFrameworkCore.SqlServer"] = "8.0.11"
    $packages["Microsoft.EntityFrameworkCore.Sqlite"] = "8.0.11"
    $packages["Microsoft.EntityFrameworkCore.Tools"] = "8.0.11"
    $packages["Microsoft.EntityFrameworkCore.Design"] = "8.0.11"

    # Logging / Reporting
    $packages["Serilog"] = "4.2.0"
    $packages["Serilog.Extensions.Hosting"] = "8.0.0"
    $packages["Serilog.Extensions.Logging"] = "8.0.0"
    $packages["Serilog.Sinks.Console"] = "6.0.0"
    $packages["Serilog.Sinks.File"] = "6.0.0"
    $packages["ClosedXML"] = "0.104.2"
    $packages["DocumentFormat.OpenXml"] = "3.1.1"
    $packages["QuestPDF"] = "2024.12.0"

    # Testing
    $packages["Microsoft.NET.Test.Sdk"] = "17.12.0"
    $packages["xunit"] = "2.9.2"
    $packages["xunit.runner.visualstudio"] = "2.8.2"
    $packages["coverlet.collector"] = "6.0.2"
    $packages["Moq"] = "4.20.72"
    $packages["FluentAssertions"] = "7.0.0"

    $lines.Add('<Project>')
    $lines.Add('  <PropertyGroup>')
    $lines.Add('    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>')
    $lines.Add('    <CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>')
    $lines.Add('    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>')
    $lines.Add('  </PropertyGroup>')
    $lines.Add('')
    $lines.Add('  <ItemGroup>')

    foreach ($name in $packages.Keys) {
        $version = $packages[$name]
        $lines.Add("    <PackageVersion Include=""$name"" Version=""$version"" />")
    }

    $lines.Add('  </ItemGroup>')
    $lines.Add('</Project>')

    [System.IO.File]::WriteAllLines($file, $lines, [System.Text.UTF8Encoding]::new($false))
    Ok "Directory.Packages.props updated"
}

function EnsureDirectoryBuildProps([string]$RootPath) {
    $file = Join-Path $RootPath "Directory.Build.props"
    BackupFile $file

    $content = @"
<Project>
  <PropertyGroup>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <Deterministic>true</Deterministic>
    <RestoreUseStaticGraphEvaluation>true</RestoreUseStaticGraphEvaluation>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
"@

    WriteUtf8NoBom -Path $file -Content $content
}

function EnsureNuGetConfigBuildOnline([string]$RootPath) {
    $file = Join-Path $RootPath "NuGet.config"
    BackupFile $file

    $content = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>

  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
"@

    WriteUtf8NoBom -Path $file -Content $content
    Ok "NuGet.config configured for build-time online restore only"
}

function NormalizePackageReferences([string]$RootPath) {
    $projects = GetProjectFiles -RootPath $RootPath

    foreach ($project in $projects) {
        try {
            [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
        }
        catch {
            Warn "Invalid csproj XML skipped: $($project.FullName)"
            continue
        }

        $changed = $false
        $refs = @($xml.SelectNodes("//PackageReference"))

        foreach ($ref in $refs) {
            if ($null -ne $ref.Attributes["Version"]) {
                [void]$ref.RemoveAttribute("Version")
                $changed = $true
            }

            $versionNode = $ref.SelectSingleNode("Version")
            if ($null -ne $versionNode) {
                [void]$ref.RemoveChild($versionNode)
                $changed = $true
            }
        }

        if ($changed) {
            BackupFile $project.FullName
            $xml.Save($project.FullName)
            Ok "PackageReference versions removed from: $($project.FullName)"
        }
    }
}

function EnsurePackageReference([string]$ProjectPath, [string]$PackageName) {
    [xml]$xml = Get-Content -LiteralPath $ProjectPath -Raw

    $existing = $xml.SelectSingleNode("//PackageReference[@Include='$PackageName']")
    if ($null -ne $existing) {
        Ok "Package already exists in WPF project: $PackageName"
        return
    }

    $projectNode = $xml.Project
    $itemGroup = $xml.CreateElement("ItemGroup")
    $packageReference = $xml.CreateElement("PackageReference")
    $includeAttribute = $xml.CreateAttribute("Include")
    $includeAttribute.Value = $PackageName
    [void]$packageReference.Attributes.Append($includeAttribute)
    [void]$itemGroup.AppendChild($packageReference)
    [void]$projectNode.AppendChild($itemGroup)

    BackupFile $ProjectPath
    $xml.Save($ProjectPath)

    Ok "PackageReference added to WPF project: $PackageName"
}

function EnsureContentFileInProject([string]$ProjectPath, [string]$RelativePath, [string]$CopyMode) {
    [xml]$xml = Get-Content -LiteralPath $ProjectPath -Raw

    $escaped = $RelativePath.Replace('\', '\\')
    $existingNone = $xml.SelectSingleNode("//None[@Update='$RelativePath']")
    $existingContent = $xml.SelectSingleNode("//Content[@Include='$RelativePath']")

    if ($null -ne $existingNone -or $null -ne $existingContent) {
        Ok "Project already contains content rule for: $RelativePath"
        return
    }

    $projectNode = $xml.Project
    $itemGroup = $xml.CreateElement("ItemGroup")

    $none = $xml.CreateElement("None")
    $updateAttr = $xml.CreateAttribute("Update")
    $updateAttr.Value = $RelativePath
    [void]$none.Attributes.Append($updateAttr)

    $copy = $xml.CreateElement("CopyToOutputDirectory")
    $copy.InnerText = $CopyMode
    [void]$none.AppendChild($copy)

    [void]$itemGroup.AppendChild($none)
    [void]$projectNode.AppendChild($itemGroup)

    BackupFile $ProjectPath
    $xml.Save($ProjectPath)

    Ok "Content file rule added to project: $RelativePath"
}

function EnsureRuntimeNetworkOptionsClass([string]$WpfProjectDir) {
    $dir = Join-Path $WpfProjectDir "Infrastructure\Runtime"
    EnsureDirectory $dir

    $file = Join-Path $dir "RuntimeNetworkOptions.cs"

    $content = @"
namespace MyCompanyApp.Wpf.Infrastructure.Runtime;

public sealed class RuntimeNetworkOptions
{
    public bool AllowInternet { get; set; } = false;

    public string[] AllowedHosts { get; set; } = [];

    public bool BlockUnknownHosts { get; set; } = true;
}
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
}

function EnsureRuntimeNetworkGuardClass([string]$WpfProjectDir) {
    $dir = Join-Path $WpfProjectDir "Infrastructure\Runtime"
    EnsureDirectory $dir

    $file = Join-Path $dir "RuntimeNetworkGuard.cs"

    $content = @"
using Microsoft.Extensions.Options;

namespace MyCompanyApp.Wpf.Infrastructure.Runtime;

public sealed class RuntimeNetworkGuard
{
    private readonly RuntimeNetworkOptions _options;

    public RuntimeNetworkGuard(IOptions<RuntimeNetworkOptions> options)
    {
        _options = options.Value;
    }

    public void EnsureInternetAllowed(Uri? uri = null)
    {
        if (_options.AllowInternet)
        {
            return;
        }

        if (uri is not null && IsHostAllowed(uri.Host))
        {
            return;
        }

        var target = uri?.ToString() ?? "unknown target";

        throw new InvalidOperationException(
            `$"Internet/network access is disabled for this application at runtime. Target: {target}");
    }

    public bool IsHostAllowed(string? host)
    {
        if (string.IsNullOrWhiteSpace(host))
        {
            return false;
        }

        if (_options.AllowedHosts is null || _options.AllowedHosts.Length == 0)
        {
            return false;
        }

        return _options.AllowedHosts.Any(
            x => string.Equals(x, host, StringComparison.OrdinalIgnoreCase));
    }
}
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
}

function EnsureRuntimeNetworkBlockingHandlerClass([string]$WpfProjectDir) {
    $dir = Join-Path $WpfProjectDir "Infrastructure\Runtime"
    EnsureDirectory $dir

    $file = Join-Path $dir "RuntimeNetworkBlockingHandler.cs"

    $content = @"
namespace MyCompanyApp.Wpf.Infrastructure.Runtime;

public sealed class RuntimeNetworkBlockingHandler : DelegatingHandler
{
    private readonly RuntimeNetworkGuard _guard;

    public RuntimeNetworkBlockingHandler(RuntimeNetworkGuard guard)
    {
        _guard = guard;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        _guard.EnsureInternetAllowed(request.RequestUri);

        return base.SendAsync(request, cancellationToken);
    }
}
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
}

function EnsureOfflineRuntimeServiceCollectionExtensions([string]$WpfProjectDir) {
    $dir = Join-Path $WpfProjectDir "Infrastructure\Runtime"
    EnsureDirectory $dir

    $file = Join-Path $dir "OfflineRuntimeServiceCollectionExtensions.cs"

    $content = @"
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Wpf.Infrastructure.Runtime;

public static class OfflineRuntimeServiceCollectionExtensions
{
    public static IServiceCollection AddOfflineRuntimeProtection(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<RuntimeNetworkOptions>(
            configuration.GetSection("RuntimeNetwork"));

        services.AddSingleton<RuntimeNetworkGuard>();
        services.AddTransient<RuntimeNetworkBlockingHandler>();

        services.AddHttpClient("BlockedByDefault")
            .AddHttpMessageHandler<RuntimeNetworkBlockingHandler>();

        return services;
    }
}
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
}

function EnsureAppSettings([string]$WpfProjectDir, [string]$ProjectPath) {
    $file = Join-Path $WpfProjectDir "appsettings.json"

    $content = @"
{
  "RuntimeNetwork": {
    "AllowInternet": false,
    "AllowedHosts": [],
    "BlockUnknownHosts": true
  },

  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "System": "Warning"
    }
  }
}
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
    EnsureContentFileInProject -ProjectPath $ProjectPath -RelativePath "appsettings.json" -CopyMode "PreserveNewest"
}

function EnsureAppXamlCsUsesHost([string]$WpfProjectDir) {
    $file = Join-Path $WpfProjectDir "App.xaml.cs"

    $content = @"
using System.Windows;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using MyCompanyApp.Wpf.Infrastructure.Runtime;

namespace MyCompanyApp.Wpf;

public partial class App : System.Windows.Application
{
    private IHost? _host;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _host = Host.CreateDefaultBuilder(e.Args)
            .ConfigureAppConfiguration((context, config) =>
            {
                config.SetBasePath(AppContext.BaseDirectory);
                config.AddJsonFile("appsettings.json", optional: false, reloadOnChange: false);
            })
            .ConfigureServices((context, services) =>
            {
                services.AddOfflineRuntimeProtection(context.Configuration);

                services.AddSingleton<MainWindow>();
            })
            .Build();

        await _host.StartAsync();

        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        mainWindow.Show();
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        if (_host is not null)
        {
            await _host.StopAsync(TimeSpan.FromSeconds(5));
            _host.Dispose();
        }

        base.OnExit(e);
    }
}
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
}

function EnsureAppXaml([string]$WpfProjectDir) {
    $file = Join-Path $WpfProjectDir "App.xaml"

    if (-not (Test-Path -LiteralPath $file)) {
        $content = @"
<Application x:Class="MyCompanyApp.Wpf.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Application.Resources>
    </Application.Resources>
</Application>
"@
        WriteUtf8NoBom -Path $file -Content $content
        return
    }

    $current = Get-Content -LiteralPath $file -Raw

    if ($current -match 'StartupUri\s*=') {
        BackupFile $file
        $updated = $current -replace '\s*StartupUri\s*=\s*"[^"]*"', ''
        WriteUtf8NoBom -Path $file -Content $updated
        Ok "StartupUri removed from App.xaml for Generic Host startup"
    }
    else {
        Ok "App.xaml does not contain StartupUri"
    }
}

function EnsureMainWindowIfMissing([string]$WpfProjectDir) {
    $xaml = Join-Path $WpfProjectDir "MainWindow.xaml"
    $codeBehind = Join-Path $WpfProjectDir "MainWindow.xaml.cs"

    if (-not (Test-Path -LiteralPath $xaml)) {
        $xamlContent = @"
<Window x:Class="MyCompanyApp.Wpf.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MyCompanyApp"
        Width="1100"
        Height="700"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <TextBlock Text="MyCompanyApp WPF"
                   HorizontalAlignment="Center"
                   VerticalAlignment="Center"
                   FontSize="32"
                   FontWeight="SemiBold" />
    </Grid>
</Window>
"@
        WriteUtf8NoBom -Path $xaml -Content $xamlContent
    }

    if (-not (Test-Path -LiteralPath $codeBehind)) {
        $csContent = @"
using System.Windows;

namespace MyCompanyApp.Wpf;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }
}
"@
        WriteUtf8NoBom -Path $codeBehind -Content $csContent
    }
}

function EnsurePublishProfile([string]$WpfProjectDir) {
    $dir = Join-Path $WpfProjectDir "Properties\PublishProfiles"
    EnsureDirectory $dir

    $file = Join-Path $dir "FolderProfile.pubxml"

    $content = @"
<Project>
  <PropertyGroup>
    <Configuration>Release</Configuration>
    <Platform>Any CPU</Platform>
    <PublishDir>bin\Release\net8.0-windows\win-x64\publish\</PublishDir>
    <PublishProtocol>FileSystem</PublishProtocol>
    <TargetFramework>net8.0-windows</TargetFramework>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>false</SelfContained>
    <PublishSingleFile>false</PublishSingleFile>
    <PublishReadyToRun>false</PublishReadyToRun>
    <PublishTrimmed>false</PublishTrimmed>
  </PropertyGroup>
</Project>
"@

    BackupFile $file
    WriteUtf8NoBom -Path $file -Content $content
}

function InvokeDotNetRestore([string]$SolutionPath, [string]$ConfigFile) {
    Log "Restoring solution using build-time online NuGet source..."
    & dotnet restore $SolutionPath --configfile $ConfigFile --force-evaluate

    if ($LASTEXITCODE -ne 0) {
        Fail "dotnet restore failed."
    }

    Ok "Restore succeeded"
}

function InvokeDotNetBuild([string]$SolutionPath, [string]$ConfigurationName) {
    Log "Building solution..."
    & dotnet build $SolutionPath -c $ConfigurationName --no-restore

    if ($LASTEXITCODE -ne 0) {
        Fail "dotnet build failed."
    }

    Ok "Build succeeded"
}

function InvokeDotNetPublish(
    [string]$ProjectPath,
    [string]$ConfigurationName,
    [string]$TargetFramework,
    [string]$RuntimeIdentifier,
    [bool]$IsSelfContained
) {
    Log "Publishing WPF project..."

    if ($IsSelfContained) {
        & dotnet publish $ProjectPath `
            -c $ConfigurationName `
            -f $TargetFramework `
            -r $RuntimeIdentifier `
            --self-contained true `
            /p:PublishSingleFile=false `
            /p:PublishReadyToRun=false `
            /p:PublishTrimmed=false `
            --no-restore
    }
    else {
        & dotnet publish $ProjectPath `
            -c $ConfigurationName `
            -f $TargetFramework `
            -r $RuntimeIdentifier `
            --self-contained false `
            /p:PublishSingleFile=false `
            /p:PublishReadyToRun=false `
            /p:PublishTrimmed=false `
            --no-restore
    }

    if ($LASTEXITCODE -ne 0) {
        Fail "dotnet publish failed."
    }

    Ok "Publish succeeded"
}

function GetPublishDirectory(
    [string]$WpfProjectDir,
    [string]$ConfigurationName,
    [string]$TargetFramework,
    [string]$RuntimeIdentifier
) {
    return Join-Path $WpfProjectDir "bin\$ConfigurationName\$TargetFramework\$RuntimeIdentifier\publish"
}

function GetPublishedExe([string]$PublishDir, [string]$WpfProjectPath) {
    if (-not (Test-Path -LiteralPath $PublishDir)) {
        return $null
    }

    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($WpfProjectPath)
    $expectedExe = Join-Path $PublishDir "$projectName.exe"

    if (Test-Path -LiteralPath $expectedExe) {
        return $expectedExe
    }

    $exeFiles = @(
        Get-ChildItem -Path $PublishDir -Filter *.exe -File -ErrorAction SilentlyContinue
    )

    if ($exeFiles.Length -gt 0) {
        return $exeFiles[0].FullName
    }

    return $null
}

function EnsureFirewallBlockRule([string]$ExePath) {
    if (-not (Test-Path -LiteralPath $ExePath)) {
        Warn "EXE not found. Firewall rule skipped: $ExePath"
        return
    }

    $ruleName = "MyCompanyApp Runtime Offline Block - $([System.IO.Path]::GetFileNameWithoutExtension($ExePath))"

    $existingRules = @(
        Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    )

    foreach ($rule in $existingRules) {
        Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
    }

    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Outbound `
        -Program $ExePath `
        -Action Block `
        -Profile Any `
        -Enabled True | Out-Null

    Ok "Outbound firewall block rule created for: $ExePath"
}

function WriteRuntimeOfflineReadme([string]$PublishDir, [string]$ExePath) {
    EnsureDirectory $PublishDir

    $file = Join-Path $PublishDir "RUNTIME-OFFLINE-NOTES.txt"

    $content = @"
Runtime Offline Notes
=====================

This application was built with the following policy:

1. Build-time restore/build/publish may use internet access.
2. Runtime internet access is disabled by configuration:
   appsettings.json -> RuntimeNetwork.AllowInternet = false
3. HttpClient created through the application's DI container is blocked by RuntimeNetworkBlockingHandler.
4. A Windows Firewall outbound block rule can be created for the published executable.

Published EXE:
$ExePath

Important:
Code-level blocking protects HttpClient usage registered through DI.
The strongest runtime protection is the Windows Firewall outbound block rule.
"@

    WriteUtf8NoBom -Path $file -Content $content
}

Log "Root: $Root"

$solution = FindSolution -RootPath $Root
Ok "Solution found: $solution"

$wpfProject = FindWpfProject -RootPath $Root
Ok "WPF project found: $wpfProject"

$wpfProjectDir = GetProjectDirectory -ProjectPath $wpfProject
Ok "WPF project directory: $wpfProjectDir"

EnsureDirectoryPackages -RootPath $Root
EnsureDirectoryBuildProps -RootPath $Root
EnsureNuGetConfigBuildOnline -RootPath $Root

EnsurePackageReference -ProjectPath $wpfProject -PackageName "Microsoft.Extensions.Hosting"
EnsurePackageReference -ProjectPath $wpfProject -PackageName "Microsoft.Extensions.Configuration.Json"
EnsurePackageReference -ProjectPath $wpfProject -PackageName "Microsoft.Extensions.Options.ConfigurationExtensions"
EnsurePackageReference -ProjectPath $wpfProject -PackageName "Microsoft.Extensions.DependencyInjection"

NormalizePackageReferences -RootPath $Root

EnsureRuntimeNetworkOptionsClass -WpfProjectDir $wpfProjectDir
EnsureRuntimeNetworkGuardClass -WpfProjectDir $wpfProjectDir
EnsureRuntimeNetworkBlockingHandlerClass -WpfProjectDir $wpfProjectDir
EnsureOfflineRuntimeServiceCollectionExtensions -WpfProjectDir $wpfProjectDir

EnsureAppSettings -WpfProjectDir $wpfProjectDir -ProjectPath $wpfProject
EnsureAppXaml -WpfProjectDir $wpfProjectDir
EnsureAppXamlCsUsesHost -WpfProjectDir $wpfProjectDir
EnsureMainWindowIfMissing -WpfProjectDir $wpfProjectDir
EnsurePublishProfile -WpfProjectDir $wpfProjectDir

$nugetConfig = Join-Path $Root "NuGet.config"

if (-not $SkipRestore) {
    InvokeDotNetRestore -SolutionPath $solution -ConfigFile $nugetConfig
}
else {
    Warn "Restore skipped"
}

if (-not $SkipBuild) {
    InvokeDotNetBuild -SolutionPath $solution -ConfigurationName $Configuration
}
else {
    Warn "Build skipped"
}

if (-not $SkipPublish) {
    InvokeDotNetPublish `
        -ProjectPath $wpfProject `
        -ConfigurationName $Configuration `
        -TargetFramework $Framework `
        -RuntimeIdentifier $Runtime `
        -IsSelfContained $SelfContained.IsPresent

    $publishDir = GetPublishDirectory `
        -WpfProjectDir $wpfProjectDir `
        -ConfigurationName $Configuration `
        -TargetFramework $Framework `
        -RuntimeIdentifier $Runtime

    $exe = GetPublishedExe -PublishDir $publishDir -WpfProjectPath $wpfProject

    if ($null -ne $exe) {
        Ok "Published EXE: $exe"

        WriteRuntimeOfflineReadme -PublishDir $publishDir -ExePath $exe

        if (-not $SkipFirewallRule) {
            try {
                EnsureFirewallBlockRule -ExePath $exe
            }
            catch {
                Warn "Could not create firewall rule. Run PowerShell as Administrator if needed."
                Warn $_.Exception.Message
            }
        }
        else {
            Warn "Firewall rule skipped"
        }
    }
    else {
        Warn "Published EXE not found in: $publishDir"
    }
}
else {
    Warn "Publish skipped"
}

Ok "Build-online / runtime-offline preparation completed successfully"
