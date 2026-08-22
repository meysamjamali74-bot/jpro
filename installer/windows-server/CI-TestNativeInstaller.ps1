$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Stage=(Resolve-Path (Join-Path $PSScriptRoot 'build\staging')).Path
$Exe=(Resolve-Path (Join-Path $PSScriptRoot 'build\Tarazpad-ERP-Web-Server-Setup-0.2.0.exe')).Path
$InstallRoot='C:\ProgramData\Tarazpad\server'

Write-Host '[CI] Reserving port 8080 to verify dynamic web-port fallback...'
$portBlocker=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,8080)
$portBlocker.Start()

try{
  Write-Host '[CI] Preparing direct native-install test root...'
  New-Item $InstallRoot -ItemType Directory -Force | Out-Null
  Copy-Item (Join-Path $Stage '*') $InstallRoot -Recurse -Force

  Write-Host '[CI] Running configuration script directly so failures are visible...'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'Install-TarazpadServer.ps1')
  if($LASTEXITCODE -ne 0){ throw "Direct native configuration failed: $LASTEXITCODE" }

  $cfgPath=Join-Path $InstallRoot 'config\server.json'
  if(!(Test-Path $cfgPath)){throw 'Server config missing.'}
  $before=Get-Content $cfgPath -Raw | ConvertFrom-Json
  if([int]$before.webPort -eq 8080){throw 'Dynamic web-port fallback failed: installer selected occupied port 8080.'}

  Write-Host "[CI] Verifying web health on selected port $($before.webPort)..."
  $health=$null
  for($i=0;$i -lt 90;$i++){
    try{$health=Invoke-RestMethod "http://127.0.0.1:$($before.webPort)/api/health" -TimeoutSec 2;if($health.ok){break}}catch{}
    Start-Sleep 1
  }
  if(!$health -or !$health.ok){ throw 'Tarazpad health check failed after direct native configuration.' }

  $svc=Get-Service 'TarazpadMySQL' -ErrorAction Stop
  if($svc.Status -ne 'Running'){throw 'TarazpadMySQL service is not running.'}
  if(!(Test-Path (Join-Path $InstallRoot 'INITIAL-LOGIN.txt'))){throw 'Initial credentials file missing.'}
  if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Server' -ErrorAction SilentlyContinue)){throw 'Tarazpad startup task missing.'}
  if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Daily Backup' -ErrorAction SilentlyContinue)){throw 'Tarazpad backup task missing.'}
} finally {
  if($portBlocker){$portBlocker.Stop()}
}

Write-Host '[CI] Breaking the app DB credential intentionally to verify safe recovery...'
$env:MYSQL_PWD=$before.mysqlRootPassword
$breakSql="ALTER USER 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY 'CI_BROKEN_CREDENTIAL_8xQ7!'; FLUSH PRIVILEGES;"
& $before.mysqlExe --protocol=tcp --host=127.0.0.1 --port=$($before.mysqlPort) --user=root --execute=$breakSql 2>$null
$breakExit=$LASTEXITCODE
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
if($breakExit -ne 0){throw "Unable to create credential-recovery test condition: $breakExit"}

Write-Host '[CI] Running packaged Setup.exe over the damaged existing installation...'
$p=Start-Process $Exe -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){throw "Setup EXE recovery/idempotency run failed: $($p.ExitCode)"}
$after=Get-Content $cfgPath -Raw | ConvertFrom-Json
if($before.installedAt -ne $after.installedAt){throw 'Idempotency failure: installedAt changed.'}
if($before.jwtSecret -ne $after.jwtSecret){throw 'Idempotency failure: JWT secret changed.'}
if($before.mysqlPassword -eq $after.mysqlPassword){throw 'Credential recovery failure: damaged application password was not rotated.'}
if([int]$before.webPort -ne [int]$after.webPort){throw 'Idempotency failure: selected web port changed on healthy reinstall.'}

$health2=Invoke-RestMethod "http://127.0.0.1:$($after.webPort)/api/health" -TimeoutSec 10
if(!$health2.ok){throw 'Health check failed after credential-recovery Setup.exe run.'}

Write-Host '[CI] Verifying backup script returns a valid non-empty archive...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'Backup-Tarazpad.ps1')
if($LASTEXITCODE -ne 0){throw "Backup script failed: $LASTEXITCODE"}
$latestBackup=Get-ChildItem (Join-Path $InstallRoot 'backups') -Filter 'tarazpad-*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if(!$latestBackup -or $latestBackup.Length -lt 128){throw 'Backup validation failed: no valid non-empty ZIP produced.'}

Write-Host "[CI] PASS - dynamic web port=$($after.webPort); MySQL $($after.mysqlVersion) source=$($after.mysqlSource); damaged DB credential recovered; existing configuration preserved."
