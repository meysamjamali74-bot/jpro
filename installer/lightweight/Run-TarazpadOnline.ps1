#requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$task='Tarazpad ERP Server'
$installer=Join-Path $PSScriptRoot 'Install-TarazpadOnline.ps1'
if(!(Test-Path $installer)){throw 'Tarazpad installer script is missing.'}

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
