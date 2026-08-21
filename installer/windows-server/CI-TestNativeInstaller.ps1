$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Stage=(Resolve-Path (Join-Path $PSScriptRoot 'build\staging')).Path
$Exe=(Resolve-Path (Join-Path $PSScriptRoot 'build\Tarazpad-ERP-Web-Server-Setup-0.2.1.exe')).Path
$InstallRoot='C:\ProgramData\Tarazpad\server'

Write-Host '[CI] Preparing direct native-install test root...'
New-Item $InstallRoot -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $Stage '*') $InstallRoot -Recurse -Force

# Force the installer to prove it can survive the most common local port collision.
$portBlocker=$null
$forcedCollision=$false
try {
  $portBlocker=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,8080)
  $portBlocker.Start()
  $forcedCollision=$true
  Write-Host '[CI] Port 8080 intentionally occupied to test automatic web-port fallback.'
} catch {
  Write-Host '[CI] Port 8080 was already occupied; collision scenario already exists.'
}

Write-Host '[CI] Running configuration script directly so failures are visible...'
try {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'Install-TarazpadServer.ps1')
  if($LASTEXITCODE -ne 0){ throw "Direct native configuration failed: $LASTEXITCODE" }
} finally {
  if($portBlocker){$portBlocker.Stop()}
}

$cfgPath=Join-Path $InstallRoot 'config\server.json'
if(!(Test-Path $cfgPath)){throw 'Server config missing.'}
$before=Get-Content $cfgPath -Raw | ConvertFrom-Json
$webPort=[int]$before.webPort
if($webPort -lt 1 -or $webPort -gt 65535){throw "Invalid persisted web port: $webPort"}
if($forcedCollision -and $webPort -eq 8080){throw 'Port-collision fallback failed: installer persisted occupied port 8080.'}

Write-Host "[CI] Verifying web health on persisted port $webPort..."
$health=$null
for($i=0;$i -lt 90;$i++){
  try{$health=Invoke-RestMethod "http://127.0.0.1:$webPort/api/health" -TimeoutSec 2;if($health.ok){break}}catch{}
  Start-Sleep 1
}
if(!$health -or !$health.ok){ throw "Tarazpad health check failed on port $webPort after direct native configuration." }

$svc=Get-Service 'TarazpadMySQL' -ErrorAction Stop
if($svc.Status -ne 'Running'){throw 'TarazpadMySQL service is not running.'}
$credPath=Join-Path $InstallRoot 'INITIAL-LOGIN.txt'
if(!(Test-Path $credPath)){throw 'Initial credentials file missing.'}
$credAcl=Get-Acl $credPath
if(-not $credAcl.AreAccessRulesProtected){throw 'Initial credentials ACL still inherits permissions.'}
$unexpected=$credAcl.Access | Where-Object {
  $_.AccessControlType -eq 'Allow' -and
  $_.IdentityReference.Value -notmatch '(?i)(SYSTEM|Administrators)$'
}
if($unexpected){throw 'Initial credentials file grants access outside SYSTEM/Administrators.'}
if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Server' -ErrorAction SilentlyContinue)){throw 'Tarazpad startup task missing.'}
if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Daily Backup' -ErrorAction SilentlyContinue)){throw 'Tarazpad backup task missing.'}

Write-Host '[CI] Running packaged Setup.exe over existing installation...'
$p=Start-Process $Exe -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){throw "Setup EXE idempotency run failed: $($p.ExitCode)"}
$after=Get-Content $cfgPath -Raw | ConvertFrom-Json
if($before.installedAt -ne $after.installedAt){throw 'Idempotency failure: installedAt changed.'}
if($before.mysqlPassword -ne $after.mysqlPassword){throw 'Idempotency failure: MySQL application password changed.'}
if($before.jwtSecret -ne $after.jwtSecret){throw 'Idempotency failure: JWT secret changed.'}
if([int]$before.webPort -ne [int]$after.webPort){throw 'Idempotency failure: persisted web port changed.'}

$health2=Invoke-RestMethod "http://127.0.0.1:$($after.webPort)/api/health" -TimeoutSec 10
if(!$health2.ok){throw 'Health check failed after Setup.exe second run.'}
Write-Host "[CI] PASS - web=$($after.webPort); MySQL $($after.mysqlVersion) source=$($after.mysqlSource); existing configuration preserved."
