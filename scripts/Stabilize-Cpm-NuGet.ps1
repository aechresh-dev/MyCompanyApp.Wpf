param(
    [string]$Root = (Get-Location).Path,
    [switch]$SkipRestore,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Log($m){Write-Host "[INFO] $m" -ForegroundColor Cyan}
function Ok($m){Write-Host "[OK] $m" -ForegroundColor Green}
function Warn($m){Write-Host "[WARN] $m" -ForegroundColor Yellow}

function BackupFile($path){
    if(Test-Path $path){
        $t=Get-Date -Format "yyyyMMddHHmmss"
        Copy-Item $path "$path.bak.$t"
    }
}

function GetPackages(){
    $p=@{}
    # Base Frameworks
    $p["CommunityToolkit.Mvvm"]="8.4.2"
    $p["Microsoft.Extensions.Hosting"]="8.0.1"
    $p["Microsoft.Extensions.Configuration"]="8.0.0"
    $p["Microsoft.Extensions.Configuration.Json"]="8.0.1"
    $p["Microsoft.Extensions.DependencyInjection"]="8.0.1"
    $p["Microsoft.Extensions.DependencyInjection.Abstractions"]="8.0.1"
    $p["Microsoft.Extensions.Logging"]="8.0.1"
    $p["Microsoft.Extensions.Logging.Console"]="8.0.1"

    # EF Core
    $p["Microsoft.EntityFrameworkCore"]="8.0.11"
    $p["Microsoft.EntityFrameworkCore.SqlServer"]="8.0.11"
    $p["Microsoft.EntityFrameworkCore.Sqlite"]="8.0.11"
    $p["Microsoft.EntityFrameworkCore.Tools"]="8.0.11"
    $p["Microsoft.EntityFrameworkCore.Design"]="8.0.11"

    # Utils
    $p["Serilog"]="4.3.0"
    $p["Serilog.Extensions.Logging"]="8.0.0"
    $p["Serilog.Sinks.Console"]="6.0.0"
    $p["Serilog.Sinks.File"]="6.0.0"
    $p["ClosedXML"]="0.105.0"
    $p["DocumentFormat.OpenXml"]="3.2.0"
    $p["QuestPDF"]="2026.6.0"

    # Testing
    $p["Microsoft.NET.Test.Sdk"]="18.0.0"
    $p["xunit"]="2.9.3"
    $p["xunit.runner.visualstudio"]="3.1.5"
    $p["coverlet.collector"]="6.0.4"
    $p["Moq"]="4.20.72"
    $p["FluentAssertions"]="8.10.0"

    return $p
}

function EnsureDirectoryPackages($root,$packages){
    $file=Join-Path $root "Directory.Packages.props"
    BackupFile $file
    $xml=@"<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>
  </PropertyGroup>
  <ItemGroup>
"@
    foreach($k in $packages.Keys){
        $v=$packages[$k]
        $xml+="    <PackageVersion Include=`"$k`" Version=`"$v`" />`n"
    }
    $xml+="  </ItemGroup>
</Project>"
    $xml | Out-File $file -Encoding utf8
    Ok "Directory.Packages.props created"
}

function EnsureNugetConfig($root){
    $file=Join-Path $root "NuGet.config"
    BackupFile $file
    $content=@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear/>
    <add key="nuget" value="https://api.nuget.org/v3/index.json"/>
  </packageSources>
</configuration>
"@
    $content | Out-File $file -Encoding utf8
    Ok "NuGet.config simplified"
}

function NormalizeCsproj($file){
    try{ [xml]$xml=Get-Content $file -Raw }catch{ return }
    $refs=$xml.SelectNodes("//PackageReference")
    $changed=$false
    foreach($r in $refs){
        if($r.HasAttribute("Version")){ $r.RemoveAttribute("Version"); $changed=$true }
        $v=$r.SelectSingleNode("Version")
        if($v){ $r.RemoveChild($v)|Out-Null; $changed=$true }
    }
    if($changed){ $xml.Save($file); Ok "normalized $file" }
}

# Execution
EnsureDirectoryPackages $Root (GetPackages)
EnsureNugetConfig $Root

$files=Get-ChildItem -Path $Root -Recurse -Filter *.csproj -File | Where-Object{$_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\"}
foreach($f in $files){ NormalizeCsproj $f.FullName }

$sln=(Get-ChildItem -Path $Root -Filter *.sln -File)[0].FullName
& dotnet restore $sln
& dotnet build $sln --no-restore
Ok "Completed successfully"
