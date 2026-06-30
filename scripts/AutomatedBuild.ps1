Write-Host "--- Starting Professional Build Process for امیر ---" -ForegroundColor Cyan

# ۱. رفتن به پوشه اصلی
cd 'G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf'

# ۲. پاکسازی
Write-Host "Cleaning Solution..." -ForegroundColor Yellow
dotnet clean MyCompanyApp.sln

# ۳. انتشار فقط پروژه WPF به صورت Self-Contained و Single-File
Write-Host "Publishing Main WPF App..." -ForegroundColor Magenta

# نکته: اینجا مستقیما فایل csproj هدف قرار گرفته تا خطای NETSDK1099 پیش نیاد
dotnet publish 'G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj' -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishReadyToRun=true -p:IncludeNativeLibrariesForSelfExtract=true -o "./Publish"

if ($?) {
    Write-Host "
[SUCCESS] Your app is ready in the 'Publish' folder." -ForegroundColor Green
    Write-Host "All dependencies (PresentationFramework, etc.) are embedded inside the EXE." -ForegroundColor White
    explorer "./Publish"
} else {
    Write-Host "
[FAILED] Build failed. Please check the errors above." -ForegroundColor Red
}
