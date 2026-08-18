$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Stage=(Resolve-Path (Join-Path $PSScriptRoot 'build\staging')).Path
$Exe=(Resolve-Path (Join-Path $PSScriptRoot 'build\Tarazpad-ERP-Web-Server-Setup-0.2.0.exe')).Path
$InstallRoot='C:\ProgramData\Tarazpad\server'

Write-Host '[CI] Preparing direct native-install test root...'
New-Item $InstallRoot -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $Stage '*') $InstallRoot -Recurse -Force

Write-Host '[CI] Running configuration script directly so failures are visible...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'Install-TarazpadServer.ps1')
if($LASTEXITCODE -ne 0){ throw "Direct native configuration failed: $LASTEXITCODE" }

Write-Host '[CI] Verifying web health...'
$health=$null
for($i=0;$i -lt 90;$i++){
  try{$health=Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -TimeoutSec 2;if($health.ok){break}}catch{}
  Start-Sleep 1
}
if(!$health -or !$health.ok){ throw 'Tarazpad health check failed after direct native configuration.' }

$cfgPath=Join-Path $InstallRoot 'config\server.json'
if(!(Test-Path $cfgPath)){throw 'Server config missing.'}
$before=Get-Content $cfgPath -Raw | ConvertFrom-Json
$svc=Get-Service 'TarazpadMySQL' -ErrorAction Stop
if($svc.Status -ne 'Running'){throw 'TarazpadMySQL service is not running.'}
if(!(Test-Path (Join-Path $InstallRoot 'INITIAL-LOGIN.txt'))){throw 'Initial credentials file missing.'}
if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Server' -ErrorAction SilentlyContinue)){throw 'Tarazpad startup task missing.'}
if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Daily Backup' -ErrorAction SilentlyContinue)){throw 'Tarazpad backup task missing.'}

Write-Host '[CI] Running packaged Setup.exe over existing installation...'
$p=Start-Process $Exe -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){throw "Setup EXE idempotency run failed: $($p.ExitCode)"}
$after=Get-Content $cfgPath -Raw | ConvertFrom-Json
if($before.installedAt -ne $after.installedAt){throw 'Idempotency failure: installedAt changed.'}
if($before.mysqlPassword -ne $after.mysqlPassword){throw 'Idempotency failure: MySQL application password changed.'}
if($before.jwtSecret -ne $after.jwtSecret){throw 'Idempotency failure: JWT secret changed.'}

$health2=Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -TimeoutSec 10
if(!$health2.ok){throw 'Health check failed after Setup.exe second run.'}
Write-Host "[CI] PASS - prerequisites/source: MySQL $($after.mysqlVersion) source=$($after.mysqlSource); existing configuration preserved."
