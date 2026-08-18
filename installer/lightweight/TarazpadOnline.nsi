Unicode True
RequestExecutionLevel admin
SetCompressor /SOLID lzma
!include "LogicLib.nsh"

!define APPNAME "Tarazpad ERP Web Installer"
!define VERSION "0.3.0"

Name "${APPNAME}"
Caption "${APPNAME} ${VERSION}"
OutFile "build\Tarazpad-ERP-Web-Setup-Light-${VERSION}.exe"
InstallDir "$PROGRAMFILES64\Tarazpad\Bootstrap"
ShowInstDetails show

VIProductVersion "0.3.0.0"
VIAddVersionKey "ProductName" "Tarazpad ERP Web Installer"
VIAddVersionKey "FileDescription" "Lightweight prerequisite-aware Tarazpad ERP web installer"
VIAddVersionKey "CompanyName" "Tarazpad"
VIAddVersionKey "FileVersion" "0.3.0"
VIAddVersionKey "ProductVersion" "0.3.0"

Page instfiles

Section "Install Tarazpad ERP" SEC_MAIN
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  File "Install-TarazpadOnline.ps1"
  File "Run-TarazpadOnline.ps1"
  DetailPrint "Checking installed prerequisites and installing Tarazpad..."
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\Run-TarazpadOnline.ps1"' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP|MB_OK "Tarazpad installation failed with error code $0.$\r$\nSee C:\ProgramData\Tarazpad\server\logs for the installer log."
    SetErrorLevel $0
    Quit
  ${EndIf}
  MessageBox MB_ICONINFORMATION|MB_OK "Tarazpad ERP is ready.$\r$\nOpen http://localhost:8080 or use the desktop shortcut."
SectionEnd
