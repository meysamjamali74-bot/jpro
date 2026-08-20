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
try{
  Write-Host '[TARAZPAD] Enabling trigger creation on the dedicated Tarazpad MySQL instance...'
  & $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --execute="SET GLOBAL log_bin_trust_function_creators=1;" $cfg.mysqlDatabase
  if($LASTEXITCODE -ne 0){throw "Unable to configure MySQL trigger trust. Exit code: $LASTEXITCODE"}

  Write-Host '[TARAZPAD] Installing HARD_CLOSED database guards...'
  Get-Content $SqlPath -Raw | & $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root $cfg.mysqlDatabase
  if($LASTEXITCODE -ne 0){throw "Database guard installation failed. Exit code: $LASTEXITCODE"}

  $count=& $cfg.mysqlExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=root --batch --skip-column-names --execute="SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME IN ('trg_journal_hard_close_delete','trg_journal_hard_close_update','trg_journal_line_hard_close_insert','trg_journal_line_hard_close_update','trg_journal_line_hard_close_delete');" $cfg.mysqlDatabase
  if($LASTEXITCODE -ne 0){throw "Database guard verification query failed. Exit code: $LASTEXITCODE"}
  if([int]([string]$count).Trim() -ne 5){throw "Expected 5 HARD_CLOSED database guards but found $count."}

  Write-Host '[OK] HARD_CLOSED database guards installed and verified.' -ForegroundColor Green
}
finally{
  Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
