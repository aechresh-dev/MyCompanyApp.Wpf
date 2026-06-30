param(
    [string]$Root = (Get-Location).Path,
    [string]$OutDir = "",
    [switch]$QuarantineCleanup
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function To-Array {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }

    return @($Value)
}

function Safe-Count {
    param($Value)

    if ($null -eq $Value) {
        return 0
    }

    return @(To-Array $Value).Count
}

function Read-TextSafe {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if (Test-Path -LiteralPath $Path) {
        try {
            return [System.IO.File]::ReadAllText($Path)
        }
        catch {
            return ""
        }
    }

    return ""
}

function Add-Finding {
    param(
        [System.Collections.ArrayList]$List,
        [string]$Category,
        [string]$Name,
        [string]$Status,
        [string]$Details,
        [string]$Evidence = ""
    )

    $null = $List.Add([pscustomobject]@{
        Category = $Category
        Name     = $Name
        Status   = $Status
        Details  = $Details
        Evidence = $Evidence
    })
}

function Get-AllFiles {
    param([string]$Path)

    return @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue)
}

function Get-AllDirs {
    param([string]$Path)

    return @(Get-ChildItem -LiteralPath $Path -Recurse -Force -Directory -ErrorAction SilentlyContinue)
}

function Search-InFiles {
    param(
        $Files,
        [string[]]$Patterns
    )

    $matches = New-Object System.Collections.ArrayList
    $safeFiles = @(To-Array $Files)

    foreach ($file in $safeFiles) {
        if ($null -eq $file) {
            continue
        }

        try {
            if (-not (Test-Path -LiteralPath $file.FullName)) {
                continue
            }

            $content = [System.IO.File]::ReadAllText($file.FullName)

            foreach ($pattern in $Patterns) {
                if ($content -match $pattern) {
                    $null = $matches.Add([pscustomobject]@{
                        File    = $file.FullName
                        Pattern = $pattern
                    })
                }
            }
        }
        catch {
        }
    }

    return @($matches)
}

function Get-RelativePath {
    param(
        [string]$Base,
        [string]$Full
    )

    try {
        $baseResolved = (Resolve-Path -LiteralPath $Base).Path
        $fullResolved = (Resolve-Path -LiteralPath $Full).Path

        $baseUri = New-Object System.Uri(($baseResolved.TrimEnd('\') + '\'))
        $fullUri = New-Object System.Uri($fullResolved)

        return [System.Uri]::UnescapeDataString(
            $baseUri.MakeRelativeUri($fullUri).ToString().Replace('/', '\')
        )
    }
    catch {
        return $Full
    }
}

function Is-InIgnoredPath {
    param(
        [string]$FullPath,
        [string[]]$IgnoredPatterns
    )

    foreach ($pattern in $IgnoredPatterns) {
        if ($FullPath -match $pattern) {
            return $true
        }
    }

    return $false
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Root path not found: $Root"
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $Root "Audit-Output"
}

Ensure-Dir $OutDir

$QuarantineDir = Join-Path $OutDir "Quarantine"

if ($QuarantineCleanup) {
    Ensure-Dir $QuarantineDir
}

$Findings = New-Object System.Collections.ArrayList
$CleanupCandidates = New-Object System.Collections.ArrayList
$ProjectStats = [ordered]@{}

$docPath = Join-Path $Root "PROJECT_DOCUMENTATION.md"
$docText = Read-TextSafe $docPath

$Rules = [ordered]@{
    ArchitectureStyle               = "Modular Clean Monolith"
    UIStyle                         = "WPF + MVVM"
    Database                        = "SQLite"
    ORM                             = "EF Core"
    Security                        = "RBAC"
    SingleDbContextRequired         = $true
    ExpectedModulesPresent          = @("Logs")
    ExpectedModulesMissing          = @("Notifications","Reports","Roles","Permissions","Backup","ImportExport","Dashboard","Identity","Settings")
}

Write-Host ""
Write-Host "Starting online project audit..." -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host ""

$allFiles = @(Get-AllFiles $Root)
$allDirs = @(Get-AllDirs $Root)

$csFiles = @($allFiles | Where-Object { $_.Extension -eq ".cs" })
$xamlFiles = @($allFiles | Where-Object { $_.Extension -eq ".xaml" })
$csprojFiles = @($allFiles | Where-Object { $_.Extension -eq ".csproj" })
$slnFiles = @($allFiles | Where-Object { $_.Extension -eq ".sln" })
$configFiles = @($allFiles | Where-Object { $_.Name -match 'appsettings|config|settings' })
$dbFiles = @($allFiles | Where-Object { $_.Extension -in @(".db",".sqlite",".sqlite3") })

$ProjectStats.Root = $Root
$ProjectStats.TotalFiles = @(To-Array $allFiles).Count
$ProjectStats.TotalDirectories = @(To-Array $allDirs).Count
$ProjectStats.CsFiles = @(To-Array $csFiles).Count
$ProjectStats.XamlFiles = @(To-Array $xamlFiles).Count
$ProjectStats.CsprojFiles = @(To-Array $csprojFiles).Count
$ProjectStats.SolutionFiles = @(To-Array $slnFiles).Count
$ProjectStats.DatabaseFiles = @(To-Array $dbFiles).Count

if (-not [string]::IsNullOrWhiteSpace($docText)) {
    Add-Finding -List $Findings -Category "Docs" -Name "PROJECT_DOCUMENTATION.md" -Status "PASS" -Details "Documentation file found and readable." -Evidence $docPath
}
else {
    Add-Finding -List $Findings -Category "Docs" -Name "PROJECT_DOCUMENTATION.md" -Status "WARN" -Details "Documentation file not found or empty. Built-in rules will be used." -Evidence $docPath
}

$wpfEvidence = @(Search-InFiles -Files $csprojFiles -Patterns @("UseWPF", "<UseWPF>true</UseWPF>"))

if (@(To-Array $wpfEvidence).Count -gt 0 -or @(To-Array $xamlFiles).Count -gt 0) {
    Add-Finding -List $Findings -Category "Architecture" -Name "WPF" -Status "PASS" -Details "WPF evidence found."
}
else {
    Add-Finding -List $Findings -Category "Architecture" -Name "WPF" -Status "FAIL" -Details "No clear WPF evidence found."
}

$mvvmFiles = @($allFiles | Where-Object {
    $_.Name -match 'ViewModel|BaseViewModel|ObservableObject|RelayCommand|DelegateCommand|Command'
})

if (@(To-Array $mvvmFiles).Count -gt 0) {
    Add-Finding -List $Findings -Category "Architecture" -Name "MVVM" -Status "PASS" -Details "MVVM-related files found: $(@(To-Array $mvvmFiles).Count)"
}
else {
    Add-Finding -List $Findings -Category "Architecture" -Name "MVVM" -Status "WARN" -Details "No strong MVVM file naming evidence found."
}

$efEvidence = @(Search-InFiles -Files ($csFiles + $csprojFiles) -Patterns @(
    "Microsoft\.EntityFrameworkCore",
    "DbContext",
    "DbSet<"
))

if (@(To-Array $efEvidence).Count -gt 0) {
    Add-Finding -List $Findings -Category "Data" -Name "EF Core" -Status "PASS" -Details "EF Core evidence found."
}
else {
    Add-Finding -List $Findings -Category "Data" -Name "EF Core" -Status "FAIL" -Details "EF Core evidence not found."
}

$sqliteEvidence = @(Search-InFiles -Files ($csFiles + $csprojFiles + $configFiles) -Patterns @(
    "Sqlite",
    "SQLite",
    "Microsoft\.EntityFrameworkCore\.Sqlite",
    "\.db\b"
))

if (@(To-Array $sqliteEvidence).Count -gt 0 -or @(To-Array $dbFiles).Count -gt 0) {
    Add-Finding -List $Findings -Category "Data" -Name "SQLite" -Status "PASS" -Details "SQLite evidence found."
}
else {
    Add-Finding -List $Findings -Category "Data" -Name "SQLite" -Status "FAIL" -Details "SQLite evidence not found."
}

$dbContextFiles = @(Search-InFiles -Files $csFiles -Patterns @(
    "class\s+\w*DbContext\s*:\s*DbContext",
    "class\s+AppDbContext\s*:\s*DbContext"
))

$dbContextGrouped = @($dbContextFiles | Group-Object File)
$dbContextCount = @(To-Array $dbContextGrouped).Count
$ProjectStats.DbContextCount = $dbContextCount

if ($dbContextCount -eq 1) {
    Add-Finding -List $Findings -Category "Data" -Name "Single AppDbContext" -Status "PASS" -Details "Exactly one DbContext implementation found." -Evidence (($dbContextGrouped | Select-Object -First 1).Name)
}
elseif ($dbContextCount -gt 1) {
    Add-Finding -List $Findings -Category "Data" -Name "Single AppDbContext" -Status "FAIL" -Details "Multiple DbContext implementations found: $dbContextCount" -Evidence (($dbContextGrouped | ForEach-Object { $_.Name }) -join "; ")
}
else {
    Add-Finding -List $Findings -Category "Data" -Name "Single AppDbContext" -Status "WARN" -Details "No DbContext implementation found."
}

$domainDirs = @($allDirs | Where-Object { $_.Name -match 'Domain' })
$applicationDirs = @($allDirs | Where-Object { $_.Name -match 'Application' })
$infrastructureDirs = @($allDirs | Where-Object { $_.Name -match 'Infrastructure|Persistence' })
$uiDirs = @($allDirs | Where-Object { $_.Name -match 'Wpf|UI|Presentation' })

if (@(To-Array $domainDirs).Count -gt 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "Domain Layer" -Status "PASS" -Details "Domain layer folder found."
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "Domain Layer" -Status "WARN" -Details "Domain layer folder not clearly found."
}

if (@(To-Array $applicationDirs).Count -gt 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "Application Layer" -Status "PASS" -Details "Application layer folder found."
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "Application Layer" -Status "WARN" -Details "Application layer folder not clearly found."
}

if (@(To-Array $infrastructureDirs).Count -gt 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "Infrastructure Layer" -Status "PASS" -Details "Infrastructure/Persistence folder found."
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "Infrastructure Layer" -Status "WARN" -Details "Infrastructure/Persistence folder not clearly found."
}

if (@(To-Array $uiDirs).Count -gt 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "UI Layer" -Status "PASS" -Details "UI/WPF/Presentation folder found."
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "UI Layer" -Status "WARN" -Details "UI/WPF/Presentation folder not clearly found."
}

$uiCodeFiles = @($csFiles | Where-Object { $_.FullName -match 'Wpf|UI|Presentation|Views|ViewModels' })

$uiBusinessMatches = @(Search-InFiles -Files $uiCodeFiles -Patterns @(
    "new\s+SqlConnection",
    "new\s+SQLiteConnection",
    "DbContext",
    "SaveChanges\s*\(",
    "ExecuteSql",
    "INSERT\s+INTO",
    "UPDATE\s+\w+",
    "DELETE\s+FROM",
    "business rule"
))

if (@(To-Array $uiBusinessMatches).Count -eq 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "UI contains no business rules" -Status "PASS" -Details "No obvious business/data access patterns found in UI."
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "UI contains no business rules" -Status "WARN" -Details "Possible business/data-access logic detected in UI files: $(@(To-Array $uiBusinessMatches).Count) matches." -Evidence (($uiBusinessMatches | Select-Object -First 10 | ForEach-Object { $_.File }) -join "; ")
}

$domainCsFiles = @($csFiles | Where-Object { $_.FullName -match 'Domain' })

$domainViolations = @(Search-InFiles -Files $domainCsFiles -Patterns @(
    "System\.Windows",
    "PresentationFramework",
    "Microsoft\.EntityFrameworkCore",
    "DbContext",
    "SQLite",
    "SqlConnection"
))

if (@(To-Array $domainViolations).Count -eq 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "Domain independent from UI and database" -Status "PASS" -Details "No obvious UI/DB dependency found in Domain."
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "Domain independent from UI and database" -Status "FAIL" -Details "Domain contains possible UI/DB dependencies: $(@(To-Array $domainViolations).Count) matches." -Evidence (($domainViolations | Select-Object -First 10 | ForEach-Object { $_.File }) -join "; ")
}

$appCsFiles = @($csFiles | Where-Object { $_.FullName -match 'Application' })

if (@(To-Array $appCsFiles).Count -gt 0) {
    Add-Finding -List $Findings -Category "Layers" -Name "Business logic in Application layer" -Status "PASS" -Details "Application files found: $(@(To-Array $appCsFiles).Count)"
}
else {
    Add-Finding -List $Findings -Category "Layers" -Name "Business logic in Application layer" -Status "WARN" -Details "Application layer files not clearly found."
}

$securityMatches = @(Search-InFiles -Files $csFiles -Patterns @(
    "Role",
    "Permission",
    "Login",
    "PasswordHash",
    "Lockout",
    "FailedLogin",
    "Authorize",
    "Authentication"
))

if (@(To-Array $securityMatches).Count -gt 0) {
    Add-Finding -List $Findings -Category "Security" -Name "RBAC / Identity Evidence" -Status "PASS" -Details "Security-related code patterns found: $(@(To-Array $securityMatches).Count)"
}
else {
    Add-Finding -List $Findings -Category "Security" -Name "RBAC / Identity Evidence" -Status "WARN" -Details "Security-related code patterns not clearly found."
}

$superAdminMatches = @(Search-InFiles -Files $csFiles -Patterns @("SuperAdmin"))

if (@(To-Array $superAdminMatches).Count -eq 0) {
    Add-Finding -List $Findings -Category "Security" -Name "No SuperAdmin" -Status "PASS" -Details "No SuperAdmin references found."
}
else {
    Add-Finding -List $Findings -Category "Security" -Name "No SuperAdmin" -Status "FAIL" -Details "SuperAdmin references found: $(@(To-Array $superAdminMatches).Count)" -Evidence (($superAdminMatches | Select-Object -First 10 | ForEach-Object { $_.File }) -join "; ")
}

$programDataMatches = @(Search-InFiles -Files ($csFiles + $configFiles) -Patterns @(
    "ProgramData",
    "MyCompanyApp\\Data",
    "MyCompanyApp\\Backups",
    "MyCompanyApp\\Logs"
))

if (@(To-Array $programDataMatches).Count -gt 0) {
    Add-Finding -List $Findings -Category "Storage" -Name "ProgramData Storage" -Status "PASS" -Details "ProgramData path evidence found."
}
else {
    Add-Finding -List $Findings -Category "Storage" -Name "ProgramData Storage" -Status "WARN" -Details "ProgramData storage path evidence not clearly found."
}

foreach ($module in $Rules.ExpectedModulesPresent) {
    $moduleFound = @($allDirs | Where-Object { $_.Name -eq $module })

    if (@(To-Array $moduleFound).Count -gt 0) {
        Add-Finding -List $Findings -Category "Modules" -Name $module -Status "PASS" -Details "Expected present module found."
    }
    else {
        Add-Finding -List $Findings -Category "Modules" -Name $module -Status "WARN" -Details "Expected present module not clearly found."
    }
}

foreach ($module in $Rules.ExpectedModulesMissing) {
    $moduleFound = @($allDirs | Where-Object { $_.Name -eq $module })

    if (@(To-Array $moduleFound).Count -gt 0) {
        Add-Finding -List $Findings -Category "Modules" -Name $module -Status "WARN" -Details "Module documented as missing but folder exists."
    }
    else {
        Add-Finding -List $Findings -Category "Modules" -Name $module -Status "PASS" -Details "Module documented as missing and not found."
    }
}

$ignoredDirPatterns = @(
    "\\bin\\",
    "\\obj\\",
    "\\.vs\\",
    "\\packages\\",
    "\\TestResults\\",
    "\\Audit-Output\\",
    "\\node_modules\\"
)

$junkFilePatterns = @(
    "\.user$",
    "\.suo$",
    "\.cache$",
    "\.tmp$",
    "\.bak$",
    "\.old$",
    "\.orig$",
    "\.rej$",
    "\.log$"
)

foreach ($file in $allFiles) {
    if ($null -eq $file) {
        continue
    }

    $full = $file.FullName

    if (Is-InIgnoredPath -FullPath $full -IgnoredPatterns $ignoredDirPatterns) {
        continue
    }

    $isCandidate = $false
    $reason = ""

    foreach ($fp in $junkFilePatterns) {
        if ($file.Name -match $fp) {
            $isCandidate = $true
            $reason = "Temporary/backup/user-specific file"
            break
        }
    }

    if (-not $isCandidate -and $file.Extension -in @(".db-wal",".db-shm")) {
        $isCandidate = $true
        $reason = "Transient SQLite sidecar file"
    }

    if (-not $isCandidate -and $file.FullName -match "\\Debug\\|\\Release\\") {
        $isCandidate = $true
        $reason = "Build output artifact"
    }

    if ($isCandidate) {
        $relative = Get-RelativePath -Base $Root -Full $file.FullName

        $null = $CleanupCandidates.Add([pscustomobject]@{
            File         = $file.FullName
            RelativePath = $relative
            Reason       = $reason
            Action       = if ($QuarantineCleanup) { "MOVE_TO_QUARANTINE" } else { "REPORT_ONLY" }
        })
    }
}

if ($QuarantineCleanup) {
    foreach ($item in $CleanupCandidates) {
        try {
            if (-not (Test-Path -LiteralPath $item.File)) {
                continue
            }

            $safeRelative = $item.RelativePath -replace "[:]", "_"
            $target = Join-Path $QuarantineDir $safeRelative
            $targetDir = Split-Path $target -Parent

            Ensure-Dir $targetDir

            Move-Item -LiteralPath $item.File -Destination $target -Force -ErrorAction Stop
        }
        catch {
        }
    }
}

$passCount = @($Findings | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = @($Findings | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = @($Findings | Where-Object { $_.Status -eq "FAIL" }).Count
$totalChecks = [Math]::Max(@(To-Array $Findings).Count, 1)

$auditScore = [Math]::Round((($passCount + ($warnCount * 0.5)) / $totalChecks) * 100, 2)

$Summary = [pscustomobject]@{
    Root              = $Root
    AuditScore        = $auditScore
    TotalChecks       = $totalChecks
    PassCount         = $passCount
    WarnCount         = $warnCount
    FailCount         = $failCount
    CleanupCandidates = @(To-Array $CleanupCandidates).Count
    QuarantineMode    = [bool]$QuarantineCleanup
    Stats             = $ProjectStats
}

$Report = [pscustomobject]@{
    Summary           = $Summary
    Rules             = $Rules
    Findings          = $Findings
    CleanupCandidates = $CleanupCandidates
}

$jsonPath = Join-Path $OutDir "audit-report.json"
$txtPath  = Join-Path $OutDir "audit-report.txt"

$Report | ConvertTo-Json -Depth 12 | Set-Content -Path $jsonPath -Encoding UTF8

$txt = New-Object System.Text.StringBuilder

[void]$txt.AppendLine("PROJECT ONLINE AUDIT REPORT")
[void]$txt.AppendLine("====================================")
[void]$txt.AppendLine("Root: $Root")
[void]$txt.AppendLine("Audit Score: $auditScore%")
[void]$txt.AppendLine("Pass: $passCount")
[void]$txt.AppendLine("Warn: $warnCount")
[void]$txt.AppendLine("Fail: $failCount")
[void]$txt.AppendLine("Cleanup Candidates: $(@(To-Array $CleanupCandidates).Count)")
[void]$txt.AppendLine("Quarantine Mode: $([bool]$QuarantineCleanup)")
[void]$txt.AppendLine("")
[void]$txt.AppendLine("PROJECT STATS")
[void]$txt.AppendLine("-------------")

foreach ($key in $ProjectStats.Keys) {
    [void]$txt.AppendLine("${key}: $($ProjectStats[$key])")
}

[void]$txt.AppendLine("")
[void]$txt.AppendLine("CHECKS")
[void]$txt.AppendLine("------")

foreach ($f in $Findings) {
    [void]$txt.AppendLine("[$($f.Status)] $($f.Category) :: $($f.Name) -> $($f.Details)")
    if (-not [string]::IsNullOrWhiteSpace($f.Evidence)) {
        [void]$txt.AppendLine("    Evidence: $($f.Evidence)")
    }
}

[void]$txt.AppendLine("")
[void]$txt.AppendLine("CLEANUP CANDIDATES")
[void]$txt.AppendLine("------------------")

foreach ($c in $CleanupCandidates) {
    [void]$txt.AppendLine("$($c.RelativePath) | $($c.Reason) | $($c.Action)")
}

Set-Content -Path $txtPath -Value $txt.ToString() -Encoding UTF8

Write-Host ""
Write-Host "Audit complete." -ForegroundColor Green
Write-Host "Audit Score        : $auditScore%"
Write-Host "Pass/Warn/Fail     : $passCount / $warnCount / $failCount"
Write-Host "Cleanup Candidates : $(@(To-Array $CleanupCandidates).Count)"
Write-Host "JSON Report        : $jsonPath"
Write-Host "TXT Report         : $txtPath"

if ($QuarantineCleanup) {
    Write-Host "Quarantine Folder  : $QuarantineDir"
}

Write-Host ""

