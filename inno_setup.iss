[Setup]
AppName=Concorde EFB
AppVersion=3.1.10
DefaultDirName={autopf}\Concorde EFB
DefaultGroupName=Concorde EFB
UninstallDisplayIcon={app}\concorde_efb.exe
Compression=lzma2
SolidCompression=yes
OutputDir=build\windows
OutputBaseFilename=Concorde-EFB-Installer
ArchitecturesInstallIn64BitMode=x64
DisableWelcomePage=no
DisableDirPage=no

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Concorde EFB"; Filename: "{app}\concorde_efb.exe"
Name: "{autodesktop}\Concorde EFB"; Filename: "{app}\concorde_efb.exe"

[Run]
Filename: "{app}\concorde_efb.exe"; Description: "Launch Concorde EFB"; Flags: nowait postinstall skipifsilent
