param(
    [string]$ProjectPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
)

Write-Host "شروع تحلیل پروژه..." -ForegroundColor Cyan

if(!(Test-Path $ProjectPath)){
    Write-Host "پروژه پیدا نشد" -ForegroundColor Red
    exit
}

# حذف پوشه های build
Write-Host "پاکسازی bin و obj ..." -ForegroundColor Yellow
Get-ChildItem $ProjectPath -Recurse -Directory -Include bin,obj | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# پیدا کردن csproj
$csproj = Get-ChildItem $ProjectPath -Recurse -Filter *.csproj | Select-Object -First 1

if(!$csproj){
    Write-Host "فایل csproj پیدا نشد" -ForegroundColor Red
    exit
}

Write-Host "پروژه یافت شد:"
Write-Host $csproj.FullName

$content = Get-Content $csproj.FullName -Raw

# فعال سازی WPF
if($content -notmatch "<UseWPF>true</UseWPF>"){
    Write-Host "اضافه کردن UseWPF"
    $content = $content -replace "</PropertyGroup>","  <UseWPF>true</UseWPF>`n</PropertyGroup>"
}

# اصلاح OutputType
if($content -notmatch "<OutputType>WinExe</OutputType>"){
    Write-Host "اصلاح OutputType"
    $content = $content -replace "<OutputType>.*</OutputType>","<OutputType>WinExe</OutputType>"
}

Set-Content $csproj.FullName $content

# بررسی App.xaml
$appxaml = Get-ChildItem $ProjectPath -Recurse -Filter App.xaml | Select-Object -First 1

if(!$appxaml){
    Write-Host "App.xaml وجود ندارد - ایجاد می شود"

$appContent = @"
<Application x:Class="MyCompanyApp.App"
 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 StartupUri="MainWindow.xaml">
</Application>
"@

New-Item "$ProjectPath\App.xaml" -ItemType File -Value $appContent
}

# بررسی MainWindow
$main = Get-ChildItem $ProjectPath -Recurse -Filter MainWindow.xaml | Select-Object -First 1

if(!$main){
Write-Host "ساخت MainWindow"

$window = @"
<Window x:Class="MyCompanyApp.MainWindow"
 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="MyCompanyApp" Height="450" Width="800">
 <Grid>
 <TextBlock Text="Application Started"
 VerticalAlignment="Center"
 HorizontalAlignment="Center"
 FontSize="30"/>
 </Grid>
</Window>
"@

New-Item "$ProjectPath\MainWindow.xaml" -ItemType File -Value $window
}

# حذف فایل های temp
Write-Host "حذف فایل های موقت"

Get-ChildItem $ProjectPath -Recurse -Include *.tmp,*.cache,*.log -ErrorAction SilentlyContinue | Remove-Item -Force

# restore nuget
Write-Host "Nuget Restore"
dotnet restore $csproj.FullName

# build
Write-Host "Build پروژه"
dotnet build $csproj.FullName

Write-Host "پایان عملیات" -ForegroundColor Green
