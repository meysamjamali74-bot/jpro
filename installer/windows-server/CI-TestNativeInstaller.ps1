$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Stage=(Resolve-Path (Join-Path $PSScriptRoot 'build\staging')).Path
$Exe=(Resolve-Path (Join-Path $PSScriptRoot 'build\Tarazpad-ERP-Enterprise-Setup-1.8.0.exe')).Path
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
$credPath=Join-Path $InstallRoot 'INITIAL-LOGIN.txt'
if(!(Test-Path $credPath)){throw 'Initial credentials file missing.'}
$credAcl=Get-Acl $credPath
if(-not $credAcl.AreAccessRulesProtected){throw 'Initial credentials file still inherits permissions.'}
$unexpected=$credAcl.Access|Where-Object{$_.AccessControlType -eq 'Allow' -and $_.IdentityReference.Value -notmatch '(?i)(SYSTEM|Administrators)$'}
if($unexpected){throw 'Initial credentials file grants access outside SYSTEM/Administrators.'}
if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Server' -ErrorAction SilentlyContinue)){throw 'Tarazpad startup task missing.'}
if(!(Get-ScheduledTask -TaskName 'Tarazpad ERP Daily Backup' -ErrorAction SilentlyContinue)){throw 'Tarazpad backup task missing.'}

Write-Host '[CI] Running packaged Enterprise Setup.exe over existing installation...'
$p=Start-Process $Exe -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){throw "Setup EXE idempotency run failed: $($p.ExitCode)"}
$after=Get-Content $cfgPath -Raw | ConvertFrom-Json
if($before.installedAt -ne $after.installedAt){throw 'Idempotency failure: installedAt changed.'}
if($before.mysqlPassword -ne $after.mysqlPassword){throw 'Idempotency failure: MySQL application password changed.'}
if($before.jwtSecret -ne $after.jwtSecret){throw 'Idempotency failure: JWT secret changed.'}

$health2=Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -TimeoutSec 10
if(!$health2.ok){throw 'Health check failed after Setup.exe second run.'}

Write-Host '[CI] Verifying HARD_CLOSED database guards installed by packaged Setup...'
$env:MYSQL_PWD=$after.mysqlPassword
$triggerCount=& $after.mysqlExe --protocol=tcp --host=$after.mysqlHost --port=$after.mysqlPort --user=$after.mysqlUser --database=$after.mysqlDatabase --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME IN ('trg_journal_line_hard_close_insert','trg_journal_line_hard_close_update','trg_journal_line_hard_close_delete');"
$mysqlExit=$LASTEXITCODE
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
if($mysqlExit -ne 0){throw "Database guard verification query failed: $mysqlExit"}
if([int]($triggerCount|Select-Object -Last 1) -lt 3){throw "Expected HARD_CLOSED journal triggers were not all installed. Found: $triggerCount"}

Write-Host "[CI] PASS - Enterprise 1.8 installer; MySQL $($after.mysqlVersion) source=$($after.mysqlSource); config/secrets preserved; DB guards verified."
