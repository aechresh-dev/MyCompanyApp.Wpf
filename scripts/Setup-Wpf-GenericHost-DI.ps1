#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================
# 1) CONFIG
# =========================

$Root = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportDir = Join-Path $Root "analysis-reports"
$ReportPath = Join-Path $ReportDir "project-structure-analysis-$Timestamp.txt"
$JsonPath = Join-Path $ReportDir "project-structure-analysis-$Timestamp.json"

$ExcludedFolderRegex = '\\(\.git|bin|obj|artifacts|legacy|backups|_backups|_backup_[^\\]*|backup-before-[^\\]*|WPF_Cleanup_Backup_[^\\]*|_code_backup_[^\\]*)(\\|$)'
$BackupFileRegex = '\.(bak|backup|old)(\.|-|$)|repair-bak'

# =========================
# 2) HELPERS
# =========================

function Write-Section {
    param([string]$Title)

    $line = "=" * 90
    Write-Host ""
    Write-Host $line -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkGray
}

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    try {
        $baseUri = [Uri]((Resolve-Path $BasePath).Path.TrimEnd('\') + '\')
        $fullUri = [Uri]((Resolve-Path $FullPath).Path)
        return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString()).Replace('/', '\')
    }
    catch {
        return $FullPath
    }
}

function Test-IsExcludedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -match $ExcludedFolderRegex)
}

function Test-IsBackupFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.Path]::GetFileName($Path) -match $BackupFileRegex)
}

function Resolve-ProjectReferencePath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectFile,
        [Parameter(Mandatory = $true)][string]$ReferenceInclude
    )

    $projectDir = Split-Path $ProjectFile -Parent
    $combined = Join-Path $projectDir $ReferenceInclude

    try {
        return [System.IO.Path]::GetFullPath($combined)
    }
    catch {
        return $combined
    }
}

function Parse-SlnProjects {
    param([Parameter(Mandatory = $true)][string]$SolutionPath)

    $solutionDir = Split-Path $SolutionPath -Parent
    $lines = Get-Content -LiteralPath $SolutionPath -Encoding UTF8

    $results = @()

    foreach ($line in $lines) {
        if ($line -match '^Project\("\{[^}]+\}"\)\s*=\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"\{[^}]+\}"') {
            $name = $Matches[1]
            $relativePath = $Matches[2]

            if ($relativePath -like "*.csproj") {
                $fullPath = [System.IO.Path]::GetFullPath((Join-Path $solutionDir $relativePath))
                $exists = Test-Path -LiteralPath $fullPath

                $results += [PSCustomObject]@{
                    Solution      = $SolutionPath
                    SolutionName  = Split-Path $SolutionPath -Leaf
                    ProjectName   = $name
                    RelativePath  = $relativePath
                    FullPath      = $fullPath
                    Exists        = $exists
                    IsExcluded    = Test-IsExcludedPath $fullPath
                    IsBackupFile  = Test-IsBackupFile $fullPath
                }
            }
        }
    }

    return $results
}

function Get-XmlNodeTextSafe {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][string]$Name
    )

    try {
        $child = $Node.ChildNodes | Where-Object { #requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================
# 1) CONFIG
# =========================

$Root = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportDir = Join-Path $Root "analysis-reports"
$ReportPath = Join-Path $ReportDir "project-structure-analysis-$Timestamp.txt"
$JsonPath = Join-Path $ReportDir "project-structure-analysis-$Timestamp.json"

$ExcludedFolderRegex = '\\(\.git|bin|obj|artifacts|legacy|backups|_backups|_backup_[^\\]*|backup-before-[^\\]*|WPF_Cleanup_Backup_[^\\]*|_code_backup_[^\\]*)(\\|$)'
$BackupFileRegex = '\.(bak|backup|old)(\.|-|$)|repair-bak'

# =========================
# 2) HELPERS
# =========================

function Write-Section {
    param([string]$Title)

    $line = "=" * 90
    Write-Host ""
    Write-Host $line -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkGray
}

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    try {
        $baseUri = [Uri]((Resolve-Path $BasePath).Path.TrimEnd('\') + '\')
        $fullUri = [Uri]((Resolve-Path $FullPath).Path)
        return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString()).Replace('/', '\')
    }
    catch {
        return $FullPath
    }
}

function Test-IsExcludedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -match $ExcludedFolderRegex)
}

function Test-IsBackupFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.Path]::GetFileName($Path) -match $BackupFileRegex)
}

function Resolve-ProjectReferencePath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectFile,
        [Parameter(Mandatory = $true)][string]$ReferenceInclude
    )

    $projectDir = Split-Path $ProjectFile -Parent
    $combined = Join-Path $projectDir $ReferenceInclude

    try {
        return [System.IO.Path]::GetFullPath($combined)
    }
    catch {
        return $combined
    }
}

function Parse-SlnProjects {
    param([Parameter(Mandatory = $true)][string]$SolutionPath)

    $solutionDir = Split-Path $SolutionPath -Parent
    $lines = Get-Content -LiteralPath $SolutionPath -Encoding UTF8

    $results = @()

    foreach ($line in $lines) {
        if ($line -match '^Project\("\{[^}]+\}"\)\s*=\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"\{[^}]+\}"') {
            $name = $Matches[1]
            $relativePath = $Matches[2]

            if ($relativePath -like "*.csproj") {
                $fullPath = [System.IO.Path]::GetFullPath((Join-Path $solutionDir $relativePath))
                $exists = Test-Path -LiteralPath $fullPath

                $results += [PSCustomObject]@{
                    Solution      = $SolutionPath
                    SolutionName  = Split-Path $SolutionPath -Leaf
                    ProjectName   = $name
                    RelativePath  = $relativePath
                    FullPath      = $fullPath
                    Exists        = $exists
                    IsExcluded    = Test-IsExcludedPath $fullPath
                    IsBackupFile  = Test-IsBackupFile $fullPath
                }
            }
        }
    }

    return $results
}

function Parse-CsprojInfo {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)

    [xml]$xml = Get-Content -LiteralPath $ProjectPath -Encoding UTF8

    $targetFramework = $null
    $targetFrameworks = $null
    $outputType = $null
    $useWpf = $null
    $assemblyName = $null
    $rootNamespace = $null

    if ($xml.Project.PropertyGroup) {
        foreach ($pg in $xml.Project.PropertyGroup) {
            if (-not $targetFramework -and $pg.TargetFramework) { $targetFramework = [string]$pg.TargetFramework }
            if (-not $targetFrameworks -and $pg.TargetFrameworks) { $targetFrameworks = [string]$pg.TargetFrameworks }
            if (-not $outputType -and $pg.OutputType) { $outputType = [string]$pg.OutputType }
            if (-not $useWpf -and $pg.UseWPF) { $useWpf = [string]$pg.UseWPF }
            if (-not $assemblyName -and $pg.AssemblyName) { $assemblyName = [string]$pg.AssemblyName }
            if (-not $rootNamespace -and $pg.RootNamespace) { $rootNamespace = [string]$pg.RootNamespace }
        }
    }

    $refs = @()
    $projectRefs = $xml.Project.ItemGroup.ProjectReference

    foreach ($ref in $projectRefs) {
        $include = [string]$ref.Include
        if ([string]::IsNullOrWhiteSpace($include)) { continue }

        $resolved = Resolve-ProjectReferencePath -ProjectFile $ProjectPath -ReferenceInclude $include

        $refs += [PSCustomObject]@{
            Include      = $include
            ResolvedPath = $resolved
            Exists       = Test-Path -LiteralPath $resolved
            IsExcluded   = Test-IsExcludedPath $resolved
            IsBackupFile = Test-IsBackupFile $resolved
        }
    }

    return [PSCustomObject]@{
        ProjectPath      = $ProjectPath
        ProjectFileName  = Split-Path $ProjectPath -Leaf
        ProjectDirectory = Split-Path $ProjectPath -Parent
        RelativePath     = Get-RelativePathSafe -BasePath $Root -FullPath $ProjectPath
        TargetFramework  = $targetFramework
        TargetFrameworks = $targetFrameworks
        OutputType       = $outputType
        UseWPF           = $useWpf
        AssemblyName     = $assemblyName
        RootNamespace    = $rootNamespace
        IsExcluded       = Test-IsExcludedPath $ProjectPath
        IsBackupFile     = Test-IsBackupFile $ProjectPath
        References       = $refs
    }
}

function Out-Text {
    param([string]$Text)
    $Text | Tee-Object -FilePath $ReportPath -Append
}

function Out-ObjectTable {
    param(
        $Objects,
        [string[]]$Properties
    )

    if ($null -eq $Objects -or @($Objects).Count -eq 0) {
        Out-Text "No items found."
        return
    }

    $formatted = $Objects | Format-Table -AutoSize $Properties | Out-String -Width 220
    Out-Text $formatted
}

# =========================
# 3) PREPARE REPORT
# =========================

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Root path not found: $Root"
}

if (-not (Test-Path -LiteralPath $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir | Out-Null
}

if (Test-Path -LiteralPath $ReportPath) {
    Remove-Item -LiteralPath $ReportPath -Force
}

Out-Text "MyCompanyApp.Wpf Project Structure Analysis"
Out-Text "Root: $Root"
Out-Text "Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Out-Text ""

# =========================
# 4) COLLECT FILES
# =========================

Write-Section "Collecting files"

$AllSlnFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "*.sln" |
    Where-Object { -not (Test-IsExcludedPath $_.FullName) } |
    Sort-Object FullName

$AllCsprojFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "*.csproj" |
    Sort-Object FullName

$ActiveCandidateCsprojFiles = $AllCsprojFiles |
    Where-Object {
        -not (Test-IsExcludedPath $_.FullName) -and
        -not (Test-IsBackupFile $_.FullName)
    } |
    Sort-Object FullName

# =========================
# 5) SOLUTION PROJECTS
# =========================

Write-Section "Solution Projects"

$SlnProjectEntries = @()

foreach ($sln in $AllSlnFiles) {
    $entries = Parse-SlnProjects -SolutionPath $sln.FullName
    $SlnProjectEntries += $entries
}

Out-Text "`n[Solutions found]"
Out-ObjectTable `
    -Objects ($AllSlnFiles | Select-Object Name, FullName) `
    -Properties @("Name", "FullName")

Out-Text "`n[Projects registered inside solutions]"
Out-ObjectTable `
    -Objects ($SlnProjectEntries | Select-Object SolutionName, ProjectName, RelativePath, Exists, IsExcluded) `
    -Properties @("SolutionName", "ProjectName", "RelativePath", "Exists", "IsExcluded")

# =========================
# 6) CSPROJ DETAILS
# =========================

Write-Section "Project files and ProjectReferences"

$ProjectInfos = @()

foreach ($csproj in $ActiveCandidateCsprojFiles) {
    try {
        $ProjectInfos += Parse-CsprojInfo -ProjectPath $csproj.FullName
    }
    catch {
        Out-Text "Failed to parse csproj: $($csproj.FullName)"
        Out-Text "Error: $($_.Exception.Message)"
    }
}

Out-Text "`n[Active candidate csproj files]"
Out-ObjectTable `
    -Objects ($ProjectInfos | Select-Object ProjectFileName, RelativePath, TargetFramework, OutputType, UseWPF) `
    -Properties @("ProjectFileName", "RelativePath", "TargetFramework", "OutputType", "UseWPF")

Out-Text "`n[ProjectReference graph]"

$ReferenceRows = @()

foreach ($p in $ProjectInfos) {
    if ($p.References.Count -eq 0) {
        $ReferenceRows += [PSCustomObject]@{
            Project        = $p.RelativePath
            Reference      = "[No ProjectReference]"
            Resolved       = ""
            Exists         = ""
            ReferenceState = ""
        }
    }
    else {
        foreach ($r in $p.References) {
            $ReferenceRows += [PSCustomObject]@{
                Project        = $p.RelativePath
                Reference      = $r.Include
                Resolved       = Get-RelativePathSafe -BasePath $Root -FullPath $r.ResolvedPath
                Exists         = $r.Exists
                ReferenceState = if ($r.IsExcluded) { "Excluded/Legacy/Generated" } else { "ActiveCandidate" }
            }
        }
    }
}

Out-ObjectTable `
    -Objects $ReferenceRows `
    -Properties @("Project", "Reference", "Resolved", "Exists", "ReferenceState")

# =========================
# 7) DUPLICATE PROJECT NAMES
# =========================

Write-Section "Duplicate project names"

$DuplicateGroups = $ActiveCandidateCsprojFiles |
    Group-Object Name |
    Where-Object { $_.Count -gt 1 } |
    Sort-Object Name

$DuplicateRows = @()

foreach ($group in $DuplicateGroups) {
    foreach ($item in $group.Group) {
        $DuplicateRows += [PSCustomObject]@{
            ProjectFileName = $group.Name
            Count           = $group.Count
            FullPath        = $item.FullName
            RelativePath    = Get-RelativePathSafe -BasePath $Root -FullPath $item.FullName
        }
    }
}

Out-ObjectTable `
    -Objects $DuplicateRows `
    -Properties @("ProjectFileName", "Count", "RelativePath")

# =========================
# 8) WPF CANDIDATES
# =========================

Write-Section "WPF candidates"

$WpfCandidates = $ProjectInfos | Where-Object {
    $_.UseWPF -match 'true' -or
    $_.TargetFramework -match 'windows' -or
    $_.ProjectFileName -match 'Wpf'
}

Out-ObjectTable `
    -Objects ($WpfCandidates | Select-Object ProjectFileName, RelativePath, TargetFramework, OutputType, UseWPF) `
    -Properties @("ProjectFileName", "RelativePath", "TargetFramework", "OutputType", "UseWPF")

$MixedWpfReferenceRows = @()

foreach ($wpf in $WpfCandidates) {
    $refs = $wpf.References

    $hasOldApplication = $refs | Where-Object { $_.ResolvedPath -match '\\src\\Application\\MyCompanyApp\.Application\.csproj$' }
    $hasNewApplication = $refs | Where-Object { $_.ResolvedPath -match '\\src\\MyCompanyApp\.Application\\MyCompanyApp\.Application\.csproj$' }

    $hasOldDomain = $refs | Where-Object { $_.ResolvedPath -match '\\src\\Domain\\MyCompanyApp\.Domain\.csproj$' }
    $hasNewDomain = $refs | Where-Object { $_.ResolvedPath -match '\\src\\MyCompanyApp\.Domain\\MyCompanyApp\.Domain\.csproj$' }

    $hasOldInfrastructure = $refs | Where-Object { $_.ResolvedPath -match '\\src\\Infrastructure\\MyCompanyApp\.Infrastructure\.csproj$' }
    $hasNewInfrastructure = $refs | Where-Object { $_.ResolvedPath -match '\\src\\MyCompanyApp\.Infrastructure\\MyCompanyApp\.Infrastructure\.csproj$' }

    $mixed = (
        ($hasOldApplication -and $hasNewApplication) -or
        ($hasOldDomain -and $hasNewDomain) -or
        ($hasOldInfrastructure -and $hasNewInfrastructure)
    )

    $MixedWpfReferenceRows += [PSCustomObject]@{
        WpfProject              = $wpf.RelativePath
        HasOldApplication       = [bool]$hasOldApplication
        HasNewApplication       = [bool]$hasNewApplication
        HasOldDomain            = [bool]$hasOldDomain
        HasNewDomain            = [bool]$hasNewDomain
        HasOldInfrastructure    = [bool]$hasOldInfrastructure
        HasNewInfrastructure    = [bool]$hasNewInfrastructure
        HasMixedDuplicateRefs   = [bool]$mixed
    }
}

Out-Text "`n[WPF mixed duplicate reference analysis]"
Out-ObjectTable `
    -Objects $MixedWpfReferenceRows `
    -Properties @(
        "WpfProject",
        "HasOldApplication",
        "HasNewApplication",
        "HasOldDomain",
        "HasNewDomain",
        "HasOldInfrastructure",
        "HasNewInfrastructure",
        "HasMixedDuplicateRefs"
    )

# =========================
# 9) BACKUP / LEGACY / GENERATED
# =========================

Write-Section "Backup / legacy / generated inventory"

$BackupLikeDirectories = Get-ChildItem -LiteralPath $Root -Recurse -Directory |
    Where-Object {
        $_.FullName -match '\\(legacy|backups|_backups|_backup_[^\\]*|backup-before-[^\\]*|WPF_Cleanup_Backup_[^\\]*|_code_backup_[^\\]*)(\\|$)'
    } |
    Sort-Object FullName

$BackupLikeFiles = Get-ChildItem -LiteralPath $Root -Recurse -File |
    Where-Object { Test-IsBackupFile $_.FullName } |
    Sort-Object FullName

Out-Text "`n[Backup/legacy-like directories]"
Out-ObjectTable `
    -Objects ($BackupLikeDirectories | Select-Object Name, FullName) `
    -Properties @("Name", "FullName")

Out-Text "`n[Backup-like files]"
Out-ObjectTable `
    -Objects ($BackupLikeFiles | Select-Object Name, FullName) `
    -Properties @("Name", "FullName")

# =========================
# 10) HEURISTIC ACTIVE TREE DECISION
# =========================

Write-Section "Heuristic active tree decision"

$IncludedProjectFullPaths = $SlnProjectEntries |
    Where-Object { $_.Exists -eq $true -and $_.IsExcluded -eq $false } |
    ForEach-Object { [System.IO.Path]::GetFullPath($_.FullPath) } |
    Select-Object -Unique

$HeuristicRows = @()

foreach ($p in $ProjectInfos) {
    $full = [System.IO.Path]::GetFullPath($p.ProjectPath)

    $isIncludedInSln = $IncludedProjectFullPaths -contains $full
    $isReferencedByAny = $false

    foreach ($other in $ProjectInfos) {
        foreach ($r in $other.References) {
            if ([System.IO.Path]::GetFullPath($r.ResolvedPath) -eq $full) {
                $isReferencedByAny = $true
            }
        }
    }

    $treeType = "Unknown"

    if ($p.RelativePath -match '^src\\MyCompanyApp\.') {
        $treeType = "NewNamedTree"
    }
    elseif ($p.RelativePath -match '^src\\(Application|Domain|Infrastructure)\\') {
        $treeType = "OldShortTree"
    }
    elseif ($p.RelativePath -match '^src\\Wpf\\') {
        $treeType = "WpfShortTree"
    }
    elseif ($p.RelativePath -match '^src\\MyCompanyApp\.Wpf\\') {
        $treeType = "WpfNamedTree"
    }
    elseif ($p.RelativePath -match '^tests\\') {
        $treeType = "Tests"
    }
    elseif ($p.RelativePath -match '^TestProject\\') {
        $treeType = "ScratchTestProject"
    }

    $score = 0
    if ($isIncludedInSln) { $score += 5 }
    if ($isReferencedByAny) { $score += 3 }
    if ($treeType -eq "NewNamedTree") { $score += 2 }
    if ($treeType -eq "WpfShortTree") { $score += 2 }
    if ($treeType -eq "OldShortTree") { $score += 1 }
    if ($treeType -eq "ScratchTestProject") { $score -= 3 }

    $HeuristicRows += [PSCustomObject]@{
        Project         = $p.RelativePath
        TreeType        = $treeType
        InSolution      = $isIncludedInSln
        ReferencedByAny = $isReferencedByAny
        Score           = $score
    }
}

Out-ObjectTable `
    -Objects ($HeuristicRows | Sort-Object @{ Expression = "Score"; Descending = $true }, @{ Expression = "Project"; Descending = $false }) `
    -Properties @("Project", "TreeType", "InSolution", "ReferencedByAny", "Score")

# =========================
# 11) FINAL RECOMMENDATIONS
# =========================

Write-Section "Recommended next actions"

Out-Text @"
Recommended interpretation rules:

1. If a project appears in the active .sln and is referenced by WPF, it is active.
2. If duplicate project names exist, do NOT delete either side until WPF references are normalized.
3. If WPF references both:
   - src\Application and src\MyCompanyApp.Application
   - src\Domain and src\MyCompanyApp.Domain
   - src\Infrastructure and src\MyCompanyApp.Infrastructure
   then WPF is currently in mixed/unsafe state.
4. backup-before-*, WPF_Cleanup_Backup_*, legacy, backups, _backups, bin, obj, artifacts are not source-of-truth.
5. After references are normalized, run:
   dotnet clean
   dotnet restore
   dotnet build
   dotnet test
"@

# =========================
# 12) EXPORT JSON
# =========================

$ExportObject = [PSCustomObject]@{
    Root                   = $Root
    GeneratedAt            = Get-Date
    Solutions              = $AllSlnFiles.FullName
    SolutionProjectEntries = $SlnProjectEntries
    Projects               = $ProjectInfos
    DuplicateProjects      = $DuplicateRows
    WpfCandidates          = $WpfCandidates
    WpfMixedReferences     = $MixedWpfReferenceRows
    HeuristicDecision      = $HeuristicRows
    BackupDirectories      = $BackupLikeDirectories.FullName
    BackupFiles            = $BackupLikeFiles.FullName
}

$ExportObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8

Write-Section "Done"

Write-Host ""
Write-Host "Text report:" -ForegroundColor Green
Write-Host $ReportPath

Write-Host ""
Write-Host "JSON report:" -ForegroundColor Green
Write-Host $JsonPath

Write-Host ""
Write-Host "Analysis completed." -ForegroundColor Green

.Name -eq $Name } | Select-Object -First 1
        if ($null -ne $child) {
            return [string]$child.InnerText
        }
    }
    catch {
        return $null
    }

    return $null
}

function Parse-CsprojInfo {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)

    [xml]$xml = Get-Content -LiteralPath $ProjectPath -Encoding UTF8

    $targetFramework = $null
    $targetFrameworks = $null
    $outputType = $null
    $useWpf = $null
    $assemblyName = $null
    $rootNamespace = $null

    $propertyGroups = @()
    if ($null -ne $xml.Project -and $null -ne $xml.Project.PropertyGroup) {
        $propertyGroups = @($xml.Project.PropertyGroup)
    }

    foreach ($pg in $propertyGroups) {
        if (-not $targetFramework) {
            $value = Get-XmlNodeTextSafe -Node $pg -Name "TargetFramework"
            if (-not [string]::IsNullOrWhiteSpace($value)) { $targetFramework = $value }
        }

        if (-not $targetFrameworks) {
            $value = Get-XmlNodeTextSafe -Node $pg -Name "TargetFrameworks"
            if (-not [string]::IsNullOrWhiteSpace($value)) { $targetFrameworks = $value }
        }

        if (-not $outputType) {
            $value = Get-XmlNodeTextSafe -Node $pg -Name "OutputType"
            if (-not [string]::IsNullOrWhiteSpace($value)) { $outputType = $value }
        }

        if (-not $useWpf) {
            $value = Get-XmlNodeTextSafe -Node $pg -Name "UseWPF"
            if (-not [string]::IsNullOrWhiteSpace($value)) { $useWpf = $value }
        }

        if (-not $assemblyName) {
            $value = Get-XmlNodeTextSafe -Node $pg -Name "AssemblyName"
            if (-not [string]::IsNullOrWhiteSpace($value)) { $assemblyName = $value }
        }

        if (-not $rootNamespace) {
            $value = Get-XmlNodeTextSafe -Node $pg -Name "RootNamespace"
            if (-not [string]::IsNullOrWhiteSpace($value)) { $rootNamespace = $value }
        }
    }

    $refs = @()

    $itemGroups = @()
    if ($null -ne $xml.Project -and $null -ne $xml.Project.ItemGroup) {
        $itemGroups = @($xml.Project.ItemGroup)
    }

    foreach ($ig in $itemGroups) {
        $projectReferences = @()

        try {
            if ($null -ne $ig.ProjectReference) {
                $projectReferences = @($ig.ProjectReference)
            }
        }
        catch {
            $projectReferences = @()
        }

        foreach ($ref in $projectReferences) {
            $include = $null

            try {
                $include = [string]$ref.Include
            }
            catch {
                $include = $null
            }

            if ([string]::IsNullOrWhiteSpace($include)) { continue }

            $resolved = Resolve-ProjectReferencePath -ProjectFile $ProjectPath -ReferenceInclude $include

            $refs += [PSCustomObject]@{
                Include      = $include
                ResolvedPath = $resolved
                Exists       = Test-Path -LiteralPath $resolved
                IsExcluded   = Test-IsExcludedPath $resolved
                IsBackupFile = Test-IsBackupFile $resolved
            }
        }
    }

    return [PSCustomObject]@{
        ProjectPath      = $ProjectPath
        ProjectFileName  = Split-Path $ProjectPath -Leaf
        ProjectDirectory = Split-Path $ProjectPath -Parent
        RelativePath     = Get-RelativePathSafe -BasePath $Root -FullPath $ProjectPath
        TargetFramework  = $targetFramework
        TargetFrameworks = $targetFrameworks
        OutputType       = $outputType
        UseWPF           = $useWpf
        AssemblyName     = $assemblyName
        RootNamespace    = $rootNamespace
        IsExcluded       = Test-IsExcludedPath $ProjectPath
        IsBackupFile     = Test-IsBackupFile $ProjectPath
        References       = @($refs)
    }
}

function Out-Text {
    param([string]$Text)
    $Text | Tee-Object -FilePath $ReportPath -Append
}

function Out-ObjectTable {
    param(
        $Objects,
        [string[]]$Properties
    )

    if ($null -eq $Objects -or @($Objects).Count -eq 0) {
        Out-Text "No items found."
        return
    }

    $formatted = $Objects | Format-Table -AutoSize $Properties | Out-String -Width 220
    Out-Text $formatted
}

# =========================
# 3) PREPARE REPORT
# =========================

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Root path not found: $Root"
}

if (-not (Test-Path -LiteralPath $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir | Out-Null
}

if (Test-Path -LiteralPath $ReportPath) {
    Remove-Item -LiteralPath $ReportPath -Force
}

Out-Text "MyCompanyApp.Wpf Project Structure Analysis"
Out-Text "Root: $Root"
Out-Text "Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Out-Text ""

# =========================
# 4) COLLECT FILES
# =========================

Write-Section "Collecting files"

$AllSlnFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "*.sln" |
    Where-Object { -not (Test-IsExcludedPath $_.FullName) } |
    Sort-Object FullName

$AllCsprojFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "*.csproj" |
    Sort-Object FullName

$ActiveCandidateCsprojFiles = $AllCsprojFiles |
    Where-Object {
        -not (Test-IsExcludedPath $_.FullName) -and
        -not (Test-IsBackupFile $_.FullName)
    } |
    Sort-Object FullName

# =========================
# 5) SOLUTION PROJECTS
# =========================

Write-Section "Solution Projects"

$SlnProjectEntries = @()

foreach ($sln in $AllSlnFiles) {
    $entries = Parse-SlnProjects -SolutionPath $sln.FullName
    $SlnProjectEntries += $entries
}

Out-Text "`n[Solutions found]"
Out-ObjectTable `
    -Objects ($AllSlnFiles | Select-Object Name, FullName) `
    -Properties @("Name", "FullName")

Out-Text "`n[Projects registered inside solutions]"
Out-ObjectTable `
    -Objects ($SlnProjectEntries | Select-Object SolutionName, ProjectName, RelativePath, Exists, IsExcluded) `
    -Properties @("SolutionName", "ProjectName", "RelativePath", "Exists", "IsExcluded")

# =========================
# 6) CSPROJ DETAILS
# =========================

Write-Section "Project files and ProjectReferences"

$ProjectInfos = @()

foreach ($csproj in $ActiveCandidateCsprojFiles) {
    try {
        $ProjectInfos += Parse-CsprojInfo -ProjectPath $csproj.FullName
    }
    catch {
        Out-Text "Failed to parse csproj: $($csproj.FullName)"
        Out-Text "Error: $($_.Exception.Message)"
    }
}

Out-Text "`n[Active candidate csproj files]"
Out-ObjectTable `
    -Objects ($ProjectInfos | Select-Object ProjectFileName, RelativePath, TargetFramework, OutputType, UseWPF) `
    -Properties @("ProjectFileName", "RelativePath", "TargetFramework", "OutputType", "UseWPF")

Out-Text "`n[ProjectReference graph]"

$ReferenceRows = @()

foreach ($p in $ProjectInfos) {
    if ($p.References.Count -eq 0) {
        $ReferenceRows += [PSCustomObject]@{
            Project        = $p.RelativePath
            Reference      = "[No ProjectReference]"
            Resolved       = ""
            Exists         = ""
            ReferenceState = ""
        }
    }
    else {
        foreach ($r in $p.References) {
            $ReferenceRows += [PSCustomObject]@{
                Project        = $p.RelativePath
                Reference      = $r.Include
                Resolved       = Get-RelativePathSafe -BasePath $Root -FullPath $r.ResolvedPath
                Exists         = $r.Exists
                ReferenceState = if ($r.IsExcluded) { "Excluded/Legacy/Generated" } else { "ActiveCandidate" }
            }
        }
    }
}

Out-ObjectTable `
    -Objects $ReferenceRows `
    -Properties @("Project", "Reference", "Resolved", "Exists", "ReferenceState")

# =========================
# 7) DUPLICATE PROJECT NAMES
# =========================

Write-Section "Duplicate project names"

$DuplicateGroups = $ActiveCandidateCsprojFiles |
    Group-Object Name |
    Where-Object { $_.Count -gt 1 } |
    Sort-Object Name

$DuplicateRows = @()

foreach ($group in $DuplicateGroups) {
    foreach ($item in $group.Group) {
        $DuplicateRows += [PSCustomObject]@{
            ProjectFileName = $group.Name
            Count           = $group.Count
            FullPath        = $item.FullName
            RelativePath    = Get-RelativePathSafe -BasePath $Root -FullPath $item.FullName
        }
    }
}

Out-ObjectTable `
    -Objects $DuplicateRows `
    -Properties @("ProjectFileName", "Count", "RelativePath")

# =========================
# 8) WPF CANDIDATES
# =========================

Write-Section "WPF candidates"

$WpfCandidates = $ProjectInfos | Where-Object {
    $_.UseWPF -match 'true' -or
    $_.TargetFramework -match 'windows' -or
    $_.ProjectFileName -match 'Wpf'
}

Out-ObjectTable `
    -Objects ($WpfCandidates | Select-Object ProjectFileName, RelativePath, TargetFramework, OutputType, UseWPF) `
    -Properties @("ProjectFileName", "RelativePath", "TargetFramework", "OutputType", "UseWPF")

$MixedWpfReferenceRows = @()

foreach ($wpf in $WpfCandidates) {
    $refs = $wpf.References

    $hasOldApplication = $refs | Where-Object { $_.ResolvedPath -match '\\src\\Application\\MyCompanyApp\.Application\.csproj$' }
    $hasNewApplication = $refs | Where-Object { $_.ResolvedPath -match '\\src\\MyCompanyApp\.Application\\MyCompanyApp\.Application\.csproj$' }

    $hasOldDomain = $refs | Where-Object { $_.ResolvedPath -match '\\src\\Domain\\MyCompanyApp\.Domain\.csproj$' }
    $hasNewDomain = $refs | Where-Object { $_.ResolvedPath -match '\\src\\MyCompanyApp\.Domain\\MyCompanyApp\.Domain\.csproj$' }

    $hasOldInfrastructure = $refs | Where-Object { $_.ResolvedPath -match '\\src\\Infrastructure\\MyCompanyApp\.Infrastructure\.csproj$' }
    $hasNewInfrastructure = $refs | Where-Object { $_.ResolvedPath -match '\\src\\MyCompanyApp\.Infrastructure\\MyCompanyApp\.Infrastructure\.csproj$' }

    $mixed = (
        ($hasOldApplication -and $hasNewApplication) -or
        ($hasOldDomain -and $hasNewDomain) -or
        ($hasOldInfrastructure -and $hasNewInfrastructure)
    )

    $MixedWpfReferenceRows += [PSCustomObject]@{
        WpfProject              = $wpf.RelativePath
        HasOldApplication       = [bool]$hasOldApplication
        HasNewApplication       = [bool]$hasNewApplication
        HasOldDomain            = [bool]$hasOldDomain
        HasNewDomain            = [bool]$hasNewDomain
        HasOldInfrastructure    = [bool]$hasOldInfrastructure
        HasNewInfrastructure    = [bool]$hasNewInfrastructure
        HasMixedDuplicateRefs   = [bool]$mixed
    }
}

Out-Text "`n[WPF mixed duplicate reference analysis]"
Out-ObjectTable `
    -Objects $MixedWpfReferenceRows `
    -Properties @(
        "WpfProject",
        "HasOldApplication",
        "HasNewApplication",
        "HasOldDomain",
        "HasNewDomain",
        "HasOldInfrastructure",
        "HasNewInfrastructure",
        "HasMixedDuplicateRefs"
    )

# =========================
# 9) BACKUP / LEGACY / GENERATED
# =========================

Write-Section "Backup / legacy / generated inventory"

$BackupLikeDirectories = Get-ChildItem -LiteralPath $Root -Recurse -Directory |
    Where-Object {
        $_.FullName -match '\\(legacy|backups|_backups|_backup_[^\\]*|backup-before-[^\\]*|WPF_Cleanup_Backup_[^\\]*|_code_backup_[^\\]*)(\\|$)'
    } |
    Sort-Object FullName

$BackupLikeFiles = Get-ChildItem -LiteralPath $Root -Recurse -File |
    Where-Object { Test-IsBackupFile $_.FullName } |
    Sort-Object FullName

Out-Text "`n[Backup/legacy-like directories]"
Out-ObjectTable `
    -Objects ($BackupLikeDirectories | Select-Object Name, FullName) `
    -Properties @("Name", "FullName")

Out-Text "`n[Backup-like files]"
Out-ObjectTable `
    -Objects ($BackupLikeFiles | Select-Object Name, FullName) `
    -Properties @("Name", "FullName")

# =========================
# 10) HEURISTIC ACTIVE TREE DECISION
# =========================

Write-Section "Heuristic active tree decision"

$IncludedProjectFullPaths = $SlnProjectEntries |
    Where-Object { $_.Exists -eq $true -and $_.IsExcluded -eq $false } |
    ForEach-Object { [System.IO.Path]::GetFullPath($_.FullPath) } |
    Select-Object -Unique

$HeuristicRows = @()

foreach ($p in $ProjectInfos) {
    $full = [System.IO.Path]::GetFullPath($p.ProjectPath)

    $isIncludedInSln = $IncludedProjectFullPaths -contains $full
    $isReferencedByAny = $false

    foreach ($other in $ProjectInfos) {
        foreach ($r in $other.References) {
            if ([System.IO.Path]::GetFullPath($r.ResolvedPath) -eq $full) {
                $isReferencedByAny = $true
            }
        }
    }

    $treeType = "Unknown"

    if ($p.RelativePath -match '^src\\MyCompanyApp\.') {
        $treeType = "NewNamedTree"
    }
    elseif ($p.RelativePath -match '^src\\(Application|Domain|Infrastructure)\\') {
        $treeType = "OldShortTree"
    }
    elseif ($p.RelativePath -match '^src\\Wpf\\') {
        $treeType = "WpfShortTree"
    }
    elseif ($p.RelativePath -match '^src\\MyCompanyApp\.Wpf\\') {
        $treeType = "WpfNamedTree"
    }
    elseif ($p.RelativePath -match '^tests\\') {
        $treeType = "Tests"
    }
    elseif ($p.RelativePath -match '^TestProject\\') {
        $treeType = "ScratchTestProject"
    }

    $score = 0
    if ($isIncludedInSln) { $score += 5 }
    if ($isReferencedByAny) { $score += 3 }
    if ($treeType -eq "NewNamedTree") { $score += 2 }
    if ($treeType -eq "WpfShortTree") { $score += 2 }
    if ($treeType -eq "OldShortTree") { $score += 1 }
    if ($treeType -eq "ScratchTestProject") { $score -= 3 }

    $HeuristicRows += [PSCustomObject]@{
        Project         = $p.RelativePath
        TreeType        = $treeType
        InSolution      = $isIncludedInSln
        ReferencedByAny = $isReferencedByAny
        Score           = $score
    }
}

Out-ObjectTable `
    -Objects ($HeuristicRows | Sort-Object @{ Expression = "Score"; Descending = $true }, @{ Expression = "Project"; Descending = $false }) `
    -Properties @("Project", "TreeType", "InSolution", "ReferencedByAny", "Score")

# =========================
# 11) FINAL RECOMMENDATIONS
# =========================

Write-Section "Recommended next actions"

Out-Text @"
Recommended interpretation rules:

1. If a project appears in the active .sln and is referenced by WPF, it is active.
2. If duplicate project names exist, do NOT delete either side until WPF references are normalized.
3. If WPF references both:
   - src\Application and src\MyCompanyApp.Application
   - src\Domain and src\MyCompanyApp.Domain
   - src\Infrastructure and src\MyCompanyApp.Infrastructure
   then WPF is currently in mixed/unsafe state.
4. backup-before-*, WPF_Cleanup_Backup_*, legacy, backups, _backups, bin, obj, artifacts are not source-of-truth.
5. After references are normalized, run:
   dotnet clean
   dotnet restore
   dotnet build
   dotnet test
"@

# =========================
# 12) EXPORT JSON
# =========================

$ExportObject = [PSCustomObject]@{
    Root                   = $Root
    GeneratedAt            = Get-Date
    Solutions              = $AllSlnFiles.FullName
    SolutionProjectEntries = $SlnProjectEntries
    Projects               = $ProjectInfos
    DuplicateProjects      = $DuplicateRows
    WpfCandidates          = $WpfCandidates
    WpfMixedReferences     = $MixedWpfReferenceRows
    HeuristicDecision      = $HeuristicRows
    BackupDirectories      = $BackupLikeDirectories.FullName
    BackupFiles            = $BackupLikeFiles.FullName
}

$ExportObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8

Write-Section "Done"

Write-Host ""
Write-Host "Text report:" -ForegroundColor Green
Write-Host $ReportPath

Write-Host ""
Write-Host "JSON report:" -ForegroundColor Green
Write-Host $JsonPath

Write-Host ""
Write-Host "Analysis completed." -ForegroundColor Green


