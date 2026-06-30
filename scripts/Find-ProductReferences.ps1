param(
    [string]$RootPath = ".",
    [switch]$Replace,
    [string]$NewName = "Item"
)

$RootPath = (Resolve-Path $RootPath).Path
Write-Host "`n🔎 جستجوی '$OldName' در کل پروژه..." -ForegroundColor Cyan
Write-Host "=" * 60

$allFiles = Get-ChildItem $RootPath -Recurse -File -Depth 5 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -in '.cs', '.xaml', '.csproj', '.sln', '.config', '.json', '.xml', '.md', '.txt' -and
        $_.FullName -notlike "*\.git\*" -and
        $_.FullName -notlike "*\Cleanup_Backup_*" -and
        $_.FullName -notlike "*\analysis-reports\*" -and
        $_.FullName -notlike "*\Analysis_Reports\*" -and
        $_.FullName -notlike "*\obj\*" -and
        $_.FullName -notlike "*\bin\*"
    }

$totalMatches = 0
$filesWithMatches = @()

foreach ($file in $allFiles) {
    $matches = Select-String -Path $file.FullName -Pattern $OldName -CaseSensitive -AllMatches
    if ($matches) {
        $filesWithMatches += $file
        $totalMatches += $matches.Matches.Count
        Write-Host "`n📄 $($file.FullName):" -ForegroundColor Yellow
        foreach ($line in $matches) {
            Write-Host "  خط $($line.LineNumber): $($line.Line.Trim())" -ForegroundColor Gray
        }
    }
}

Write-Host "`n📊 خلاصه: $totalMatches مورد '$OldName' در $($filesWithMatches.Count) فایل پیدا شد." -ForegroundColor Cyan

if ($Replace) {
    Write-Host "`n🔄 جایگزینی '$OldName' → '$NewName'..." -ForegroundColor Magenta
    $backupDir = Join-Path $RootPath "Replace_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    foreach ($file in $filesWithMatches) {
        $content = Get-Content $file.FullName -Raw
        $newContent = $content -replace $OldName, $NewName
        if ($newContent -ne $content) {
            $relativePath = $file.FullName.Substring($RootPath.Length).TrimStart('\')
            $backupPath = Join-Path $backupDir $relativePath
            $backupParent = Split-Path $backupPath -Parent
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
            Copy-Item $file.FullName $backupPath -Force

            Set-Content $file.FullName -Value $newContent -Encoding UTF8
            Write-Host "  ✅ $($file.Name) → $OldName → $NewName"
        }
    }
    Write-Host "`n📦 بکاپ در: $backupDir" -ForegroundColor Green
}

Read-Host "`nبرای خروج کلیدی بزنید..."
