Unicode True
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!define APPNAME "Tarazpad ERP Web Server"
!define VERSION "0.2.0"

Name "${APPNAME}"
Caption "${APPNAME} ${VERSION}"
OutFile "build\Tarazpad-ERP-Web-Server-Setup-${VERSION}.exe"
InstallDir "$PROGRAMDATA\Tarazpad\server"
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "0.2.0.0"
VIAddVersionKey "ProductName" "Tarazpad ERP Web Server"
VIAddVersionKey "FileDescription" "Tarazpad ERP native Windows web server installer"
VIAddVersionKey "CompanyName" "Tarazpad"
VIAddVersionKey "FileVersion" "0.2.0"
VIAddVersionKey "ProductVersion" "0.2.0"

Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install Tarazpad ERP Server" SEC_MAIN
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  DetailPrint "Extracting Tarazpad server payload..."
  File /r "build\staging\*"

  DetailPrint "Detecting prerequisites and configuring server..."
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\Install-TarazpadServer.ps1"' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP|MB_OK "Tarazpad setup stopped with error code $0.$\r$\nSee C:\ProgramData\Tarazpad\server\logs for details."
    Abort
  ${EndIf}

  WriteUninstaller "$INSTDIR\Uninstall-TarazpadServer.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERPServer" "DisplayName" "Tarazpad ERP Web Server"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERPServer" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERPServer" "Publisher" "Tarazpad"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERPServer" "UninstallString" '"$INSTDIR\Uninstall-TarazpadServer.exe"'
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  DetailPrint "Stopping Tarazpad scheduled tasks..."
  nsExec::ExecToLog 'schtasks.exe /End /TN "Tarazpad ERP Server"'
  nsExec::ExecToLog 'schtasks.exe /Delete /TN "Tarazpad ERP Server" /F'
  nsExec::ExecToLog 'schtasks.exe /Delete /TN "Tarazpad ERP Daily Backup" /F'
  Delete "$COMMONDESKTOP\Tarazpad ERP.lnk"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERPServer"
  MessageBox MB_ICONINFORMATION|MB_OK "Tarazpad application startup has been removed. Database, configuration, MySQL instance and backups are intentionally retained in C:\ProgramData\Tarazpad\server to protect accounting data."
SectionEnd
