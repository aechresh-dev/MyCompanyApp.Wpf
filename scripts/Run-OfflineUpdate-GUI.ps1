Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- تنظیمات ---
$Title = "MyCompanyApp - سیستم بروزرسانی آفلاین"
$Form = New-Object System.Windows.Forms.Form
$Form.Text = $Title
$Form.Size = New-Object System.Drawing.Size(500,250)
$Form.StartPosition = "CenterScreen"

$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Point(20,20)
$Label.Size = New-Object System.Drawing.Size(440,30)
$Label.Text = "در حال آماده‌سازی برای بروزرسانی..."
$Form.Controls.Add($Label)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(20,60)
$ProgressBar.Size = New-Object System.Drawing.Size(440,30)
$ProgressBar.Style = "Continuous"
$Form.Controls.Add($ProgressBar)

# --- تابع اصلی ---
$Form.Add_Shown({
    $script:updatePath = Join-Path $PSScriptRoot "*.mya"
    $file = Get-ChildItem $script:updatePath | Select-Object -First 1
    
    if (-not $file) {
        $Label.Text = "خطا: فایل آپدیت (.mya) پیدا نشد!"
        return
    }

    $Label.Text = "شروع استخراج فایل: " + $file.Name
    $targetDir = "C:\MyCompanyApp" # مسیر نصب برنامه خودت را اینجا ست کن
    $tempExtract = "$env:TEMP\UpdateExtract"
    
    # 1. استخراج
    $ProgressBar.Value = 20
    Expand-Archive $file.FullName -DestinationPath $tempExtract -Force
    
    # 2. بستن برنامه
    $Label.Text = "در حال بستن برنامه..."
    Stop-Process -Name "MyCompanyApp.Wpf" -ErrorAction SilentlyContinue
    $ProgressBar.Value = 50
    
    # 3. کپی فایل‌ها (جایگزینی)
    $Label.Text = "در حال جایگزینی فایل‌ها..."
    Copy-Item "$tempExtract\*" $targetDir -Recurse -Force
    $ProgressBar.Value = 80
    
    # 4. پاکسازی
    Remove-Item $tempExtract -Recurse -Force
    $ProgressBar.Value = 100
    
    $Label.Text = "بروزرسانی با موفقیت انجام شد!"
    
    # پایان
    Start-Sleep -Seconds 1
    $Form.Close()
    
    # اجرای مجدد برنامه
    Start-Process "$targetDir\MyCompanyApp.Wpf.exe"
})

[System.Windows.Forms.Application]::EnableVisualStyles()
$Form.ShowDialog()
