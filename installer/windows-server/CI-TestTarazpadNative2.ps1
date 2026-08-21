#requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$setup=Join-Path $PSScriptRoot 'build\Tarazpad-ERP-Native-Windows-Setup-2.0.0.exe'
if(!(Test-Path $setup)){throw "Setup not found: $setup"}

function Wait-Health([int]$seconds=90){
  for($i=0;$i -lt $seconds;$i++){
    try{ $h=Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -TimeoutSec 2; if($h.ok){return $true} }catch{}
    Start-Sleep 1
  }
  return $false
}
function Read-InitialLogin([string]$path){
  $text=Get-Content $path -Raw
  $email=[regex]::Match($text,'(?im)^Email:\s*(.+)$').Groups[1].Value.Trim()
  $password=[regex]::Match($text,'(?im)^Password:\s*(.+)$').Groups[1].Value.Trim()
  if(!$email -or !$password){throw 'Initial login file could not be parsed.'}
  return @{email=$email;password=$password}
}

Write-Host '=== Tarazpad Native 2.0 first installation ===' -ForegroundColor Cyan
$p=Start-Process $setup -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){throw "Native setup failed: $($p.ExitCode)"}

$desktop='C:\Program Files\Tarazpad\Tarazpad.Desktop.exe'
$serverConfig='C:\ProgramData\Tarazpad\server\config\server.json'
$loginFile='C:\ProgramData\Tarazpad\server\INITIAL-LOGIN.txt'
$clientConfig='C:\ProgramData\Tarazpad\client\client.json'
$shortcut=Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Tarazpad ERP.lnk'
foreach($f in @($desktop,$serverConfig,$loginFile,$clientConfig,$shortcut)){if(!(Test-Path $f)){throw "Expected installed artifact missing: $f"}}

if(!(Wait-Health 90)){throw 'Tarazpad internal API did not become healthy.'}
$login=Read-InitialLogin $loginFile
$session=Invoke-RestMethod 'http://127.0.0.1:8080/api/auth/login' -Method Post -ContentType 'application/json' -Body ($login|ConvertTo-Json) -TimeoutSec 10
if(!$session.token){throw 'Login smoke test did not return a token.'}
$headers=@{Authorization="Bearer $($session.token)"}
$runtime=Invoke-RestMethod 'http://127.0.0.1:8080/api/system/runtime' -Headers $headers -TimeoutSec 10
if($runtime.mode -ne 'OFFLINE_LAN' -or $runtime.database -ne 'MySQL' -or $runtime.internetRequired -ne $false){throw "Unexpected runtime descriptor: $($runtime|ConvertTo-Json -Compress)"}

$wsh=New-Object -ComObject WScript.Shell
$link=$wsh.CreateShortcut($shortcut)
if($link.TargetPath -ne $desktop){throw "Desktop shortcut is not native. Target: $($link.TargetPath)"}
if($link.Arguments -match '^https?://'){throw 'Desktop shortcut still contains a browser URL.'}
$client=Get-Content $clientConfig -Raw|ConvertFrom-Json
if($client.ServerUrl -ne 'http://127.0.0.1:8080'){throw 'Standalone client default server URL is incorrect.'}

Write-Host 'Launching WPF executable for process-level smoke test...' -ForegroundColor Cyan
$app=Start-Process $desktop -PassThru
Start-Sleep 5
if($app.HasExited){throw "Native WPF client exited during launch smoke test with code $($app.ExitCode)."}
Stop-Process -Id $app.Id -Force

$configHash=(Get-FileHash $serverConfig -Algorithm SHA256).Hash
$loginHash=(Get-FileHash $loginFile -Algorithm SHA256).Hash
Write-Host '=== Tarazpad Native 2.0 second installation / idempotency ===' -ForegroundColor Cyan
$p2=Start-Process $setup -ArgumentList '/S' -Wait -PassThru
if($p2.ExitCode -ne 0){throw "Second setup run failed: $($p2.ExitCode)"}
if(!(Wait-Health 60)){throw 'API unhealthy after second setup run.'}
if((Get-FileHash $serverConfig -Algorithm SHA256).Hash -ne $configHash){throw 'server.json changed during reinstall; secrets/config were not preserved.'}
if((Get-FileHash $loginFile -Algorithm SHA256).Hash -ne $loginHash){throw 'Initial login credentials changed during reinstall.'}
$link2=$wsh.CreateShortcut($shortcut)
if($link2.TargetPath -ne $desktop){throw 'Native shortcut regressed after reinstall.'}
Write-Host 'Tarazpad Native 2.0 installer smoke test PASSED.' -ForegroundColor Green
