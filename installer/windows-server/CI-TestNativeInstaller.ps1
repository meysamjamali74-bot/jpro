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

# Run the exact root-only database guard stage directly once before invoking NSIS.
# This makes MySQL/PowerShell errors visible in the Actions log instead of reducing
# them to an opaque Setup.exe exit code. The packaged setup must still run the same
# stage again successfully, so idempotency remains fully tested.
Write-Host '[CI] Running database guard installation directly so failures are visible...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'Install-DatabaseGuards.ps1')
if($LASTEXITCODE -ne 0){ throw "Direct database guard installation failed: $LASTEXITCODE" }

Write-Host '[CI] Running packaged Enterprise Setup.exe over existing installation...'
$p=Start-Process $Exe -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){throw "Setup EXE idempotency run failed: $($p.ExitCode)"}
$after=Get-Content $cfgPath -Raw | ConvertFrom-Json
if($before.installedAt -ne $after.installedAt){throw 'Idempotency failure: installedAt changed.'}
if($before.mysqlPassword -ne $after.mysqlPassword){throw 'Idempotency failure: MySQL application password changed.'}
if($before.jwtSecret -ne $after.jwtSecret){throw 'Idempotency failure: JWT secret changed.'}

$health2=Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -TimeoutSec 10
if(!$health2.ok){throw 'Health check failed after Setup.exe second run.'}

Write-Host '[CI] Verifying authenticated OFFLINE_LAN runtime and customer-club workflow...'
$loginBody=@{email=[string]$after.adminEmail;password=[string]$after.adminPassword}|ConvertTo-Json
$login=Invoke-RestMethod 'http://127.0.0.1:8080/api/auth/login' -Method Post -ContentType 'application/json; charset=utf-8' -Body $loginBody -TimeoutSec 15
if([string]::IsNullOrWhiteSpace([string]$login.token)){throw 'Admin login failed after packaged setup.'}
$headers=@{Authorization="Bearer $($login.token)"}
$runtime=Invoke-RestMethod 'http://127.0.0.1:8080/api/system/runtime' -Headers $headers -TimeoutSec 10
if($runtime.mode -ne 'OFFLINE_LAN' -or $runtime.database -ne 'MySQL' -or $runtime.internetRequired -ne $false){throw "Runtime mode verification failed: $($runtime|ConvertTo-Json -Compress)"}
$clubUsers=Invoke-RestMethod 'http://127.0.0.1:8080/api/iran/customer-club/users' -Headers $headers -TimeoutSec 10
$adminUser=$clubUsers|Where-Object{$_.email -eq $after.adminEmail}|Select-Object -First 1
if(!$adminUser){throw 'Customer club could not resolve the local admin user.'}
$code='CI-CC-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$csv="name,mobile,code,nextActionTitle`nCI Offline Customer,09120000001,$code,Initial Followup"
$importBody=@{csvText=$csv;sourceName='ci-customer-club.csv';defaultOwnerUserId=[int64]$adminUser.id;defaultSource='WINDOWS_INSTALLER_CI'}|ConvertTo-Json -Depth 5
$importResult=Invoke-RestMethod 'http://127.0.0.1:8080/api/iran/customer-club/import' -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $importBody -TimeoutSec 20
if([int]$importResult.inserted -ne 1 -or [int]$importResult.rejected -ne 0){throw "Customer club CSV import failed: $($importResult|ConvertTo-Json -Compress)"}
$customerRows=Invoke-RestMethod ("http://127.0.0.1:8080/api/iran/customer-club/customers?q="+[uri]::EscapeDataString($code)) -Headers $headers -TimeoutSec 10
$clubCustomer=$customerRows|Where-Object{$_.code -eq $code}|Select-Object -First 1
if(!$clubCustomer -or [string]::IsNullOrWhiteSpace([string]$clubCustomer.member_no)){throw 'Imported customer or loyalty membership was not created.'}
$followBody=@{subject='Installer CI Followup';activityType='CALL';scheduledAt=(Get-Date).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss');ownerUserId=[int64]$adminUser.id}|ConvertTo-Json
$follow=Invoke-RestMethod "http://127.0.0.1:8080/api/iran/customer-club/customers/$($clubCustomer.party_id)/followups" -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $followBody -TimeoutSec 10
if([int64]$follow.id -le 0){throw 'Customer club follow-up creation failed.'}
$queue=Invoke-RestMethod 'http://127.0.0.1:8080/api/iran/customer-club/followups?status=OPEN' -Headers $headers -TimeoutSec 10
if(-not($queue|Where-Object{$_.id -eq $follow.id})){throw 'Created customer club follow-up is missing from the user queue.'}
Write-Host '[CI] OFFLINE_LAN + MySQL + customer club import/follow-up smoke test passed.'

Write-Host '[CI] Verifying HARD_CLOSED database guards installed by packaged Setup...'
# Verify trigger metadata as root because the runtime account intentionally has no
# TRIGGER privilege. Use scalar native arguments so PowerShell cannot stringify the
# whole PSCustomObject (the original source of the opaque mysql port failure).
$mysqlExe=[string]$after.mysqlExe
$mysqlHost=[string]$after.mysqlHost
$mysqlPort=[int]$after.mysqlPort
$mysqlDatabase=[string]$after.mysqlDatabase
$env:MYSQL_PWD=[string]$after.mysqlRootPassword
$triggerCount=& $mysqlExe "--protocol=tcp" "--host=$mysqlHost" "--port=$mysqlPort" "--user=root" "--database=$mysqlDatabase" "--batch" "--skip-column-names" "--execute=SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME IN ('trg_journal_line_hard_close_insert','trg_journal_line_hard_close_update','trg_journal_line_hard_close_delete');"
$mysqlExit=$LASTEXITCODE
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
if($mysqlExit -ne 0){throw "Database guard verification query failed: $mysqlExit"}
if([int]($triggerCount|Select-Object -Last 1) -lt 3){throw "Expected HARD_CLOSED journal triggers were not all installed. Found: $triggerCount"}

Write-Host "[CI] PASS - Enterprise 1.8 Windows/LAN installer; MySQL $($after.mysqlVersion) source=$($after.mysqlSource); config/secrets preserved; customer club workflow and DB guards verified."
