param(
    [string]$RootPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf"
)

$ErrorActionPreference = "Stop"

function Section($t){
    Write-Host ""
    Write-Host ("="*80) -ForegroundColor DarkGray
    Write-Host $t -ForegroundColor Cyan
    Write-Host ("="*80) -ForegroundColor DarkGray
}

function Info($t){ Write-Host "[INFO] $t" -ForegroundColor Green }
function Warn($t){ Write-Host "[WARN] $t" -ForegroundColor Yellow }

function Get-CsprojInfo {

    param($Path)

    if(!(Test-Path $Path)){ return }

    [xml]$xml = Get-Content $Path -Raw

    $props = $xml.Project.PropertyGroup

    $result = [ordered]@{
        Csproj = $Path
        TargetFramework = $null
        Version = $null
        AssemblyVersion = $null
        FileVersion = $null
        InformationalVersion = $null
        OutputType = $null
    }

    foreach($p in $props){

        if($p.TargetFramework){$result.TargetFramework = $p.TargetFramework}
        if($p.Version){$result.Version = $p.Version}
        if($p.AssemblyVersion){$result.AssemblyVersion = $p.AssemblyVersion}
        if($p.FileVersion){$result.FileVersion = $p.FileVersion}
        if($p.InformationalVersion){$result.InformationalVersion = $p.InformationalVersion}
        if($p.OutputType){$result.OutputType = $p.OutputType}

    }

    return [pscustomobject]$result
}

Section "1) Detect solution"

$solution = Join-Path $RootPath "MyCompanyApp.sln"

if(Test-Path $solution){
    Info "Solution: $solution"
}

Section "2) Detect projects"

$wpf = Join-Path $RootPath "src\MyCompanyApp.Wpf\MyCompanyApp.Wpf.csproj"
$updater = Join-Path $RootPath "MyCompanyApp.Updater\MyCompanyApp.Updater.csproj"

Info "WPF: $wpf"
Info "Updater: $updater"

Section "3) csproj version info"

$wpfInfo = Get-CsprojInfo $wpf
$updInfo = Get-CsprojInfo $updater

$wpfInfo | Format-List
$updInfo | Format-List

Section "4) Find publish folders"

$publish = Get-ChildItem $RootPath -Recurse -Directory -Filter publish -ErrorAction SilentlyContinue

$publish | Select FullName,LastWriteTime | Sort LastWriteTime -Descending | Select -First 5

Section "5) Locate MyCompanyApp.Wpf.exe"

$exe = Get-ChildItem $RootPath -Recurse -Filter MyCompanyApp.Wpf.exe -ErrorAction SilentlyContinue | Sort LastWriteTime -Descending | Select -First 1

if($exe){

    Info "Executable found: $($exe.FullName)"

    $v = $exe.VersionInfo

    Write-Host ""
    Write-Host "VersionInfo:" -ForegroundColor Cyan
    Write-Host "ProductVersion : $($v.ProductVersion)"
    Write-Host "FileVersion    : $($v.FileVersion)"
    Write-Host "Company        : $($v.CompanyName)"
    Write-Host "Description    : $($v.FileDescription)"

}else{

    Warn "MyCompanyApp.Wpf.exe not found"

}

Section "Inspection finished"
