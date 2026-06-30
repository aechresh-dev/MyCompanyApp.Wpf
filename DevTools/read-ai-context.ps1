$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
$Docs = Join-Path $ProjectRoot "Docs"
$Files = @(
    "DAILY_AI_EXECUTION_FILE.txt",
    "AI_MASTER_PROMPT.txt",
    "AI_PROJECT_CONTEXT.md",
    "PROJECT_FEATURES.md",
    "AI_DEVELOPMENT_ROADMAP.md",
    "AI_TASK_LOG.md",
    "ARCHITECTURE.md",
    "AI_AUTOMATED_ANALYSIS_REPORT.md"
)

foreach ($file in $Files) {
    $path = Join-Path $Docs $file
    if (Test-Path $path) {
        Write-Host ""
        Write-Host "==================== $file ===================="
        Get-Content $path -Raw
    }
}
