Unicode True
RequestExecutionLevel admin
SetCompressor zlib
!include "LogicLib.nsh"

!define APPNAME "Tarazpad ERP Native Windows"
!define VERSION "2.0.0"

Name "${APPNAME}"
Caption "${APPNAME} ${VERSION}"
OutFile "build\Tarazpad-ERP-Native-Windows-Setup-${VERSION}.exe"
InstallDir "$PROGRAMFILES64\Tarazpad"
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "2.0.0.0"
VIAddVersionKey "ProductName" "Tarazpad ERP Native Windows"
VIAddVersionKey "FileDescription" "Tarazpad ERP native Windows desktop and internal server installer"
VIAddVersionKey "CompanyName" "Tarazpad"
VIAddVersionKey "FileVersion" "2.0.0"
VIAddVersionKey "ProductVersion" "2.0.0"

Var ServerRoot

Function .onInit
  ReadEnvStr $0 "ProgramData"
  ${If} $0 == ""
    StrCpy $0 "$WINDIR\..\ProgramData"
  ${EndIf}
  StrCpy $ServerRoot "$0\Tarazpad\server"
FunctionEnd

Page components
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Tarazpad Desktop Client (required)" SEC_DESKTOP
  SectionIn RO
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  SetOverwrite on
  File /r "build\staging\desktop\*"

  SetOutPath "$ServerRoot"
  File "build\staging\Configure-TarazpadNative.ps1"

  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$ServerRoot\Configure-TarazpadNative.ps1" -DesktopExe "$INSTDIR\Tarazpad.Desktop.exe"' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP|MB_OK "Tarazpad native client configuration failed with error code $0."
    SetErrorLevel $0
    Quit
  ${EndIf}

  WriteUninstaller "$INSTDIR\Uninstall-Tarazpad.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP" "DisplayName" "Tarazpad ERP Native Windows"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP" "Publisher" "Tarazpad"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP" "DisplayIcon" "$INSTDIR\Tarazpad.Desktop.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP" "UninstallString" '"$INSTDIR\Uninstall-Tarazpad.exe"'
SectionEnd

Section "Internal Server + MySQL (recommended for main PC/server)" SEC_SERVER
  SetShellVarContext all
  DetailPrint "Installing Tarazpad internal API and MySQL..."
  SetOutPath "$ServerRoot"
  SetCompress auto
  SetOverwrite on
  File /r "build\staging\app"
  File "build\staging\Install-TarazpadServer.ps1"
  File "build\staging\Install-DatabaseGuards.ps1"
  File "build\staging\HardClose-DatabaseGuards.sql"
  File "build\staging\BUILD-INFO.txt"

  SetOutPath "$ServerRoot\runtime"
  SetOverwrite off
  File "build\staging\runtime\node.exe"
  SetOverwrite on

  SetOutPath "$ServerRoot\prereqs"
  SetCompress off
  File /r "build\staging\prereqs\*"
  SetCompress auto
  SetOutPath "$ServerRoot"

  ; The server bootstrap still contains a compatibility browser launch for the old
  ; 1.x installer. Set the inherited CI flag in this NSIS process so the child
  ; PowerShell process suppresses that launch. The desktop EXE remains the only UI.
  System::Call 'Kernel32::SetEnvironmentVariableW(w "GITHUB_ACTIONS", w "true") i .r0'
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$ServerRoot\Install-TarazpadServer.ps1"' $1
  ${If} $1 != 0
    MessageBox MB_ICONSTOP|MB_OK "Tarazpad internal server setup failed with error code $1.$\r$\nSee C:\ProgramData\Tarazpad\server\logs."
    SetErrorLevel $1
    Quit
  ${EndIf}

  DetailPrint "Installing accounting HARD_CLOSED database guards..."
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$ServerRoot\Install-DatabaseGuards.ps1"' $2
  ${If} $2 != 0
    MessageBox MB_ICONSTOP|MB_OK "Database guard setup failed with error code $2."
    SetErrorLevel $2
    Quit
  ${EndIf}

  ; Ensure any legacy shortcut is replaced with the native WPF application.
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$ServerRoot\Configure-TarazpadNative.ps1" -DesktopExe "$INSTDIR\Tarazpad.Desktop.exe"' $3
  ${If} $3 != 0
    SetErrorLevel $3
    Quit
  ${EndIf}
SectionEnd

Section -Launch
  IfSilent done
  Exec '"$INSTDIR\Tarazpad.Desktop.exe"'
  done:
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  nsExec::ExecToLog 'schtasks.exe /End /TN "Tarazpad ERP Server"'
  nsExec::ExecToLog 'schtasks.exe /Delete /TN "Tarazpad ERP Server" /F'
  nsExec::ExecToLog 'schtasks.exe /Delete /TN "Tarazpad ERP Daily Backup" /F'
  Delete "$COMMONDESKTOP\Tarazpad ERP.lnk"
  RMDir /r "$COMMONPROGRAMS\Tarazpad"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TarazpadERP"
  MessageBox MB_ICONINFORMATION|MB_OK "Tarazpad Desktop removed. Accounting database, configuration and backups remain in C:\ProgramData\Tarazpad\server to protect financial records."
SectionEnd
