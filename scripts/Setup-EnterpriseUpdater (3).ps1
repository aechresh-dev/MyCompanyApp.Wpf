param(
[string]$DatabaseName="mycompanyapp_hr.db",
[switch]$CreateRawDatabaseIfNothingFound
)

$Root=if($PSScriptRoot){$PSScriptRoot}else{(Get-Location).Path}

$DataDir="$Root\data"
$BackupDir="$Root\backups"
$QuarantineDir="$Root\quarantine"

$DbPath="$DataDir\$DatabaseName"
$Schema="$DataDir\schema_hr_persian.sql"

function Get-Sqlite{

$local="$Root\sqlite3.exe"

if(Test-Path $local){
return $local
}

$cmd=Get-Command sqlite3 -ErrorAction SilentlyContinue

if($cmd){
return $cmd.Source
}

throw "sqlite3 not found"
}

function Test-Db{

param($db)

$sqlite=Get-Sqlite

$result=& $sqlite $db "PRAGMA integrity_check;" 2>&1

return ($result -eq "ok")

}

function Create-Db{

$sqlite=Get-Sqlite

& $sqlite $DbPath ".read `"$Schema`""

}

function Backup-Db{

if(Test-Path $DbPath){

$stamp=Get-Date -Format "yyyyMMdd-HHmmss"

Copy-Item $DbPath "$BackupDir\backup-$stamp.db"

}

}

function Quarantine{

if(Test-Path $DbPath){

$stamp=Get-Date -Format "yyyyMMdd-HHmmss"

Move-Item $DbPath "$QuarantineDir\db-$stamp.quarantine"

}

}

Write-Host ""
Write-Host "Database Guardian Starting..."
Write-Host ""

if(Test-Path $DbPath){

if(Test-Db $DbPath){

Write-Host "Database healthy."
exit

}else{

Write-Host "Database corrupt -> quarantine"

Quarantine

}

}

$backup=Get-ChildItem $BackupDir -Filter *.db -ErrorAction SilentlyContinue | Sort LastWriteTime -Descending | Select -First 1

if($backup){

Copy-Item $backup.FullName $DbPath

Write-Host "Restored from backup."

exit

}

if($CreateRawDatabaseIfNothingFound){

Write-Host "Creating raw database..."

Create-Db

exit

}

Write-Host "No database recovered."
