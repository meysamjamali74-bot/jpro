#requires -RunAsAdministrator
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$DesktopExe,
  [string]$DefaultServerUrl='http://127.0.0.1:8080'
)
$ErrorActionPreference='Stop'
if(!(Test-Path $DesktopExe)){throw "Tarazpad desktop executable not found: $DesktopExe"}

$programData=[Environment]::GetFolderPath('CommonApplicationData')
$clientDir=Join-Path $programData 'Tarazpad\client'
$configPath=Join-Path $clientDir 'client.json'
New-Item $clientDir -ItemType Directory -Force | Out-Null
if(!(Test-Path $configPath)){
  [ordered]@{ServerUrl=$DefaultServerUrl;RememberServer=$true} | ConvertTo-Json | Set-Content $configPath -Encoding utf8
}

$desktop=[Environment]::GetFolderPath('CommonDesktopDirectory')
$startMenu=Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Tarazpad'
New-Item $startMenu -ItemType Directory -Force | Out-Null
$shell=New-Object -ComObject WScript.Shell
foreach($path in @((Join-Path $desktop 'Tarazpad ERP.lnk'),(Join-Path $startMenu 'Tarazpad ERP.lnk'))){
  if(Test-Path $path){Remove-Item $path -Force}
  $shortcut=$shell.CreateShortcut($path)
  $shortcut.TargetPath=$DesktopExe
  $shortcut.WorkingDirectory=Split-Path -Parent $DesktopExe
  $shortcut.Description='Tarazpad ERP Native Windows Client'
  $shortcut.Save()
}
Write-Host "[OK] Native Tarazpad shortcuts target $DesktopExe" -ForegroundColor Green
