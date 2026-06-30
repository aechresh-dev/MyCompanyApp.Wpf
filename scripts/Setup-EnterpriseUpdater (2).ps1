# Fixed: Added ProjectRoot initialization
$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$PSScriptRoot = $ProjectRoot
# Fixed: Added ProjectRoot initialization
$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$PSScriptRoot = $ProjectRoot
# Fixed: Added ProjectRoot initialization
$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$PSScriptRoot = $ProjectRoot
# Fixed: Added ProjectRoot initialization
$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$PSScriptRoot = $ProjectRoot
# Fix-ProjectRoot.ps1
# این اسکریپت مشکل مقداردهی $ProjectRoot را رفع می‌کند

param(
    [string]$ProjectPath = $PSScriptRoot
)

# ۱. بررسی وجود فایل Cleanup-Full.ps1
$cleanupScript = Join-Path $ProjectPath "Cleanup-Full.ps1"
if (-not (Test-Path $cleanupScript)) {
    Write-Error "فایل Cleanup-Full.ps1 یافت نشد در مسیر: $cleanupScript"
    exit 1
}

# ۲. خواندن محتوای فایل
$content = Get-Content $cleanupScript -Raw

# ۳. اضافه کردن مقداردهی $ProjectRoot در ابتدای فایل
$fixedContent = @"
# Fixed: Added ProjectRoot initialization
`$ProjectRoot = `"$ProjectPath`"
`$PSScriptRoot = `$ProjectRoot

"@ + $content

# ۴. جایگزینی فایل
$fixedContent | Out-File $cleanupScript -Encoding UTF8 -Force
Write-Host "✅ فایل Cleanup-Full.ps1 با موفقیت اصلاح شد" -ForegroundColor Green




