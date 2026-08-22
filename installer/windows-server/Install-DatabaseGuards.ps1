[CmdletBinding()]
param()

$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath=Join-Path $Root 'config\server.json'
$SqlPath=Join-Path $Root 'HardClose-DatabaseGuards.sql'

if(!(Test-Path $ConfigPath)){throw "Tarazpad configuration not found: $ConfigPath"}
if(!(Test-Path $SqlPath)){throw "Database guard SQL not found: $SqlPath"}

$cfg=Get-Content $ConfigPath -Raw | ConvertFrom-Json
if(!(Test-Path $cfg.mysqlExe)){throw "MySQL client not found: $($cfg.mysqlExe)"}
if([string]::IsNullOrWhiteSpace([string]$cfg.mysqlRootPassword)){throw 'Tarazpad MySQL root credential is unavailable.'}

$env:MYSQL_PWD=[string]$cfg.mysqlRootPassword
$trustEnabled=$false
try{
  Write-Host '[TARAZPAD] Temporarily enabling trusted trigger creation on the dedicated Tarazpad MySQL instance...'
  & $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --execute="SET GLOBAL log_bin_trust_function_creators=1;" $cfg.mysqlDatabase
  if($LASTEXITCODE -ne 0){throw "Unable to configure MySQL trigger trust. Exit code: $LASTEXITCODE"}
  $trustEnabled=$true

  Write-Host '[TARAZPAD] Installing HARD_CLOSED database guards...'
  Get-Content $SqlPath -Raw | & $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root $cfg.mysqlDatabase
  if($LASTEXITCODE -ne 0){throw "Database guard installation failed. Exit code: $LASTEXITCODE"}

  $count=& $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --batch --skip-column-names --execute="SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME IN ('trg_journal_hard_close_delete','trg_journal_hard_close_update','trg_journal_line_hard_close_insert','trg_journal_line_hard_close_update','trg_journal_line_hard_close_delete');" $cfg.mysqlDatabase
  if($LASTEXITCODE -ne 0){throw "Database guard verification query failed. Exit code: $LASTEXITCODE"}
  if([int]([string]$count).Trim() -ne 5){throw "Expected 5 HARD_CLOSED database guards but found $count."}

  # The application needs normal DML plus schema migration DDL, but it does not
  # need SUPER/TRIGGER/CREATE ROUTINE/ALTER ROUTINE during daily operation.
  # Trigger installation is intentionally owned by this root-only installer step.
  $dbName=[string]$cfg.mysqlDatabase
  $appUser=[string]$cfg.mysqlUser
  if($appUser -eq 'tarazpad_app'){
    Write-Host '[TARAZPAD] Applying least-privilege runtime database grants...'
    $grantSql=@"
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'tarazpad_app'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES, CREATE TEMPORARY TABLES, LOCK TABLES ON ``$dbName``.* TO 'tarazpad_app'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
    & $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --execute=$grantSql $dbName
    if($LASTEXITCODE -ne 0){throw "Unable to apply least-privilege runtime grants. Exit code: $LASTEXITCODE"}

    $grants=& $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --batch --skip-column-names --execute="SHOW GRANTS FOR 'tarazpad_app'@'127.0.0.1';" $dbName
    if($LASTEXITCODE -ne 0){throw 'Unable to verify runtime database grants.'}
    $grantText=($grants -join "`n")
    if($grantText -match '(?i)\bTRIGGER\b|CREATE ROUTINE|ALTER ROUTINE|\bSUPER\b'){throw 'Runtime database user still has privileged routine/trigger permissions.'}
  }

  Write-Host '[OK] HARD_CLOSED database guards installed; runtime DB permissions restricted.' -ForegroundColor Green
}
finally{
  if($trustEnabled){
    try{
      & $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --execute="SET GLOBAL log_bin_trust_function_creators=0;" $cfg.mysqlDatabase | Out-Null
    }catch{}
  }
  Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
