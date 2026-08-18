#requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppRoot = Join-Path $Root 'app'
$RuntimeRoot = Join-Path $Root 'runtime'
$PrereqRoot = Join-Path $Root 'prereqs'
$DataRoot = Join-Path $Root 'data'
$ConfigRoot = Join-Path $Root 'config'
$LogRoot = Join-Path $Root 'logs'
$BackupRoot = Join-Path $Root 'backups'
$MySqlData = Join-Path $DataRoot 'mysql'
$MySqlRuntimeLocal = Join-Path $Root 'mysql-runtime'
$ConfigPath = Join-Path $ConfigRoot 'server.json'
$MyIni = Join-Path $ConfigRoot 'my.ini'
$ServiceName = 'TarazpadMySQL'
$TaskName = 'Tarazpad ERP Server'
$BackupTaskName = 'Tarazpad ERP Daily Backup'
$Port = 8080

function Step($m) { Write-Host "`n[TARAZPAD] $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[ERROR] $m" -ForegroundColor Red }
function New-Secret([int]$length=48) {
  $chars='abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*_-+'
  $rng=[System.Security.Cryptography.RandomNumberGenerator]::Create()
  $bytes=New-Object byte[] $length
  $rng.GetBytes($bytes)
  -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}
function Test-TcpPort([int]$p) {
  try { $l=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$p); $l.Start(); $l.Stop(); $true } catch { $false }
}
function Find-FreePort([int]$start=3307) {
  for($p=$start;$p -le $start+20;$p++){ if(Test-TcpPort $p){ return $p } }
  throw 'No free MySQL TCP port found.'
}
function Get-MySqlCandidate {
  $c=@()
  $cmd=Get-Command mysql.exe -ErrorAction SilentlyContinue
  if($cmd){ $c += $cmd.Source }
  $c += Get-ChildItem 'C:\Program Files\MySQL' -Filter mysql.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
  $c += Get-ChildItem 'C:\mysql*' -Filter mysql.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
  foreach($mysql in ($c | Where-Object {$_} | Select-Object -Unique)){
    try{
      $v=& $mysql --version 2>$null
      if($v -match 'Ver\s+(\d+)\.(\d+)\.(\d+)'){
        if([int]$Matches[1] -gt 8 -or ([int]$Matches[1] -eq 8 -and [int]$Matches[2] -ge 4)){
          $bin=Split-Path -Parent $mysql
          $base=Split-Path -Parent $bin
          $mysqld=Join-Path $bin 'mysqld.exe'
          $dump=Join-Path $bin 'mysqldump.exe'
          if(Test-Path $mysqld){ return [pscustomobject]@{ Mysql=$mysql; Mysqld=$mysqld; Dump=$dump; Base=$base; Version="$($Matches[1]).$($Matches[2]).$($Matches[3])"; Source='system' } }
        }
      }
    }catch{}
  }
  return $null
}
function Ensure-VCRuntime {
  $installed=$false
  foreach($key in @('HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64','HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64')){
    try{ $p=Get-ItemProperty $key -ErrorAction Stop; if($p.Installed -eq 1){$installed=$true;break} }catch{}
  }
  if($installed){ Ok 'Microsoft Visual C++ Runtime already installed; skipped.'; return }
  $vc=Join-Path $PrereqRoot 'vc_redist.x64.exe'
  if(!(Test-Path $vc)){ throw 'Visual C++ runtime is missing and bundled installer was not found.' }
  Step 'Installing missing Microsoft Visual C++ runtime only...'
  $p=Start-Process $vc -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
  if($p.ExitCode -notin 0,1638,3010){ throw "VC++ runtime installer failed: $($p.ExitCode)" }
  Ok 'Visual C++ runtime ready.'
}
function Ensure-Node {
  $cmd=Get-Command node.exe -ErrorAction SilentlyContinue
  if($cmd){
    try{ $major=[int]((& $cmd.Source -p 'process.versions.node').Split('.')[0]); if($major -ge 22){ Ok "Compatible Node.js already installed ($(& $cmd.Source -v)); skipped."; return $cmd.Source } }catch{}
  }
  $bundled=Join-Path $RuntimeRoot 'node.exe'
  if(!(Test-Path $bundled)){ throw 'Compatible Node.js not installed and bundled runtime is missing.' }
  Ok 'System Node.js not suitable; using bundled Tarazpad runtime (no system installation).'
  return $bundled
}
function Expand-BundledMySql {
  $zip=Join-Path $PrereqRoot 'mysql-8.4.11-winx64.zip'
  if(!(Test-Path $zip)){ throw 'Bundled MySQL 8.4.11 archive not found.' }
  if(Test-Path $MySqlRuntimeLocal){ Remove-Item $MySqlRuntimeLocal -Recurse -Force }
  New-Item $MySqlRuntimeLocal -ItemType Directory -Force | Out-Null
  $tmp=Join-Path $env:TEMP ('tarazpad-mysql-'+[guid]::NewGuid())
  New-Item $tmp -ItemType Directory -Force | Out-Null
  Step 'Extracting bundled MySQL 8.4.11 because no compatible MySQL 8.4+ was found...'
  Expand-Archive $zip -DestinationPath $tmp -Force
  $top=Get-ChildItem $tmp -Directory | Select-Object -First 1
  if(!$top){ throw 'Bundled MySQL archive structure is invalid.' }
  Copy-Item (Join-Path $top.FullName '*') $MySqlRuntimeLocal -Recurse -Force
  Remove-Item $tmp -Recurse -Force
  return [pscustomobject]@{ Mysql=(Join-Path $MySqlRuntimeLocal 'bin\mysql.exe'); Mysqld=(Join-Path $MySqlRuntimeLocal 'bin\mysqld.exe'); Dump=(Join-Path $MySqlRuntimeLocal 'bin\mysqldump.exe'); Base=$MySqlRuntimeLocal; Version='8.4.11'; Source='bundled' }
}
function Write-MyIni($mysql,[int]$dbPort){
  $basedir=$mysql.Base.Replace('\','/')
  $datadir=$MySqlData.Replace('\','/')
  $log=(Join-Path $LogRoot 'mysql-error.log').Replace('\','/')
  $binlog=(Join-Path $DataRoot 'mysql-bin').Replace('\','/')
  @"
[mysqld]
basedir=$basedir
datadir=$datadir
port=$dbPort
bind-address=127.0.0.1
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
server-id=1405
log-bin=$binlog
binlog_format=ROW
log-error=$log
max_connections=250
sql_mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
[client]
port=$dbPort
host=127.0.0.1
default-character-set=utf8mb4
"@ | Set-Content $MyIni -Encoding ascii
}
function Wait-MySql($mysql,[int]$dbPort,[int]$seconds=60){
  for($i=0;$i -lt $seconds;$i++){
    try{ & $mysql.Mysql --protocol=tcp -h127.0.0.1 -P$dbPort -uroot -e 'SELECT 1' 2>$null | Out-Null; return $true }catch{}
    Start-Sleep 1
  }
  return $false
}
function Ensure-MySql {
  Ensure-VCRuntime
  $existingConfig=$null
  if(Test-Path $ConfigPath){ try{$existingConfig=Get-Content $ConfigPath -Raw | ConvertFrom-Json}catch{} }
  $svc=Get-Service $ServiceName -ErrorAction SilentlyContinue
  if($svc -and $existingConfig -and (Test-Path $existingConfig.mysqlExe)){
    Ok 'Tarazpad MySQL instance already configured; database installation skipped.'
    if($svc.Status -ne 'Running'){ Start-Service $ServiceName; $svc.WaitForStatus('Running','00:00:30') }
    return [pscustomobject]@{ Mysql=$existingConfig.mysqlExe; Mysqld=$existingConfig.mysqldExe; Dump=$existingConfig.mysqldumpExe; Base=$existingConfig.mysqlBase; Version=$existingConfig.mysqlVersion; Source=$existingConfig.mysqlSource; Port=[int]$existingConfig.mysqlPort; ExistingConfig=$existingConfig }
  }

  $mysql=Get-MySqlCandidate
  if($mysql){ Ok "Compatible MySQL $($mysql.Version) already installed; reusing binaries and skipping MySQL installation." }
  else { $mysql=Expand-BundledMySql }

  New-Item $MySqlData -ItemType Directory -Force | Out-Null
  $dbPort=Find-FreePort 3307
  Write-MyIni $mysql $dbPort

  if(!(Test-Path (Join-Path $MySqlData 'mysql'))){
    Step 'Initializing dedicated Tarazpad MySQL data directory...'
    & $mysql.Mysqld --defaults-file="$MyIni" --initialize-insecure
    if($LASTEXITCODE -ne 0){ throw "MySQL initialization failed: $LASTEXITCODE" }
  }
  if(!(Get-Service $ServiceName -ErrorAction SilentlyContinue)){
    & $mysql.Mysqld --install $ServiceName --defaults-file="$MyIni"
    if($LASTEXITCODE -ne 0){ throw "MySQL service registration failed: $LASTEXITCODE" }
  } else { Ok 'TarazpadMySQL Windows service already exists; registration skipped.' }
  Start-Service $ServiceName
  (Get-Service $ServiceName).WaitForStatus('Running','00:00:30')
  if(!(Wait-MySql $mysql $dbPort 60)){ throw 'Tarazpad MySQL did not become ready.' }

  $rootSecret=New-Secret 48
  $appSecret=New-Secret 48
  $jwtSecret=New-Secret 72
  $adminSecret=New-Secret 24
  $env:MYSQL_PWD=''
  $sql=@"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$($rootSecret.Replace("'","''"))';
CREATE DATABASE IF NOT EXISTS tarazpad CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY '$($appSecret.Replace("'","''"))';
ALTER USER 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY '$($appSecret.Replace("'","''"))';
GRANT ALL PRIVILEGES ON tarazpad.* TO 'tarazpad_app'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
  $tempSql=Join-Path $env:TEMP ('tarazpad-init-'+[guid]::NewGuid()+'.sql')
  $sql | Set-Content $tempSql -Encoding utf8
  Get-Content $tempSql | & $mysql.Mysql --protocol=tcp -h127.0.0.1 -P$dbPort -uroot
  Remove-Item $tempSql -Force
  Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
  return [pscustomobject]@{ Mysql=$mysql.Mysql; Mysqld=$mysql.Mysqld; Dump=$mysql.Dump; Base=$mysql.Base; Version=$mysql.Version; Source=$mysql.Source; Port=$dbPort; RootSecret=$rootSecret; AppSecret=$appSecret; JwtSecret=$jwtSecret; AdminSecret=$adminSecret }
}

Step 'Preparing Tarazpad ERP Web Server...'
New-Item $DataRoot,$ConfigRoot,$LogRoot,$BackupRoot -ItemType Directory -Force | Out-Null
$node=Ensure-Node
$db=Ensure-MySql

if($db.ExistingConfig){
  $cfg=$db.ExistingConfig
  $cfg.nodeExe=$node
} else {
  $cfg=[ordered]@{
    version='0.2.0'
    installedAt=(Get-Date).ToString('o')
    nodeExe=$node
    mysqlExe=$db.Mysql
    mysqldExe=$db.Mysqld
    mysqldumpExe=$db.Dump
    mysqlBase=$db.Base
    mysqlVersion=$db.Version
    mysqlSource=$db.Source
    mysqlHost='127.0.0.1'
    mysqlPort=$db.Port
    mysqlDatabase='tarazpad'
    mysqlUser='tarazpad_app'
    mysqlPassword=$db.AppSecret
    mysqlRootPassword=$db.RootSecret
    jwtSecret=$db.JwtSecret
    adminEmail='admin@tarazpad.local'
    adminPassword=$db.AdminSecret
    adminName='مدیر سیستم'
    webPort=$Port
  }
}
$cfg | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding utf8
& icacls $ConfigPath /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)' | Out-Null

$watch=@'
$ErrorActionPreference='Continue'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg=Get-Content (Join-Path $root 'config\server.json') -Raw | ConvertFrom-Json
$env:NODE_ENV='production'
$env:PORT=[string]$cfg.webPort
$env:MYSQL_HOST=$cfg.mysqlHost
$env:MYSQL_PORT=[string]$cfg.mysqlPort
$env:MYSQL_DATABASE=$cfg.mysqlDatabase
$env:MYSQL_USER=$cfg.mysqlUser
$env:MYSQL_PASSWORD=$cfg.mysqlPassword
$env:JWT_SECRET=$cfg.jwtSecret
$env:TARAZPAD_ADMIN_EMAIL=$cfg.adminEmail
$env:TARAZPAD_ADMIN_PASSWORD=$cfg.adminPassword
$env:TARAZPAD_ADMIN_NAME=$cfg.adminName
$server=Join-Path $root 'app\apps\api\src\server.js'
$log=Join-Path $root 'logs\server-watchdog.log'
while($true){
  "$(Get-Date -Format o) starting Tarazpad API" | Add-Content $log
  & $cfg.nodeExe $server 2>&1 | Tee-Object -FilePath (Join-Path $root 'logs\server.log') -Append
  "$(Get-Date -Format o) server exited: $LASTEXITCODE; restart in 5 seconds" | Add-Content $log
  Start-Sleep 5
}
'@
$watch | Set-Content (Join-Path $Root 'Watch-Tarazpad.ps1') -Encoding utf8

$backup=@'
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg=Get-Content (Join-Path $root 'config\server.json') -Raw | ConvertFrom-Json
$dir=Join-Path $root 'backups'
New-Item $dir -ItemType Directory -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$sql=Join-Path $dir "tarazpad-$stamp.sql"
$zip=Join-Path $dir "tarazpad-$stamp.zip"
$env:MYSQL_PWD=$cfg.mysqlPassword
& $cfg.mysqldumpExe --protocol=tcp -h$cfg.mysqlHost -P$cfg.mysqlPort -u$cfg.mysqlUser --single-transaction --routines --triggers --events --default-character-set=utf8mb4 $cfg.mysqlDatabase | Set-Content $sql -Encoding utf8
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
Compress-Archive $sql $zip -CompressionLevel Optimal -Force
Remove-Item $sql -Force
Get-ChildItem $dir -Filter 'tarazpad-*.zip' | Where-Object LastWriteTime -lt (Get-Date).AddDays(-30) | Remove-Item -Force
'@
$backup | Set-Content (Join-Path $Root 'Backup-Tarazpad.ps1') -Encoding utf8

Step 'Registering/updating Tarazpad automatic startup...'
$taskCmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Root 'Watch-Tarazpad.ps1')`""
& schtasks.exe /Create /TN $TaskName /SC ONSTART /RU SYSTEM /RL HIGHEST /TR $taskCmd /F | Out-Null
$backupCmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Root 'Backup-Tarazpad.ps1')`""
& schtasks.exe /Create /TN $BackupTaskName /SC DAILY /ST 02:00 /RU SYSTEM /RL HIGHEST /TR $backupCmd /F | Out-Null
& schtasks.exe /End /TN $TaskName 2>$null | Out-Null
Start-Sleep 1
& schtasks.exe /Run /TN $TaskName | Out-Null

if(-not (Get-NetFirewallRule -DisplayName 'Tarazpad ERP Web' -ErrorAction SilentlyContinue)){
  New-NetFirewallRule -DisplayName 'Tarazpad ERP Web' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Domain,Private | Out-Null
  Ok 'Windows Firewall private/domain rule created.'
} else { Ok 'Firewall rule already exists; skipped.' }

Step 'Running health check...'
$healthy=$false
for($i=0;$i -lt 60;$i++){
  try{ $r=Invoke-RestMethod "http://127.0.0.1:$Port/api/health" -TimeoutSec 2; if($r.ok){$healthy=$true;break} }catch{}
  Start-Sleep 1
}
if(!$healthy){ throw "Tarazpad API did not become healthy. See $LogRoot" }
Ok 'Tarazpad API + MySQL health check passed.'

$cred=Join-Path $Root 'INITIAL-LOGIN.txt'
if(!(Test-Path $cred)){
  @"
Tarazpad ERP initial login
URL: http://localhost:$Port
Email: $($cfg.adminEmail)
Password: $($cfg.adminPassword)

Change the initial password after first login when user-management module is enabled.
Configuration secrets are stored under $ConfigRoot with Administrator/SYSTEM ACL only.
"@ | Set-Content $cred -Encoding utf8
  & icacls $cred /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)' | Out-Null
}

try{
  $shell=New-Object -ComObject WScript.Shell
  $shortcut=$shell.CreateShortcut([Environment]::GetFolderPath('CommonDesktopDirectory')+'\Tarazpad ERP.lnk')
  $shortcut.TargetPath='http://localhost:8080'
  $shortcut.Save()
}catch{}

$ips=Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*'} | Select-Object -ExpandProperty IPAddress
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host ' TARAZPAD ERP WEB SERVER INSTALLED / UPDATED SUCCESSFULLY ' -ForegroundColor Green
Write-Host " Local: http://localhost:$Port"
foreach($ip in $ips){ Write-Host " LAN:   http://$ip`:$Port" }
Write-Host " Initial login file: $cred"
Write-Host " Daily backups: $BackupRoot"
Write-Host ' Existing compatible prerequisites were reused and NOT reinstalled.'
Write-Host "============================================================`n" -ForegroundColor Green
Start-Process "http://localhost:$Port"
