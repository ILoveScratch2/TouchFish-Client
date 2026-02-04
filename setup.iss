; ==================================================
#define AppVersion "0.0.1"
#define BuildNumber "1"
; ==================================================

#define FullVersion AppVersion + "." + BuildNumber

[Setup]
AppName=TouchFish Client
AppVersion={#AppVersion}
AppPublisher=ILoveScratch2
AppPublisherURL=https://ilovescratch.us.ci
AppSupportURL=https://github.com/ILoveScratch2/TouchFish-Client/issues
AppUpdatesURL=https://github.com/ILoveScratch2/TouchFish-Client/releases
AppCopyright=Copyright © 2026 ILoveScratch2
VersionInfoVersion={#FullVersion}
UninstallDisplayName=TouchFish Client
UninstallDisplayIcon={app}\touchfish_client.exe

DefaultDirName={commonpf}\TouchFish
UsePreviousAppDir=no

OutputDir=.\Installer
OutputBaseFilename=windows-x86_64-setup
SetupIconFile=.\windows\runner\resources\app_icon.ico

Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=4

ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin

[Files]
Source: ".\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\TouchFish Client"; Filename: "{app}\touchfish_client.exe";IconFilename: "{app}\touchfish_client.exe"
Name: "{group}\{cm:UninstallProgram,TouchFish Client}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\TouchFish Client"; Filename: "{app}\touchfish_client.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\touchfish_client.exe"; Description: "Launch TF"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\ILoveScratch2\TouchFish Client"
Type: files; Name: "{group}\TouchFish Client.lnk" ;
Type: files; Name: "{autodesktop}\TouchFish Client.lnk" ;
