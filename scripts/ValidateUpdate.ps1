param(
    [Parameter(Mandatory=$true)]
    [string]$Package
)

$ErrorActionPreference="Stop"

$temp = Join-Path $env:TEMP "UpdateCheck"

try{

    if(!(Test-Path $Package)){
        Write-Output "INVALID"
        exit
    }

    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

    Expand-Archive $Package -DestinationPath $temp -Force

    $manifest = Join-Path $temp "manifest.json"
    $checksums = Join-Path $temp "checksums.sha256"

    if(!(Test-Path $manifest) -or !(Test-Path $checksums)){
        Write-Output "INVALID"
        exit
    }

    $lines = Get-Content $checksums

    foreach($line in $lines){

        $parts = $line.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)

        $expectedHash = $parts[0]
        $file = Join-Path $temp $parts[1]

        if(!(Test-Path $file)){
            Write-Output "INVALID"
            exit
        }

        $actual = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()

        if($actual -ne $expectedHash){
            Write-Output "INVALID"
            exit
        }
    }

    Remove-Item $temp -Recurse -Force

    Write-Output "VALID"
}
catch{

    Write-Output "INVALID"
}
