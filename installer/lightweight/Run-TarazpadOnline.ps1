#requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$task='Tarazpad ERP Server'
$installer=Join-Path $PSScriptRoot 'Install-TarazpadOnline.ps1'
if(!(Test-Path $installer)){throw 'Tarazpad installer script is missing.'}

$serverRoot='C:\ProgramData\Tarazpad\server'
$cacheRoot=Join-Path $serverRoot 'cache'
$mysqlZip=Join-Path $cacheRoot 'mysql-8.4.11-winx64.zip'
$mirrorUrl='https://github.com/meysamjamali74-bot/jpro/releases/download/tarazpad-mysql-8.4.11/mysql-8.4.11-winx64.zip'
$cdnUrl='https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip'
$devUrl='https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip'
New-Item $cacheRoot -ItemType Directory -Force | Out-Null

function Test-MySql84Installed {
  $candidates=New-Object System.Collections.Generic.List[string]
  $cmd=Get-Command mysql.exe -ErrorAction SilentlyContinue
  if($cmd){[void]$candidates.Add($cmd.Source)}
  foreach($p in @(
    'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe',
    'C:\mysql\bin\mysql.exe',
    'C:\mysql-8.4\bin\mysql.exe',
    'C:\ProgramData\Tarazpad\server\runtime\mysql\bin\mysql.exe'
  )){if(Test-Path $p){[void]$candidates.Add($p)}}
  foreach($p in ($candidates|Select-Object -Unique)){
    try{if((& $p --version 2>$null) -match 'Ver\s+8\.4\.'){return $true}}catch{}
  }
  return $false
}

function Test-MySqlZip([string]$path){
  if(!(Test-Path $path)){return $false}
  try{
    if((Get-Item $path).Length -lt 100000000){return $false}
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $z=[System.IO.Compression.ZipFile]::OpenRead($path)
    try{
      $entry=$z.Entries | Where-Object { $_.FullName -eq 'mysql-8.4.11-winx64/bin/mysqld.exe' } | Select-Object -First 1
      return $null -ne $entry
    } finally {$z.Dispose()}
  }catch{return $false}
}

function Try-Download([string]$url,[string]$target){
  $tmp="$target.part"
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  try{
    Write-Host "[TARAZPAD] Trying MySQL source: $url" -ForegroundColor Cyan
    $curl=Get-Command curl.exe -ErrorAction SilentlyContinue
    if($curl){
      & $curl.Source -L --fail --retry 2 --retry-delay 2 --connect-timeout 30 -A 'Tarazpad-ERP-Installer/0.3.1' -o $tmp $url
      if($LASTEXITCODE -ne 0){throw "curl exit $LASTEXITCODE"}
    }else{
      Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 900
    }
    if(!(Test-MySqlZip $tmp)){throw 'Downloaded MySQL archive failed validation.'}
    Move-Item $tmp $target -Force
    Write-Host '[OK] MySQL runtime download validated and cached.' -ForegroundColor Green
    return $true
  }catch{
    Write-Warning "MySQL source failed: $($_.Exception.Message)"
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return $false
  }
}

# Pre-seed the MySQL cache only when a compatible MySQL is not already present.
# This bypasses Oracle CDN blocks by preferring the verified Tarazpad GitHub release mirror.
if(!(Test-MySql84Installed)){
  if(Test-MySqlZip $mysqlZip){
    Write-Host '[OK] Valid cached MySQL 8.4.11 archive found; download skipped.' -ForegroundColor Green
  }else{
    Remove-Item $mysqlZip -Force -ErrorAction SilentlyContinue
    $sources=@($mirrorUrl)
    if($env:TARAZPAD_MYSQL_MIRROR_ONLY -ne '1'){$sources+=@($cdnUrl,$devUrl)}
    $ok=$false
    foreach($url in $sources){if(Try-Download $url $mysqlZip){$ok=$true;break}}
    if(!$ok){
      throw "Unable to download MySQL 8.4.11 from all configured sources. Put mysql-8.4.11-winx64.zip in $cacheRoot and run Setup again."
    }
  }
}else{
  Write-Host '[OK] Compatible MySQL 8.4 already installed; MySQL download skipped.' -ForegroundColor Green
}

# The main installer stops the existing Tarazpad startup task before replacing app files.
# On a clean machine, create and start a harmless temporary task so that this stop operation is idempotent.
$exists=$false
try{& schtasks.exe /Query /TN $task 1>$null 2>$null;if($LASTEXITCODE -eq 0){$exists=$true}}catch{}
if(!$exists){
  $bootstrap='C:\ProgramData\Tarazpad\bootstrap'
  New-Item $bootstrap -ItemType Directory -Force|Out-Null
  $dummy=Join-Path $bootstrap 'dummy.cmd'
  '@echo off' | Set-Content $dummy -Encoding ascii
  'ping.exe -t 127.0.0.1 >nul' | Add-Content $dummy -Encoding ascii
  try{
    & schtasks.exe /Create /TN $task /SC ONCE /ST 23:59 /RU SYSTEM /RL HIGHEST /TR $dummy /F 1>$null 2>$null
    if($LASTEXITCODE -eq 0){& schtasks.exe /Run /TN $task 1>$null 2>$null;Start-Sleep 1}
  }catch{}
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
exit $LASTEXITCODE
