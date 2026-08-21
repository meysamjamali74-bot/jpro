#requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$AppRoot=Join-Path $Root 'app'
$RuntimeRoot=Join-Path $Root 'runtime'
$PrereqRoot=Join-Path $Root 'prereqs'
$DataRoot=Join-Path $Root 'data'
$ConfigRoot=Join-Path $Root 'config'
$LogRoot=Join-Path $Root 'logs'
$BackupRoot=Join-Path $Root 'backups'
$MySqlData=Join-Path $DataRoot 'mysql'
$MySqlRuntimeLocal=Join-Path $Root 'mysql-runtime'
$ConfigPath=Join-Path $ConfigRoot 'server.json'
$MyIni=Join-Path $ConfigRoot 'my.ini'
$MySqlService='TarazpadMySQL'
$ServerTask='Tarazpad ERP Server'
$BackupTask='Tarazpad ERP Daily Backup'
$WebPort=8080

function Step([string]$m){Write-Host "`n[TARAZPAD] $m" -ForegroundColor Cyan}
function Ok([string]$m){Write-Host "[OK] $m" -ForegroundColor Green}
function Warn([string]$m){Write-Host "[WARN] $m" -ForegroundColor Yellow}
function New-Secret([int]$length=48){
  $chars='abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*_-+'
  $rng=[System.Security.Cryptography.RandomNumberGenerator]::Create();$bytes=New-Object byte[] $length;$rng.GetBytes($bytes)
  return -join($bytes|ForEach-Object{$chars[$_%$chars.Length]})
}
function Test-FreePort([int]$port){
  $listener=$null
  try{$listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$port);$listener.Start();return $true}catch{return $false}finally{if($listener){$listener.Stop()}}
}
function Find-FreePort([int]$start=3307){for($p=$start;$p -le ($start+30);$p++){if(Test-FreePort $p){return $p}};throw 'No free local TCP port found in the allowed range.'}
function Test-TcpConnection([string]$serverHost,[int]$port,[int]$timeoutMs=1000){
  $client=$null
  try{
    $client=New-Object System.Net.Sockets.TcpClient
    $ar=$client.BeginConnect($serverHost,$port,$null,$null)
    if(-not $ar.AsyncWaitHandle.WaitOne($timeoutMs,$false)){return $false}
    $client.EndConnect($ar);return $client.Connected
  }catch{return $false}finally{if($client){$client.Close()}}
}
function Wait-Tcp([int]$port,[int]$seconds=60){for($i=0;$i -lt $seconds;$i++){if(Test-TcpConnection '127.0.0.1' $port 750){return $true};Start-Sleep 1};return $false}

function Ensure-VCRuntime{
  foreach($key in @('HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64','HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64')){
    try{$r=Get-ItemProperty $key -ErrorAction Stop;if($r.Installed -eq 1){Ok "Microsoft Visual C++ Runtime already installed (v$($r.Major).$($r.Minor)); skipped.";return}}catch{}
  }
  $installer=Join-Path $PrereqRoot 'vc_redist.x64.exe';if(!(Test-Path $installer)){throw 'Visual C++ runtime is missing and bundled installer is unavailable.'}
  Step 'Installing missing Microsoft Visual C++ runtime only...'
  $p=Start-Process $installer -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
  if($p.ExitCode -notin 0,1638,3010){throw "VC++ runtime setup failed with code $($p.ExitCode)."};Ok 'Microsoft Visual C++ Runtime ready.'
}
function Resolve-Node{
  $cmd=Get-Command node.exe -ErrorAction SilentlyContinue
  if($cmd){try{$major=[int]((& $cmd.Source -p 'process.versions.node').Split('.')[0]);if($major -ge 22){Ok "Compatible Node.js already installed ($(& $cmd.Source -v)); skipped.";return $cmd.Source}}catch{}}
  $bundled=Join-Path $RuntimeRoot 'node.exe';if(!(Test-Path $bundled)){throw 'Node.js 22+ is not installed and bundled Tarazpad runtime is missing.'}
  Ok 'Compatible system Node.js not found; using bundled Tarazpad runtime without installing Node.js system-wide.';return $bundled
}
function Test-MySqlBinary([string]$mysqlExe){
  if(!(Test-Path $mysqlExe)){return $null}
  try{
    $v=& $mysqlExe --version 2>$null
    if($v -match 'Ver\s+(\d+)\.(\d+)\.(\d+)' -and [int]$Matches[1] -eq 8 -and [int]$Matches[2] -eq 4){
      $bin=Split-Path -Parent $mysqlExe;$base=Split-Path -Parent $bin;$mysqld=Join-Path $bin 'mysqld.exe';$dump=Join-Path $bin 'mysqldump.exe'
      if((Test-Path $mysqld)-and(Test-Path $dump)){return [pscustomobject]@{Mysql=$mysqlExe;Mysqld=$mysqld;Dump=$dump;Base=$base;Version="$($Matches[1]).$($Matches[2]).$($Matches[3])";Source='system'}}
    }
  }catch{};return $null
}
function Find-CompatibleMySql{
  # Bounded checks only; never recursively scan a whole disk.
  $paths=New-Object System.Collections.Generic.List[string]
  $cmd=Get-Command mysql.exe -ErrorAction SilentlyContinue;if($cmd){[void]$paths.Add($cmd.Source)}
  foreach($p in @('C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe','C:\mysql\bin\mysql.exe','C:\mysql-8.4\bin\mysql.exe')){if(Test-Path $p){[void]$paths.Add($p)}}
  $root='C:\Program Files\MySQL';if(Test-Path $root){Get-ChildItem $root -Directory -ErrorAction SilentlyContinue|ForEach-Object{$p=Join-Path $_.FullName 'bin\mysql.exe';if(Test-Path $p){[void]$paths.Add($p)}}}
  foreach($p in ($paths|Select-Object -Unique)){$found=Test-MySqlBinary $p;if($found){return $found}}
  return $null
}
function Expand-BundledMySql{
  $zip=Join-Path $PrereqRoot 'mysql-8.4.11-winx64.zip';if(!(Test-Path $zip)){throw 'Bundled MySQL 8.4.11 archive is missing.'}
  if(Test-Path $MySqlRuntimeLocal){Remove-Item $MySqlRuntimeLocal -Recurse -Force};New-Item $MySqlRuntimeLocal -ItemType Directory -Force|Out-Null
  $tmp=Join-Path $env:TEMP ('tarazpad-mysql-'+[guid]::NewGuid());New-Item $tmp -ItemType Directory -Force|Out-Null
  Step 'No compatible MySQL 8.4 detected; extracting bundled MySQL 8.4.11...'
  $tar=Get-Command tar.exe -ErrorAction SilentlyContinue
  if($tar){& $tar.Source -xf $zip -C $tmp;if($LASTEXITCODE -ne 0){throw "MySQL extraction failed with code $LASTEXITCODE."}}else{Expand-Archive $zip -DestinationPath $tmp -Force}
  $top=Get-ChildItem $tmp -Directory|Select-Object -First 1;if(!$top){throw 'Invalid MySQL archive structure.'}
  Copy-Item (Join-Path $top.FullName '*') $MySqlRuntimeLocal -Recurse -Force;Remove-Item $tmp -Recurse -Force
  return [pscustomobject]@{Mysql=(Join-Path $MySqlRuntimeLocal 'bin\mysql.exe');Mysqld=(Join-Path $MySqlRuntimeLocal 'bin\mysqld.exe');Dump=(Join-Path $MySqlRuntimeLocal 'bin\mysqldump.exe');Base=$MySqlRuntimeLocal;Version='8.4.11';Source='bundled'}
}
function Write-MySqlConfig($mysql,[int]$port){
  $base=$mysql.Base.Replace('\','/');$data=$MySqlData.Replace('\','/');$err=(Join-Path $LogRoot 'mysql-error.log').Replace('\','/');$binlog=(Join-Path $DataRoot 'mysql-bin').Replace('\','/')
  @"
[mysqld]
basedir=$base
datadir=$data
port=$port
bind-address=127.0.0.1
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
server-id=1405
log-bin=$binlog
binlog_format=ROW
log-error=$err
max_connections=250
sql_mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
[client]
host=127.0.0.1
port=$port
default-character-set=utf8mb4
"@|Set-Content $MyIni -Encoding ascii
}
function Ensure-MySql{
  Ensure-VCRuntime
  $existing=$null;if(Test-Path $ConfigPath){try{$existing=Get-Content $ConfigPath -Raw|ConvertFrom-Json}catch{}}
  $service=Get-Service $MySqlService -ErrorAction SilentlyContinue
  if($service -and $existing -and (Test-Path $existing.mysqlExe)){
    Ok 'Existing Tarazpad MySQL instance detected; MySQL installation/configuration skipped.'
    if($service.Status -ne 'Running'){Start-Service $MySqlService;$service.WaitForStatus('Running','00:00:30')}
    return [pscustomobject]@{Mysql=$existing.mysqlExe;Mysqld=$existing.mysqldExe;Dump=$existing.mysqldumpExe;Base=$existing.mysqlBase;Version=$existing.mysqlVersion;Source=$existing.mysqlSource;Port=[int]$existing.mysqlPort;ExistingConfig=$existing}
  }
  $mysql=Find-CompatibleMySql
  if($mysql){Ok "Compatible system MySQL $($mysql.Version) detected; installation skipped and existing binaries will be reused."}else{$mysql=Expand-BundledMySql}
  New-Item $MySqlData -ItemType Directory -Force|Out-Null;$dbPort=Find-FreePort 3307;Write-MySqlConfig $mysql $dbPort
  if(!(Test-Path (Join-Path $MySqlData 'mysql'))){Step 'Initializing dedicated Tarazpad MySQL data directory...';& $mysql.Mysqld --defaults-file="$MyIni" --initialize-insecure;if($LASTEXITCODE -ne 0){throw "MySQL initialization failed with code $LASTEXITCODE."}}else{Ok 'Tarazpad MySQL data directory already initialized; skipped.'}
  if(!(Get-Service $MySqlService -ErrorAction SilentlyContinue)){& $mysql.Mysqld --install $MySqlService --defaults-file="$MyIni";if($LASTEXITCODE -ne 0){throw "MySQL service registration failed with code $LASTEXITCODE."}}else{Ok 'TarazpadMySQL service already registered; skipped.'}
  $service=Get-Service $MySqlService;if($service.Status -ne 'Running'){Start-Service $MySqlService;$service.WaitForStatus('Running','00:00:30')}
  if(!(Wait-Tcp $dbPort 60)){throw "Tarazpad MySQL service did not open TCP port $dbPort. See $LogRoot\mysql-error.log"};Ok "Tarazpad MySQL ready on local port $dbPort."
  $rootSecret=New-Secret 48;$appSecret=New-Secret 48;$jwtSecret=New-Secret 72;$adminSecret=New-Secret 24
  $sql=@"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$($rootSecret.Replace("'","''"))';
CREATE DATABASE IF NOT EXISTS tarazpad CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY '$($appSecret.Replace("'","''"))';
ALTER USER 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY '$($appSecret.Replace("'","''"))';
GRANT ALL PRIVILEGES ON tarazpad.* TO 'tarazpad_app'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
  $temp=Join-Path $env:TEMP ('tarazpad-db-'+[guid]::NewGuid()+'.sql');$sql|Set-Content $temp -Encoding utf8;$env:MYSQL_PWD=''
  Get-Content $temp|& $mysql.Mysql --protocol=tcp --host=127.0.0.1 --port=$dbPort --user=root --skip-password
  $exit=$LASTEXITCODE;Remove-Item $temp -Force;Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue;if($exit -ne 0){throw "Database bootstrap failed with code $exit."}
  return [pscustomobject]@{Mysql=$mysql.Mysql;Mysqld=$mysql.Mysqld;Dump=$mysql.Dump;Base=$mysql.Base;Version=$mysql.Version;Source=$mysql.Source;Port=$dbPort;RootSecret=$rootSecret;AppSecret=$appSecret;JwtSecret=$jwtSecret;AdminSecret=$adminSecret}
}

Step 'Preparing Tarazpad ERP Web Server...';New-Item $DataRoot,$ConfigRoot,$LogRoot,$BackupRoot -ItemType Directory -Force|Out-Null
$node=Resolve-Node;$db=Ensure-MySql
if($db.ExistingConfig -and $db.ExistingConfig.webPort){$WebPort=[int]$db.ExistingConfig.webPort;Ok "Existing Tarazpad web port $WebPort preserved."}elseif(-not(Test-FreePort $WebPort)){$WebPort=Find-FreePort 8081;Warn "TCP port 8080 is already in use; Tarazpad will use web port $WebPort instead."}
if($db.ExistingConfig){$cfg=$db.ExistingConfig;$cfg.nodeExe=$node}else{$cfg=[ordered]@{version='0.2.1';installedAt=(Get-Date).ToString('o');nodeExe=$node;mysqlExe=$db.Mysql;mysqldExe=$db.Mysqld;mysqldumpExe=$db.Dump;mysqlBase=$db.Base;mysqlVersion=$db.Version;mysqlSource=$db.Source;mysqlHost='127.0.0.1';mysqlPort=$db.Port;mysqlDatabase='tarazpad';mysqlUser='tarazpad_app';mysqlPassword=$db.AppSecret;mysqlRootPassword=$db.RootSecret;jwtSecret=$db.JwtSecret;adminEmail='admin@tarazpad.local';adminPassword=$db.AdminSecret;adminName='مدیر سیستم';webPort=$WebPort}}
$cfg|ConvertTo-Json -Depth 5|Set-Content $ConfigPath -Encoding utf8;& icacls $ConfigPath /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)'|Out-Null

$watch=@'
$ErrorActionPreference='Continue'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path;$cfg=Get-Content (Join-Path $root 'config\server.json') -Raw|ConvertFrom-Json
$env:NODE_ENV='production';$env:PORT=[string]$cfg.webPort;$env:MYSQL_HOST=$cfg.mysqlHost;$env:MYSQL_PORT=[string]$cfg.mysqlPort;$env:MYSQL_DATABASE=$cfg.mysqlDatabase;$env:MYSQL_USER=$cfg.mysqlUser;$env:MYSQL_PASSWORD=$cfg.mysqlPassword;$env:JWT_SECRET=$cfg.jwtSecret;$env:TARAZPAD_ADMIN_EMAIL=$cfg.adminEmail;$env:TARAZPAD_ADMIN_PASSWORD=$cfg.adminPassword;$env:TARAZPAD_ADMIN_NAME=$cfg.adminName
$server=Join-Path $root 'app\apps\api\src\server.js';$log=Join-Path $root 'logs\server-watchdog.log'
while($true){"$(Get-Date -Format o) starting Tarazpad API"|Add-Content $log;& $cfg.nodeExe $server 2>&1|Tee-Object -FilePath (Join-Path $root 'logs\server.log') -Append;"$(Get-Date -Format o) server exited: $LASTEXITCODE; restart in 5 seconds"|Add-Content $log;Start-Sleep 5}
'@
$watch|Set-Content (Join-Path $Root 'Watch-Tarazpad.ps1') -Encoding utf8
$backup=@'
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path;$cfg=Get-Content (Join-Path $root 'config\server.json') -Raw|ConvertFrom-Json;$dir=Join-Path $root 'backups';New-Item $dir -ItemType Directory -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$sql=Join-Path $dir "tarazpad-$stamp.sql";$zip=Join-Path $dir "tarazpad-$stamp.zip";$env:MYSQL_PWD=$cfg.mysqlPassword
& $cfg.mysqldumpExe --protocol=tcp -h$cfg.mysqlHost -P$cfg.mysqlPort -u$cfg.mysqlUser --single-transaction --routines --triggers --events --default-character-set=utf8mb4 $cfg.mysqlDatabase|Set-Content $sql -Encoding utf8
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue;Compress-Archive $sql $zip -CompressionLevel Optimal -Force;Remove-Item $sql -Force;Get-ChildItem $dir -Filter 'tarazpad-*.zip'|Where-Object LastWriteTime -lt (Get-Date).AddDays(-30)|Remove-Item -Force
'@
$backup|Set-Content (Join-Path $Root 'Backup-Tarazpad.ps1') -Encoding utf8

Step 'Registering/updating automatic startup and backup...'
$taskCmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Root 'Watch-Tarazpad.ps1')`"";& schtasks.exe /Create /TN $ServerTask /SC ONSTART /RU SYSTEM /RL HIGHEST /TR $taskCmd /F|Out-Null
$backupCmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Root 'Backup-Tarazpad.ps1')`"";& schtasks.exe /Create /TN $BackupTask /SC DAILY /ST 02:00 /RU SYSTEM /RL HIGHEST /TR $backupCmd /F|Out-Null
& schtasks.exe /End /TN $ServerTask 2>$null|Out-Null;Start-Sleep 1;& schtasks.exe /Run /TN $ServerTask|Out-Null
if(-not(Get-NetFirewallRule -DisplayName 'Tarazpad ERP Web' -ErrorAction SilentlyContinue)){New-NetFirewallRule -DisplayName 'Tarazpad ERP Web' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $WebPort -Profile Domain,Private|Out-Null;Ok 'Private/domain firewall rule created.'}else{Ok 'Firewall rule already exists; skipped.'}
Step 'Running application health check...';$healthy=$false
for($i=0;$i -lt 60;$i++){try{$r=Invoke-RestMethod "http://127.0.0.1:$WebPort/api/health" -TimeoutSec 2;if($r.ok){$healthy=$true;break}}catch{};Start-Sleep 1};if(!$healthy){throw "Tarazpad API did not become healthy. See $LogRoot"};Ok 'Tarazpad API and MySQL health check passed.'
$cred=Join-Path $Root 'INITIAL-LOGIN.txt';if(!(Test-Path $cred)){@"
Tarazpad ERP initial login
URL: http://localhost:$WebPort
Email: $($cfg.adminEmail)
Password: $($cfg.adminPassword)

Keep this file private. Configuration secrets are protected for Administrators/SYSTEM only.
"@|Set-Content $cred -Encoding utf8;& icacls $cred /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)'|Out-Null}
try{$shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut([Environment]::GetFolderPath('CommonDesktopDirectory')+'\Tarazpad ERP.lnk');$shortcut.TargetPath=(Join-Path $env:WINDIR 'explorer.exe');$shortcut.Arguments="http://localhost:$WebPort";$shortcut.WorkingDirectory=$Root;$shortcut.Save()}catch{}
$ips=Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue|Where-Object{$_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*'}|Select-Object -ExpandProperty IPAddress
Write-Host "`n============================================================" -ForegroundColor Green;Write-Host ' TARAZPAD ERP WEB SERVER INSTALLED / UPDATED SUCCESSFULLY ' -ForegroundColor Green;Write-Host " Local: http://localhost:$WebPort";foreach($ip in $ips){Write-Host " LAN:   http://$ip`:$WebPort"};Write-Host " Initial login: $cred";Write-Host " Daily backups: $BackupRoot";Write-Host ' Compatible prerequisites already present were detected and NOT reinstalled.';Write-Host "============================================================`n" -ForegroundColor Green
if($env:GITHUB_ACTIONS -ne 'true'){Start-Process "http://localhost:$WebPort"}
