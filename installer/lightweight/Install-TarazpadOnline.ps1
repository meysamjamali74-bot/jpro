#requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$Root='C:\ProgramData\Tarazpad\server'
$CacheRoot=Join-Path $Root 'cache'
$RuntimeRoot=Join-Path $Root 'runtime'
$NodeRuntime=Join-Path $RuntimeRoot 'node'
$MySqlRuntime=Join-Path $RuntimeRoot 'mysql'
$AppRoot=Join-Path $Root 'app'
$DataRoot=Join-Path $Root 'data'
$MySqlData=Join-Path $DataRoot 'mysql'
$ConfigRoot=Join-Path $Root 'config'
$LogRoot=Join-Path $Root 'logs'
$BackupRoot=Join-Path $Root 'backups'
$ConfigPath=Join-Path $ConfigRoot 'server.json'
$MyIni=Join-Path $ConfigRoot 'my.ini'
$MySqlService='TarazpadMySQL'
$ServerTask='Tarazpad ERP Server'
$BackupTask='Tarazpad ERP Daily Backup'
$WebPort=8080
$RepoZipUrl='https://github.com/meysamjamali74-bot/jpro/archive/refs/heads/main.zip'
$MySqlUrl='https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip'
$VcUrl='https://aka.ms/vs/17/release/vc_redist.x64.exe'

New-Item $Root,$CacheRoot,$RuntimeRoot,$DataRoot,$ConfigRoot,$LogRoot,$BackupRoot -ItemType Directory -Force|Out-Null
$Transcript=Join-Path $LogRoot ('installer-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')
try{Start-Transcript -Path $Transcript -Force|Out-Null}catch{}

function Step([string]$m){Write-Host "`n[TARAZPAD] $m" -ForegroundColor Cyan}
function Ok([string]$m){Write-Host "[OK] $m" -ForegroundColor Green}
function Warn([string]$m){Write-Host "[WARN] $m" -ForegroundColor Yellow}
function New-Secret([int]$length=48){
  $chars='abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*_-+'
  $rng=[Security.Cryptography.RandomNumberGenerator]::Create();$b=New-Object byte[] $length;$rng.GetBytes($b)
  return -join($b|ForEach-Object{$chars[$_%$chars.Length]})
}
function Download-File([string]$url,[string]$out,[long]$minBytes=1024){
  if((Test-Path $out)-and((Get-Item $out).Length -ge $minBytes)){Ok "Cached download reused: $(Split-Path $out -Leaf)";return}
  New-Item (Split-Path $out -Parent) -ItemType Directory -Force|Out-Null
  for($try=1;$try -le 4;$try++){
    try{
      Step "Downloading $(Split-Path $out -Leaf) ($try/4)..."
      $curl=Get-Command curl.exe -ErrorAction SilentlyContinue
      if($curl){& $curl.Source -L --fail --retry 3 --retry-delay 3 --connect-timeout 30 -A 'Tarazpad-ERP-Installer/0.3' -o $out $url;if($LASTEXITCODE -ne 0){throw "curl exit $LASTEXITCODE"}}
      else{Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 600}
      if((Test-Path $out)-and((Get-Item $out).Length -ge $minBytes)){Ok "Download ready: $(Split-Path $out -Leaf)";return}
      throw 'Downloaded file is unexpectedly small.'
    }catch{Warn $_.Exception.Message;Remove-Item $out -Force -ErrorAction SilentlyContinue;if($try -eq 4){throw};Start-Sleep (2*$try)}
  }
}
function Test-FreePort([int]$port){$l=$null;try{$l=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port);$l.Start();return $true}catch{return $false}finally{if($l){$l.Stop()}}}
function Find-FreePort([int]$start=3307){for($p=$start;$p -le $start+30;$p++){if(Test-FreePort $p){return $p}};throw 'No free MySQL port found.'}
function Test-Tcp([string]$serverHost,[int]$port,[int]$timeout=1000){$c=$null;try{$c=New-Object Net.Sockets.TcpClient;$ar=$c.BeginConnect($serverHost,$port,$null,$null);if(!$ar.AsyncWaitHandle.WaitOne($timeout,$false)){return $false};$c.EndConnect($ar);return $c.Connected}catch{return $false}finally{if($c){$c.Close()}}}
function Wait-Tcp([int]$port,[int]$seconds=90){for($i=0;$i -lt $seconds;$i++){if(Test-Tcp '127.0.0.1' $port 800){return $true};Start-Sleep 1};return $false}

function Ensure-VCRuntime{
  foreach($k in @('HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64','HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64')){
    try{$r=Get-ItemProperty $k -ErrorAction Stop;if($r.Installed -eq 1){Ok "Visual C++ Runtime already installed (v$($r.Major).$($r.Minor)); skipped.";return}}catch{}
  }
  $file=Join-Path $CacheRoot 'vc_redist.x64.exe';Download-File $VcUrl $file 5000000
  Step 'Installing missing Visual C++ Runtime...';$p=Start-Process $file -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
  if($p.ExitCode -notin 0,1638,3010){throw "Visual C++ Runtime install failed: $($p.ExitCode)"};Ok 'Visual C++ Runtime ready.'
}
function Resolve-Node{
  $node=Get-Command node.exe -ErrorAction SilentlyContinue;$npm=Get-Command npm.cmd -ErrorAction SilentlyContinue
  if($node -and $npm){try{$major=[int]((& $node.Source -p 'process.versions.node').Split('.')[0]);if($major -ge 22){Ok "Node.js $(& $node.Source -v) already installed; skipped.";return [pscustomobject]@{Node=$node.Source;Npm=$npm.Source;Source='system'}}}catch{}}
  $localNode=Join-Path $NodeRuntime 'node.exe';$localNpm=Join-Path $NodeRuntime 'npm.cmd'
  if((Test-Path $localNode)-and(Test-Path $localNpm)){try{$major=[int]((& $localNode -p 'process.versions.node').Split('.')[0]);if($major -ge 22){Ok "Existing Tarazpad Node runtime $(& $localNode -v) reused.";return [pscustomobject]@{Node=$localNode;Npm=$localNpm;Source='tarazpad-runtime'}}}catch{}}
  Step 'Node.js 22+ not found; resolving current Node 22 runtime...'
  $index=Invoke-RestMethod 'https://nodejs.org/dist/index.json' -TimeoutSec 60
  $rel=$index|Where-Object{$_.version -match '^v22\.'}|Select-Object -First 1
  if(!$rel){throw 'Could not resolve a Node.js 22 release.'}
  $zip=Join-Path $CacheRoot ("node-$($rel.version)-win-x64.zip")
  Download-File ("https://nodejs.org/dist/$($rel.version)/node-$($rel.version)-win-x64.zip") $zip 15000000
  $tmp=Join-Path $env:TEMP ('tarazpad-node-'+[guid]::NewGuid());New-Item $tmp -ItemType Directory -Force|Out-Null
  Expand-Archive $zip -DestinationPath $tmp -Force;$top=Get-ChildItem $tmp -Directory|Select-Object -First 1;if(!$top){throw 'Invalid Node archive.'}
  Remove-Item $NodeRuntime -Recurse -Force -ErrorAction SilentlyContinue;New-Item $NodeRuntime -ItemType Directory -Force|Out-Null
  Copy-Item (Join-Path $top.FullName '*') $NodeRuntime -Recurse -Force;Remove-Item $tmp -Recurse -Force
  if(!(Test-Path $localNode)-or!(Test-Path $localNpm)){throw 'Portable Node runtime extraction failed.'}
  Ok "Portable Node $(& $localNode -v) installed only inside Tarazpad.";return [pscustomobject]@{Node=$localNode;Npm=$localNpm;Source='tarazpad-runtime'}
}
function Test-MySqlBinary([string]$mysqlExe){
  if(!(Test-Path $mysqlExe)){return $null};try{$v=& $mysqlExe --version 2>$null;if($v -match 'Ver\s+(8)\.(4)\.(\d+)'){$bin=Split-Path $mysqlExe -Parent;$base=Split-Path $bin -Parent;$d=Join-Path $bin 'mysqld.exe';$dump=Join-Path $bin 'mysqldump.exe';if((Test-Path $d)-and(Test-Path $dump)){return [pscustomobject]@{Mysql=$mysqlExe;Mysqld=$d;Dump=$dump;Base=$base;Version="8.4.$($Matches[3])";Source='system'}}}}catch{};return $null
}
function Find-MySql84{
  $paths=New-Object Collections.Generic.List[string];$cmd=Get-Command mysql.exe -ErrorAction SilentlyContinue;if($cmd){[void]$paths.Add($cmd.Source)}
  foreach($p in @('C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe','C:\mysql\bin\mysql.exe','C:\mysql-8.4\bin\mysql.exe',(Join-Path $MySqlRuntime 'bin\mysql.exe'))){if(Test-Path $p){[void]$paths.Add($p)}}
  $r='C:\Program Files\MySQL';if(Test-Path $r){Get-ChildItem $r -Directory -ErrorAction SilentlyContinue|ForEach-Object{$p=Join-Path $_.FullName 'bin\mysql.exe';if(Test-Path $p){[void]$paths.Add($p)}}}
  foreach($p in ($paths|Select-Object -Unique)){$x=Test-MySqlBinary $p;if($x){if($p -like "$MySqlRuntime*"){$x.Source='tarazpad-runtime'};return $x}};return $null
}
function Resolve-MySql{
  $found=Find-MySql84;if($found){Ok "Compatible MySQL $($found.Version) found ($($found.Source)); download/install skipped.";return $found}
  Ensure-VCRuntime
  $zip=Join-Path $CacheRoot 'mysql-8.4.11-winx64.zip';Download-File $MySqlUrl $zip 100000000
  Step 'Extracting MySQL 8.4.11 into Tarazpad runtime only...'
  $tmp=Join-Path $env:TEMP ('tarazpad-mysql-'+[guid]::NewGuid());New-Item $tmp -ItemType Directory -Force|Out-Null
  $tar=Get-Command tar.exe -ErrorAction SilentlyContinue;if($tar){& $tar.Source -xf $zip -C $tmp;if($LASTEXITCODE -ne 0){throw "MySQL extraction failed: $LASTEXITCODE"}}else{Expand-Archive $zip -DestinationPath $tmp -Force}
  $top=Get-ChildItem $tmp -Directory|Select-Object -First 1;if(!$top){throw 'Invalid MySQL archive.'}
  Remove-Item $MySqlRuntime -Recurse -Force -ErrorAction SilentlyContinue;New-Item $MySqlRuntime -ItemType Directory -Force|Out-Null
  Copy-Item (Join-Path $top.FullName '*') $MySqlRuntime -Recurse -Force;Remove-Item $tmp -Recurse -Force
  $mysql=Test-MySqlBinary (Join-Path $MySqlRuntime 'bin\mysql.exe');if(!$mysql){throw 'MySQL runtime validation failed.'};$mysql.Source='tarazpad-runtime';return $mysql
}
function Write-MySqlConfig($mysql,[int]$port){
  $base=$mysql.Base.Replace('\','/');$data=$MySqlData.Replace('\','/');$err=(Join-Path $LogRoot 'mysql-error.log').Replace('\','/');$bin=(Join-Path $DataRoot 'mysql-bin').Replace('\','/')
  @"
[mysqld]
basedir=$base
datadir=$data
port=$port
bind-address=127.0.0.1
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
server-id=1405
log-bin=$bin
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
function Ensure-Database{
  $existing=$null;if(Test-Path $ConfigPath){try{$existing=Get-Content $ConfigPath -Raw|ConvertFrom-Json}catch{}}
  $service=Get-Service $MySqlService -ErrorAction SilentlyContinue
  if($service -and $existing -and (Test-Path $existing.mysqlExe)){
    Ok 'Existing Tarazpad database instance found; database installation skipped.'
    if($service.Status -ne 'Running'){Start-Service $MySqlService;$service.WaitForStatus('Running','00:00:30')}
    return [pscustomobject]@{Mysql=$existing.mysqlExe;Mysqld=$existing.mysqldExe;Dump=$existing.mysqldumpExe;Base=$existing.mysqlBase;Version=$existing.mysqlVersion;Source=$existing.mysqlSource;Port=[int]$existing.mysqlPort;ExistingConfig=$existing}
  }
  $mysql=Resolve-MySql;New-Item $MySqlData -ItemType Directory -Force|Out-Null;$port=Find-FreePort 3307;Write-MySqlConfig $mysql $port
  if(!(Test-Path (Join-Path $MySqlData 'mysql'))){Step 'Initializing dedicated Tarazpad database...';& $mysql.Mysqld --defaults-file="$MyIni" --initialize-insecure;if($LASTEXITCODE -ne 0){throw "MySQL initialization failed: $LASTEXITCODE"}}else{Ok 'Existing Tarazpad MySQL data directory reused.'}
  if(!(Get-Service $MySqlService -ErrorAction SilentlyContinue)){& $mysql.Mysqld --install $MySqlService --defaults-file="$MyIni";if($LASTEXITCODE -ne 0){throw "MySQL service registration failed: $LASTEXITCODE"}}else{Ok 'TarazpadMySQL service already exists; skipped.'}
  $service=Get-Service $MySqlService;if($service.Status -ne 'Running'){Start-Service $MySqlService;$service.WaitForStatus('Running','00:00:30')}
  if(!(Wait-Tcp $port 90)){throw "MySQL did not become ready on port $port. See $LogRoot\mysql-error.log"}
  $rootSecret=New-Secret 48;$appSecret=New-Secret 48;$jwtSecret=New-Secret 72;$adminSecret=New-Secret 24
  $sql=@"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$($rootSecret.Replace("'","''"))';
CREATE DATABASE IF NOT EXISTS tarazpad CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY '$($appSecret.Replace("'","''"))';
ALTER USER 'tarazpad_app'@'127.0.0.1' IDENTIFIED BY '$($appSecret.Replace("'","''"))';
GRANT ALL PRIVILEGES ON tarazpad.* TO 'tarazpad_app'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
  $f=Join-Path $env:TEMP ('tarazpad-init-'+[guid]::NewGuid()+'.sql');$sql|Set-Content $f -Encoding utf8;Get-Content $f|& $mysql.Mysql --protocol=tcp --host=127.0.0.1 --port=$port --user=root --skip-password;$code=$LASTEXITCODE;Remove-Item $f -Force;if($code -ne 0){throw "Database bootstrap failed: $code"}
  Ok "Tarazpad MySQL ready on port $port.";return [pscustomobject]@{Mysql=$mysql.Mysql;Mysqld=$mysql.Mysqld;Dump=$mysql.Dump;Base=$mysql.Base;Version=$mysql.Version;Source=$mysql.Source;Port=$port;RootSecret=$rootSecret;AppSecret=$appSecret;JwtSecret=$jwtSecret;AdminSecret=$adminSecret}
}
function Install-App($node){
  Step 'Downloading current Tarazpad web application...'
  $zip=Join-Path $CacheRoot 'tarazpad-main.zip';Remove-Item $zip -Force -ErrorAction SilentlyContinue;Download-File $RepoZipUrl $zip 50000
  $tmp=Join-Path $env:TEMP ('tarazpad-app-'+[guid]::NewGuid());New-Item $tmp -ItemType Directory -Force|Out-Null;Expand-Archive $zip -DestinationPath $tmp -Force
  $src=Get-ChildItem $tmp -Directory|Select-Object -First 1;if(!$src){throw 'Invalid Tarazpad source archive.'}
  & schtasks.exe /End /TN $ServerTask 2>$null|Out-Null;Start-Sleep 2
  Remove-Item $AppRoot -Recurse -Force -ErrorAction SilentlyContinue;New-Item (Join-Path $AppRoot 'apps'),(Join-Path $AppRoot 'database') -ItemType Directory -Force|Out-Null
  Copy-Item (Join-Path $src.FullName 'apps\api') (Join-Path $AppRoot 'apps\api') -Recurse -Force
  Copy-Item (Join-Path $src.FullName 'apps\web') (Join-Path $AppRoot 'apps\web') -Recurse -Force
  Copy-Item (Join-Path $src.FullName 'database\*') (Join-Path $AppRoot 'database') -Recurse -Force
  Remove-Item $tmp -Recurse -Force
  Step 'Installing Tarazpad production packages...';Push-Location (Join-Path $AppRoot 'apps\api');& $node.Npm install --omit=dev --no-audit --no-fund;if($LASTEXITCODE -ne 0){Pop-Location;throw "npm install failed: $LASTEXITCODE"};Pop-Location
  Ok 'Tarazpad application files ready.'
}
function Write-ServiceScripts{
  $watch=@'
$ErrorActionPreference='Continue'
$root='C:\ProgramData\Tarazpad\server';$cfg=Get-Content (Join-Path $root 'config\server.json') -Raw|ConvertFrom-Json
$env:NODE_ENV='production';$env:PORT=[string]$cfg.webPort;$env:MYSQL_HOST=$cfg.mysqlHost;$env:MYSQL_PORT=[string]$cfg.mysqlPort;$env:MYSQL_DATABASE=$cfg.mysqlDatabase;$env:MYSQL_USER=$cfg.mysqlUser;$env:MYSQL_PASSWORD=$cfg.mysqlPassword;$env:JWT_SECRET=$cfg.jwtSecret;$env:TARAZPAD_ADMIN_EMAIL=$cfg.adminEmail;$env:TARAZPAD_ADMIN_PASSWORD=$cfg.adminPassword;$env:TARAZPAD_ADMIN_NAME=$cfg.adminName
$server=Join-Path $root 'app\apps\api\src\server.js';$log=Join-Path $root 'logs\server-watchdog.log'
while($true){"$(Get-Date -Format o) starting Tarazpad API"|Add-Content $log;& $cfg.nodeExe $server 2>&1|Tee-Object -FilePath (Join-Path $root 'logs\server.log') -Append;"$(Get-Date -Format o) server exited: $LASTEXITCODE; restart in 5 seconds"|Add-Content $log;Start-Sleep 5}
'@
  $watch|Set-Content (Join-Path $Root 'Watch-Tarazpad.ps1') -Encoding utf8
  $backup=@'
$ErrorActionPreference='Stop';$root='C:\ProgramData\Tarazpad\server';$cfg=Get-Content (Join-Path $root 'config\server.json') -Raw|ConvertFrom-Json;$dir=Join-Path $root 'backups';New-Item $dir -ItemType Directory -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$sql=Join-Path $dir "tarazpad-$stamp.sql";$zip=Join-Path $dir "tarazpad-$stamp.zip";$env:MYSQL_PWD=$cfg.mysqlPassword
& $cfg.mysqldumpExe --protocol=tcp --host=$cfg.mysqlHost --port=$cfg.mysqlPort --user=$cfg.mysqlUser --single-transaction --routines --triggers --events --default-character-set=utf8mb4 $cfg.mysqlDatabase|Set-Content $sql -Encoding utf8;Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
Compress-Archive $sql $zip -CompressionLevel Optimal -Force;Remove-Item $sql -Force;Get-ChildItem $dir -Filter 'tarazpad-*.zip'|Where-Object LastWriteTime -lt (Get-Date).AddDays(-30)|Remove-Item -Force
'@
  $backup|Set-Content (Join-Path $Root 'Backup-Tarazpad.ps1') -Encoding utf8
}

try{
  Step 'Checking existing prerequisites...'
  $node=Resolve-Node
  Ensure-VCRuntime
  $db=Ensure-Database
  Install-App $node
  if($db.ExistingConfig){$cfg=$db.ExistingConfig;$cfg.nodeExe=$node.Node;$cfg.nodeSource=$node.Source;$cfg.installerMode='online-bootstrap';$cfg.version='0.3.0'}
  else{$cfg=[ordered]@{version='0.3.0';installerMode='online-bootstrap';installedAt=(Get-Date).ToString('o');nodeExe=$node.Node;nodeSource=$node.Source;mysqlExe=$db.Mysql;mysqldExe=$db.Mysqld;mysqldumpExe=$db.Dump;mysqlBase=$db.Base;mysqlVersion=$db.Version;mysqlSource=$db.Source;mysqlHost='127.0.0.1';mysqlPort=$db.Port;mysqlDatabase='tarazpad';mysqlUser='tarazpad_app';mysqlPassword=$db.AppSecret;mysqlRootPassword=$db.RootSecret;jwtSecret=$db.JwtSecret;adminEmail='admin@tarazpad.local';adminPassword=$db.AdminSecret;adminName='مدیر سیستم';webPort=$WebPort}}
  $cfg|ConvertTo-Json -Depth 6|Set-Content $ConfigPath -Encoding utf8;& icacls $ConfigPath /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)'|Out-Null
  Write-ServiceScripts
  Step 'Configuring automatic startup and backup...'
  $taskCmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Root\Watch-Tarazpad.ps1`"";& schtasks.exe /Create /TN $ServerTask /SC ONSTART /RU SYSTEM /RL HIGHEST /TR $taskCmd /F|Out-Null
  $backupCmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Root\Backup-Tarazpad.ps1`"";& schtasks.exe /Create /TN $BackupTask /SC DAILY /ST 02:00 /RU SYSTEM /RL HIGHEST /TR $backupCmd /F|Out-Null
  if(-not(Get-NetFirewallRule -DisplayName 'Tarazpad ERP Web' -ErrorAction SilentlyContinue)){New-NetFirewallRule -DisplayName 'Tarazpad ERP Web' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $WebPort -Profile Domain,Private|Out-Null}
  & schtasks.exe /End /TN $ServerTask 2>$null|Out-Null;Start-Sleep 1;& schtasks.exe /Run /TN $ServerTask|Out-Null
  Step 'Running final health check...';$healthy=$false;for($i=0;$i -lt 90;$i++){try{$h=Invoke-RestMethod "http://127.0.0.1:$WebPort/api/health" -TimeoutSec 2;if($h.ok){$healthy=$true;break}}catch{};Start-Sleep 1};if(!$healthy){throw "Tarazpad health check failed. See $LogRoot"}
  $cred=Join-Path $Root 'INITIAL-LOGIN.txt';if(!(Test-Path $cred)){@"
Tarazpad ERP
URL: http://localhost:$WebPort
Email: $($cfg.adminEmail)
Password: $($cfg.adminPassword)
"@|Set-Content $cred -Encoding utf8;& icacls $cred /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)'|Out-Null}
  @" 
[InternetShortcut]
URL=http://localhost:$WebPort
"@|Set-Content ([IO.Path]::Combine([Environment]::GetFolderPath('CommonDesktopDirectory'),'Tarazpad ERP.url')) -Encoding ascii
  Ok 'Tarazpad ERP installed successfully.'
  Write-Host "URL: http://localhost:$WebPort" -ForegroundColor Green
  Write-Host "Login info: $cred" -ForegroundColor Green
  Write-Host 'Already-installed compatible prerequisites were not reinstalled.' -ForegroundColor Green
  if($env:TARAZPAD_SKIP_BROWSER -ne '1'){Start-Process "http://localhost:$WebPort"}
}catch{
  Write-Host "`n[TARAZPAD ERROR] $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Installer log: $Transcript" -ForegroundColor Yellow
  try{Stop-Transcript|Out-Null}catch{}
  exit 1
}
try{Stop-Transcript|Out-Null}catch{}
exit 0
