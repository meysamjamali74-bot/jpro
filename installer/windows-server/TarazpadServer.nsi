Unicode True
RequestExecutionLevel admin
SetCompressor zlib
!include "LogicLib.nsh"

!define APPNAME "Tarazpad ERP Web Server"
!define VERSION "0.2.0"

Name "${APPNAME}"
Caption "${APPNAME} ${VERSION}"
OutFile "build\Tarazpad-ERP-Web-Server-Setup-${VERSION}.exe"
InstallDir "$WINDIR\..\ProgramData\Tarazpad\server"
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "0.2.0.0"
VIAddVersionKey "ProductName" "Tarazpad ERP Web Server"
VIAddVersionKey "FileDescription" "Tarazpad ERP native Windows web server installer"
VIAddVersionKey "CompanyName" "Tarazpad"
VIAddVersionKey "FileVersion" "0.2.0"
VIAddVersionKey "ProductVersion" "0.2.0"

Function .onInit
  ReadEnvStr $0 "ProgramData"
  ${If} $0 != ""
    StrCpy $INSTDIR "$0\Tarazpad\server"
  ${EndIf}
FunctionEnd

Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install Tarazpad ERP Server" SEC_MAIN
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  DetailPrint "Extracting Tarazpad server payload..."
  SetCompress auto
  File /r /x prereqs "build\staging\*"
  SetOutPath "$INSTDIR\prereqs"
  SetCompress off
  File /r "build\staging\prereqs\*"
  SetCompress auto
  SetOutPath "$INSTDIR"

  DetailPrint "Detecting prerequisites and configuring server..."
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\Install-TarazpadServer.ps1"' $0
  ${If} $0 != 0
    IfSilent silent_install_error interactive_install_error
    interactive_install_error:
      MessageBox MB_ICONSTOP|MB_OK "Tarazpad setup stopped with error code $0.$\r$\nSee C:\ProgramData\Tarazpad\server\logs for details."
    silent_install_error:
      SetErrorLevel $0
      Quit
  ${EndIf}

  ; HARD_CLOSED is always enforced by the application guard. On the dedicated
  ; Windows MySQL instance we also attempt defense-in-depth triggers, but their
  ; installation must not invalidate an otherwise healthy/idempotent setup.
  ; This preserves compatibility with existing installations and restricted
  ; MySQL configurations while still attempting the stronger native guard.
  DetailPrint "Installing optional accounting HARD_CLOSED database guards..."
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\Install-DatabaseGuards.ps1"' $1
  ${If} $1 != 0
    DetailPrint "WARNING: Optional database guards returned code $1; application HARD_CLOSED guard remains active."
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
