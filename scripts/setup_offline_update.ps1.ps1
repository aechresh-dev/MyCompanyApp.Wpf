$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# =========================================================
# CONFIG
# =========================================================
$Root = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"

$WpfProjectDir = Join-Path $Root "src\MyCompanyApp.Wpf"
$UpdaterProjectDir = Join-Path $Root "MyCompanyApp.Updater"
$DevPackageDir = Join-Path $Root "DevOfflinePackages\SamplePackage"

# =========================================================
# HELPERS
# =========================================================
function Ensure-Dir {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    Ensure-Dir (Split-Path $Path -Parent)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "Written: $Path" -ForegroundColor DarkGray
}

function Backup-FileIfExists {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path $Path) {
        $backup = "$Path.bak"
        Copy-Item $Path $backup -Force
        return $backup
    }

    return $null
}

function Replace-Or-CreateFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    Backup-FileIfExists -Path $Path | Out-Null
    Write-Utf8NoBom -Path $Path -Content $Content
}

function Get-ProjectFile {
    param(
        [Parameter(Mandatory)][string]$SearchRoot,
        [Parameter(Mandatory)][string]$ProjectName
    )

    $found = Get-ChildItem -Path $SearchRoot -Recurse -Filter $ProjectName -File -ErrorAction SilentlyContinue | Select-Object -First 1
    return $found?.FullName
}

# =========================================================
# PREPARE DIRECTORIES
# =========================================================
Ensure-Dir $WpfProjectDir
Ensure-Dir $UpdaterProjectDir
Ensure-Dir $DevPackageDir

$WpfModelsDir    = Join-Path $WpfProjectDir "UpdateSystem\Models"
$WpfServicesDir  = Join-Path $WpfProjectDir "UpdateSystem\Services"
$WpfViewModelsDir = Join-Path $WpfProjectDir "UpdateSystem\ViewModels"
$WpfViewsDir     = Join-Path $WpfProjectDir "Views"

Ensure-Dir $WpfModelsDir
Ensure-Dir $WpfServicesDir
Ensure-Dir $WpfViewModelsDir
Ensure-Dir $WpfViewsDir

$UpdaterModelsDir = Join-Path $UpdaterProjectDir "Models"
$UpdaterServicesDir = Join-Path $UpdaterProjectDir "Services"

Ensure-Dir $UpdaterModelsDir
Ensure-Dir $UpdaterServicesDir

# =========================================================
# WPF: MODELS
# =========================================================
Replace-Or-CreateFile -Path (Join-Path $WpfModelsDir "OfflineUpdateManifest.cs") -Content @'
namespace MyCompanyApp.Wpf.UpdateSystem.Models;

public sealed class OfflineUpdateManifest
{
    public string Version { get; set; } = "1.0.0";
    public string PackageName { get; set; } = "offline-update.zip";
    public string Sha256 { get; set; } = string.Empty;
    public string Changelog { get; set; } = string.Empty;
    public bool Force { get; set; }
    public string EntryExe { get; set; } = "MyCompanyApp.Wpf.exe";
}
'@

Replace-Or-CreateFile -Path (Join-Path $WpfModelsDir "UpdatePackageValidationResult.cs") -Content @'
namespace MyCompanyApp.Wpf.UpdateSystem.Models;

public sealed class UpdatePackageValidationResult
{
    public bool IsValid { get; set; }
    public string Message { get; set; } = string.Empty;
    public string ExtractedDirectory { get; set; } = string.Empty;
    public string ManifestPath { get; set; } = string.Empty;
    public string PackagePath { get; set; } = string.Empty;
    public OfflineUpdateManifest? Manifest { get; set; }
}
'@

Replace-Or-CreateFile -Path (Join-Path $WpfModelsDir "ProgressReportModel.cs") -Content @'
namespace MyCompanyApp.Wpf.UpdateSystem.Models;

public sealed class ProgressReportModel
{
    public int Percent { get; set; }
    public string Message { get; set; } = string.Empty;
}
'@

# =========================================================
# WPF: SERVICE
# =========================================================
Replace-Or-CreateFile -Path (Join-Path $WpfServicesDir "OfflineUpdateService.cs") -Content @'
using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using MyCompanyApp.Wpf.UpdateSystem.Models;

namespace MyCompanyApp.Wpf.UpdateSystem.Services;

public sealed class OfflineUpdateService
{
    public string GetCurrentVersion()
    {
        return Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "1.0.0.0";
    }

    public async Task<UpdatePackageValidationResult> ValidatePackageAsync(
        string packagePath,
        IProgress<ProgressReportModel>? progress = null,
        CancellationToken cancellationToken = default)
    {
        progress?.Report(new ProgressReportModel { Percent = 5, Message = "شروع بررسی فایل آپدیت..." });

        if (string.IsNullOrWhiteSpace(packagePath) || !File.Exists(packagePath))
        {
            return new UpdatePackageValidationResult
            {
                IsValid = false,
                Message = "فایل آپدیت پیدا نشد."
            };
        }

        var tempRoot = Path.Combine(Path.GetTempPath(), "MyCompanyApp_OfflineUpdate");
        var extractDir = Path.Combine(tempRoot, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(extractDir);

        progress?.Report(new ProgressReportModel { Percent = 15, Message = "استخراج فایل آپدیت..." });

        await Task.Run(() => ZipFile.ExtractToDirectory(packagePath, extractDir, true), cancellationToken);

        var manifestPath = Path.Combine(extractDir, "manifest.json");
        if (!File.Exists(manifestPath))
        {
            return new UpdatePackageValidationResult
            {
                IsValid = false,
                Message = "فایل manifest.json داخل پکیج وجود ندارد.",
                ExtractedDirectory = extractDir,
                PackagePath = packagePath
            };
        }

        progress?.Report(new ProgressReportModel { Percent = 35, Message = "خواندن اطلاعات نسخه..." });

        var manifestJson = await File.ReadAllTextAsync(manifestPath, cancellationToken);
        var manifest = JsonSerializer.Deserialize<OfflineUpdateManifest>(
            manifestJson,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (manifest is null)
        {
            return new UpdatePackageValidationResult
            {
                IsValid = false,
                Message = "manifest.json نامعتبر است.",
                ExtractedDirectory = extractDir,
                ManifestPath = manifestPath,
                PackagePath = packagePath
            };
        }

        var filesDir = Path.Combine(extractDir, "files");
        if (!Directory.Exists(filesDir))
        {
            return new UpdatePackageValidationResult
            {
                IsValid = false,
                Message = "پوشه files داخل پکیج پیدا نشد.",
                ExtractedDirectory = extractDir,
                ManifestPath = manifestPath,
                PackagePath = packagePath,
                Manifest = manifest
            };
        }

        progress?.Report(new ProgressReportModel { Percent = 55, Message = "بررسی نسخه..." });

        var currentVersion = ParseVersionSafe(GetCurrentVersion());
        var updateVersion = ParseVersionSafe(manifest.Version);

        if (updateVersion <= currentVersion)
        {
            return new UpdatePackageValidationResult
            {
                IsValid = false,
                Message = $"نسخه فایل آپدیت ({manifest.Version}) جدیدتر از نسخه فعلی ({GetCurrentVersion()}) نیست.",
                ExtractedDirectory = extractDir,
                ManifestPath = manifestPath,
                PackagePath = packagePath,
                Manifest = manifest
            };
        }

        progress?.Report(new ProgressReportModel { Percent = 75, Message = "بررسی SHA256..." });

        if (!string.IsNullOrWhiteSpace(manifest.Sha256))
        {
            var actualHash = await ComputeSha256Async(packagePath, cancellationToken);
            if (!string.Equals(actualHash, manifest.Sha256, StringComparison.OrdinalIgnoreCase))
            {
                return new UpdatePackageValidationResult
                {
                    IsValid = false,
                    Message = "هش فایل آپدیت معتبر نیست.",
                    ExtractedDirectory = extractDir,
                    ManifestPath = manifestPath,
                    PackagePath = packagePath,
                    Manifest = manifest
                };
            }
        }

        progress?.Report(new ProgressReportModel { Percent = 100, Message = "فایل آپدیت معتبر است." });

        return new UpdatePackageValidationResult
        {
            IsValid = true,
            Message = "فایل آپدیت با موفقیت بررسی شد.",
            ExtractedDirectory = extractDir,
            ManifestPath = manifestPath,
            PackagePath = packagePath,
            Manifest = manifest
        };
    }

    public void LaunchUpdater(UpdatePackageValidationResult validationResult)
    {
        if (!validationResult.IsValid || validationResult.Manifest is null)
            throw new InvalidOperationException("پکیج آپدیت هنوز معتبر نشده است.");

        var baseDir = AppContext.BaseDirectory;
        var updaterExe = Path.Combine(baseDir, "MyCompanyApp.Updater.exe");

        if (!File.Exists(updaterExe))
            throw new FileNotFoundException("Updater پیدا نشد.", updaterExe);

        var filesDir = Path.Combine(validationResult.ExtractedDirectory, "files");
        var backupDir = Path.Combine(Path.GetTempPath(), "MyCompanyApp_Backups", DateTime.Now.ToString("yyyyMMdd_HHmmss"));

        Directory.CreateDirectory(backupDir);

        var args = string.Join(" ", new[]
        {
            Quote(filesDir),
            Quote(baseDir),
            Quote(backupDir),
            Quote(validationResult.Manifest.EntryExe)
        });

        Process.Start(new ProcessStartInfo
        {
            FileName = updaterExe,
            Arguments = args,
            UseShellExecute = true
        });
    }

    private static string Quote(string value) => $"\"{value}\"";

    private static Version ParseVersionSafe(string? input)
    {
        if (Version.TryParse(input, out var version))
            return version;

        return new Version(0, 0, 0, 0);
    }

    private static async Task<string> ComputeSha256Async(string filePath, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(filePath);
        using var sha = SHA256.Create();
        var hash = await sha.ComputeHashAsync(stream, cancellationToken);
        return Convert.ToHexString(hash);
    }
}
'@

# =========================================================
# WPF: VIEWMODEL
# =========================================================
Replace-Or-CreateFile -Path (Join-Path $WpfViewModelsDir "OfflineUpdateViewModel.cs") -Content @'
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using Microsoft.Win32;
using MyCompanyApp.Wpf.UpdateSystem.Models;
using MyCompanyApp.Wpf.UpdateSystem.Services;

namespace MyCompanyApp.Wpf.UpdateSystem.ViewModels;

public sealed class OfflineUpdateViewModel : INotifyPropertyChanged
{
    private readonly OfflineUpdateService _service = new();
    private string _selectedFilePath = string.Empty;
    private string _statusMessage = "فایل آپدیت انتخاب نشده است.";
    private string _currentVersion = string.Empty;
    private string _targetVersion = "-";
    private string _changelog = "-";
    private int _progressValue;
    private bool _isBusy;
    private UpdatePackageValidationResult? _validationResult;

    public event PropertyChangedEventHandler? PropertyChanged;

    public string SelectedFilePath
    {
        get => _selectedFilePath;
        set => SetField(ref _selectedFilePath, value);
    }

    public string StatusMessage
    {
        get => _statusMessage;
        set => SetField(ref _statusMessage, value);
    }

    public string CurrentVersion
    {
        get => _currentVersion;
        set => SetField(ref _currentVersion, value);
    }

    public string TargetVersion
    {
        get => _targetVersion;
        set => SetField(ref _targetVersion, value);
    }

    public string Changelog
    {
        get => _changelog;
        set => SetField(ref _changelog, value);
    }

    public int ProgressValue
    {
        get => _progressValue;
        set => SetField(ref _progressValue, value);
    }

    public bool IsBusy
    {
        get => _isBusy;
        set => SetField(ref _isBusy, value);
    }

    public OfflineUpdateViewModel()
    {
        CurrentVersion = _service.GetCurrentVersion();
    }

    public void BrowseFile()
    {
        var dialog = new OpenFileDialog
        {
            Title = "انتخاب فایل آپدیت",
            Filter = "Update Package (*.zip)|*.zip|All Files (*.*)|*.*",
            CheckFileExists = true,
            Multiselect = false
        };

        if (dialog.ShowDialog() == true)
        {
            SelectedFilePath = dialog.FileName;
            StatusMessage = "فایل انتخاب شد. حالا اعتبارسنجی کنید.";
            ProgressValue = 0;
        }
    }

    public async Task ValidateAsync()
    {
        try
        {
            IsBusy = true;
            ProgressValue = 0;
            StatusMessage = "در حال بررسی پکیج...";

            var progress = new Progress<ProgressReportModel>(report =>
            {
                ProgressValue = report.Percent;
                StatusMessage = report.Message;
            });

            _validationResult = await _service.ValidatePackageAsync(SelectedFilePath, progress);

            if (_validationResult.Manifest is not null)
            {
                TargetVersion = _validationResult.Manifest.Version;
                Changelog = _validationResult.Manifest.Changelog;
            }
            else
            {
                TargetVersion = "-";
                Changelog = "-";
            }

            if (_validationResult.IsValid)
            {
                StatusMessage = "پکیج معتبر است و آماده نصب می‌باشد.";
            }
            else
            {
                MessageBox.Show(_validationResult.Message, "خطا در اعتبارسنجی", MessageBoxButton.OK, MessageBoxImage.Warning);
                StatusMessage = _validationResult.Message;
            }
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
            MessageBox.Show(ex.Message, "خطا", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            IsBusy = false;
        }
    }

    public void Install()
    {
        try
        {
            if (_validationResult is null || !_validationResult.IsValid)
            {
                MessageBox.Show("ابتدا فایل آپدیت را اعتبارسنجی کنید.", "اطلاع", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var result = MessageBox.Show(
                "برای نصب آپدیت، برنامه بسته و بعد از اتمام دوباره اجرا می‌شود. ادامه می‌دهید؟",
                "تأیید نصب آپدیت",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (result != MessageBoxResult.Yes)
                return;

            _service.LaunchUpdater(_validationResult);
            Application.Current.Shutdown();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "خطا در شروع آپدیت", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string propertyName = "")
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return;

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
'@

# =========================================================
# WPF: WINDOW
# =========================================================
Replace-Or-CreateFile -Path (Join-Path $WpfViewsDir "OfflineUpdateWindow.xaml") -Content @'
<Window x:Class="MyCompanyApp.Wpf.Views.OfflineUpdateWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="بروزرسانی آفلاین"
        Height="520"
        Width="760"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        FlowDirection="RightToLeft">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Padding="12" CornerRadius="10" Background="#F5F7FB" BorderBrush="#D7DFEA" BorderThickness="1">
            <StackPanel>
                <TextBlock Text="نصب بروزرسانی آفلاین" FontSize="20" FontWeight="Bold"/>
                <TextBlock Margin="0,8,0,0"
                           Foreground="#444"
                           Text="فایل آپدیت را انتخاب کنید، بررسی کنید و سپس نصب را آغاز نمایید."/>
            </StackPanel>
        </Border>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="140"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="120"/>
            </Grid.ColumnDefinitions>

            <TextBlock Grid.Column="0" VerticalAlignment="Center" Text="فایل آپدیت:" FontWeight="SemiBold"/>
            <TextBox Grid.Column="2" Height="36" VerticalContentAlignment="Center" Text="{Binding SelectedFilePath, UpdateSourceTrigger=PropertyChanged}" IsReadOnly="True"/>
            <Button Grid.Column="4" Height="36" Content="انتخاب فایل" Click="Browse_Click"/>
        </Grid>

        <Border Grid.Row="4" Padding="12" CornerRadius="10" Background="#FFFFFF" BorderBrush="#D7DFEA" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="140"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="10"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="10"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="نسخه فعلی:" FontWeight="SemiBold"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Text="{Binding CurrentVersion}"/>

                <TextBlock Grid.Row="2" Grid.Column="0" Text="نسخه مقصد:" FontWeight="SemiBold"/>
                <TextBlock Grid.Row="2" Grid.Column="1" Text="{Binding TargetVersion}"/>

                <TextBlock Grid.Row="4" Grid.Column="0" Text="تغییرات:" FontWeight="SemiBold"/>
                <TextBox Grid.Row="4" Grid.Column="1"
                         Text="{Binding Changelog}"
                         IsReadOnly="True"
                         BorderThickness="0"
                         Background="Transparent"
                         TextWrapping="Wrap"
                         AcceptsReturn="True"/>
            </Grid>
        </Border>

        <Border Grid.Row="6" Padding="12" CornerRadius="10" Background="#FFFFFF" BorderBrush="#D7DFEA" BorderThickness="1">
            <StackPanel>
                <TextBlock Text="وضعیت عملیات" FontWeight="SemiBold"/>
                <ProgressBar Margin="0,10,0,0" Height="22" Minimum="0" Maximum="100" Value="{Binding ProgressValue}"/>
                <TextBlock Margin="0,10,0,0" Text="{Binding StatusMessage}" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <Border Grid.Row="8" Padding="12" CornerRadius="10" Background="#FBFCFE" BorderBrush="#D7DFEA" BorderThickness="1">
            <TextBlock Foreground="#555" TextWrapping="Wrap">
                نکته: فایل آپدیت باید ZIP باشد و در ریشه آن فایل manifest.json و پوشه files وجود داشته باشد.
            </TextBlock>
        </Border>

        <StackPanel Grid.Row="10" Orientation="Horizontal" HorizontalAlignment="Left">
            <Button Width="120" Height="38" Margin="0,0,10,0" Content="اعتبارسنجی" Click="Validate_Click"/>
            <Button Width="120" Height="38" Margin="0,0,10,0" Content="نصب آپدیت" Click="Install_Click"/>
            <Button Width="120" Height="38" Content="بستن" Click="Close_Click"/>
        </StackPanel>
    </Grid>
</Window>
'@

Replace-Or-CreateFile -Path (Join-Path $WpfViewsDir "OfflineUpdateWindow.xaml.cs") -Content @'
using System.Windows;
using MyCompanyApp.Wpf.UpdateSystem.ViewModels;

namespace MyCompanyApp.Wpf.Views;

public partial class OfflineUpdateWindow : Window
{
    private readonly OfflineUpdateViewModel _viewModel = new();

    public OfflineUpdateWindow()
    {
        InitializeComponent();
        DataContext = _viewModel;
    }

    private void Browse_Click(object sender, RoutedEventArgs e) => _viewModel.BrowseFile();

    private async void Validate_Click(object sender, RoutedEventArgs e) => await _viewModel.ValidateAsync();

    private void Install_Click(object sender, RoutedEventArgs e) => _viewModel.Install();

    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
'@

# =========================================================
# UPDATER: MODELS/SERVICES
# =========================================================
Replace-Or-CreateFile -Path (Join-Path $UpdaterModelsDir "InstallArguments.cs") -Content @'
namespace MyCompanyApp.Updater.Models;

public sealed class InstallArguments
{
    public string SourceDirectory { get; set; } = string.Empty;
    public string TargetDirectory { get; set; } = string.Empty;
    public string BackupDirectory { get; set; } = string.Empty;
    public string EntryExe { get; set; } = "MyCompanyApp.Wpf.exe";
}
'@

Replace-Or-CreateFile -Path (Join-Path $UpdaterServicesDir "PackageInstaller.cs") -Content @'
namespace MyCompanyApp.Updater.Services;

public sealed class PackageInstaller
{
    public void Execute(
        string sourceDirectory,
        string targetDirectory,
        string backupDirectory,
        IProgress<(int percent, string message)>? progress = null)
    {
        if (!Directory.Exists(sourceDirectory))
            throw new DirectoryNotFoundException($"Source not found: {sourceDirectory}");

        Directory.CreateDirectory(targetDirectory);
        Directory.CreateDirectory(backupDirectory);

        var files = Directory.GetFiles(sourceDirectory, "*", SearchOption.AllDirectories)
            .Where(x => !x.EndsWith("MyCompanyApp.Updater.exe", StringComparison.OrdinalIgnoreCase))
            .ToList();

        var total = Math.Max(files.Count, 1);
        var index = 0;

        progress?.Report((5, "آماده‌سازی برای نصب..."));

        foreach (var sourceFile in files)
        {
            index++;

            var relative = Path.GetRelativePath(sourceDirectory, sourceFile);
            var targetFile = Path.Combine(targetDirectory, relative);
            var backupFile = Path.Combine(backupDirectory, relative);

            Directory.CreateDirectory(Path.GetDirectoryName(targetFile)!);
            Directory.CreateDirectory(Path.GetDirectoryName(backupFile)!);

            if (File.Exists(targetFile))
            {
                File.Copy(targetFile, backupFile, true);
            }

            File.Copy(sourceFile, targetFile, true);

            var percent = 10 + (int)((index / (double)total) * 80);
            progress?.Report((percent, $"در حال کپی: {relative}"));
        }

        progress?.Report((95, "نصب فایل‌ها به پایان رسید."));
    }

    public void Rollback(string backupDirectory, string targetDirectory, IProgress<(int percent, string message)>? progress = null)
    {
        if (!Directory.Exists(backupDirectory))
            return;

        var files = Directory.GetFiles(backupDirectory, "*", SearchOption.AllDirectories).ToList();
        var total = Math.Max(files.Count, 1);
        var index = 0;

        foreach (var backupFile in files)
        {
            index++;

            var relative = Path.GetRelativePath(backupDirectory, backupFile);
            var targetFile = Path.Combine(targetDirectory, relative);

            Directory.CreateDirectory(Path.GetDirectoryName(targetFile)!);
            File.Copy(backupFile, targetFile, true);

            var percent = 10 + (int)((index / (double)total) * 80);
            progress?.Report((percent, $"بازگردانی: {relative}"));
        }

        progress?.Report((100, "بازگردانی انجام شد."));
    }
}
'@

# =========================================================
# UPDATER: UI
# =========================================================
Replace-Or-CreateFile -Path (Join-Path $UpdaterProjectDir "UpdateProgressWindow.xaml") -Content @'
<Window x:Class="MyCompanyApp.Updater.UpdateProgressWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="در حال نصب بروزرسانی"
        Height="220"
        Width="520"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        FlowDirection="RightToLeft">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0"
                   Text="در حال نصب بروزرسانی..."
                   FontSize="20"
                   FontWeight="Bold"/>

        <ProgressBar x:Name="ProgressBarInstall"
                     Grid.Row="2"
                     Height="24"
                     Minimum="0"
                     Maximum="100"/>

        <TextBlock x:Name="TextStatus"
                   Grid.Row="4"
                   TextWrapping="Wrap"
                   VerticalAlignment="Top"/>
    </Grid>
</Window>
'@

Replace-Or-CreateFile -Path (Join-Path $UpdaterProjectDir "UpdateProgressWindow.xaml.cs") -Content @'
using System.Diagnostics;
using System.Windows;
using MyCompanyApp.Updater.Services;

namespace MyCompanyApp.Updater;

public partial class UpdateProgressWindow : Window
{
    private readonly string _sourceDirectory;
    private readonly string _targetDirectory;
    private readonly string _backupDirectory;
    private readonly string _entryExe;

    public UpdateProgressWindow(string sourceDirectory, string targetDirectory, string backupDirectory, string entryExe)
    {
        InitializeComponent();
        _sourceDirectory = sourceDirectory;
        _targetDirectory = targetDirectory;
        _backupDirectory = backupDirectory;
        _entryExe = entryExe;

        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            TextStatus.Text = "در حال بستن کامل برنامه اصلی...";
            await Task.Delay(1000);

            var installer = new PackageInstaller();
            var progress = new Progress<(int percent, string message)>(p =>
            {
                ProgressBarInstall.Value = p.percent;
                TextStatus.Text = p.message;
            });

            await Task.Run(() => installer.Execute(_sourceDirectory, _targetDirectory, _backupDirectory, progress));

            ProgressBarInstall.Value = 100;
            TextStatus.Text = "بروزرسانی با موفقیت انجام شد. در حال اجرای مجدد برنامه...";

            var exePath = Path.Combine(_targetDirectory, _entryExe);
            if (File.Exists(exePath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = Path.GetDirectoryName(exePath)!,
                    UseShellExecute = true
                });
            }

            await Task.Delay(1200);
            Close();
            Application.Current.Shutdown();
        }
        catch (Exception ex)
        {
            TextStatus.Text = "خطا در بروزرسانی. در حال بازگردانی فایل‌ها...";

            try
            {
                var installer = new PackageInstaller();
                var rollbackProgress = new Progress<(int percent, string message)>(p =>
                {
