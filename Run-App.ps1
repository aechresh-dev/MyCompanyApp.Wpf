$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"

$SolutionFile = Join-Path $ProjectRoot "MyCompanyApp.sln"
$WpfCsproj    = Join-Path $ProjectRoot "src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$DocsDir      = Join-Path $ProjectRoot "docs"
$LogDir       = Join-Path $DocsDir "_logs"
$LogPath      = Join-Path $LogDir ("restore_build_run_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Invoke-DotNet {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    Push-Location $ProjectRoot
    try {
        & dotnet @Arguments 2>&1 | Tee-Object -FilePath $LogPath -Append
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet command failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

Ensure-Directory $DocsDir
Ensure-Directory $LogDir

Write-Host "Restoring..." -ForegroundColor Cyan
Invoke-DotNet restore $SolutionFile

Write-Host "Building..." -ForegroundColor Cyan
Invoke-DotNet build $SolutionFile -c Release --no-restore

Write-Host "Running..." -ForegroundColor Green
Push-Location $ProjectRoot
try {
    & dotnet run --project $WpfCsproj -c Release --no-build
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Press Enter to exit..."
Read-Host
