[Setup]
; Fixed GUID identifying this app across versions -- lets Windows/Inno treat
; upgrades as "replace the same install" (correct Add/Remove Programs entry,
; no duplicate listings) instead of a fresh unrelated install each release.
AppId={{25A23A2B-BFFC-42AF-A327-231690CD630F}
AppName=Concorde EFB
AppVersion=3.4.2
AppPublisher=Ray
AppPublisherURL=https://dwaipayanray95.github.io/Concorde-EFB/
AppSupportURL=https://dwaipayanray95.github.io/Concorde-EFB/changelog/
AppUpdatesURL=https://dwaipayanray95.github.io/Concorde-EFB/changelog/
DefaultDirName={autopf}\Concorde EFB
DefaultGroupName=Concorde EFB
UninstallDisplayIcon={app}\concorde_efb.exe
UninstallDisplayName=Concorde EFB
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
Name: "{group}\Uninstall Concorde EFB"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Concorde EFB"; Filename: "{app}\concorde_efb.exe"

[Run]
Filename: "{app}\concorde_efb.exe"; Description: "Launch Concorde EFB"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; The app writes recordings/settings next to the exe (see
; FlightRecorderService/TrimTankFuel etc. -- lib/core/... on Windows this is
; the install folder itself, chosen specifically to avoid Windows Defender's
; Controlled Folder Access on Documents). Inno's default uninstall only
; removes files IT installed, so these runtime-created files/folders would
; otherwise survive an uninstall -- clean them up explicitly.
Type: filesandordirs; Name: "{app}\concorde_efb\flights"
Type: files; Name: "{app}\concorde_efb\flights_index.json"
