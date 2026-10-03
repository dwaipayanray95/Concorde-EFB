; Passed by CI: ISCC /DAppVer=5.5.2 /DBuildDir=Release /DOutName=ConcordeEFB_v5.5.2_release_windows
;   AppVer   - version from pubspec.yaml
;   BuildDir - Flutter output folder: Debug, Profile or Release
;   OutName  - installer file name without .exe
#ifndef AppVer
  #define AppVer "0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "Release"
#endif
#ifndef OutName
  #define OutName "Concorde-EFB-Installer"
#endif

[Setup]
; Fixed GUID identifying this app across versions -- lets Windows/Inno treat
; upgrades as "replace the same install" (correct Add/Remove Programs entry,
; no duplicate listings) instead of a fresh unrelated install each release.
AppId={{25A23A2B-BFFC-42AF-A327-231690CD630F}
AppName=Concorde EFB
AppVersion={#AppVer}
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
OutputBaseFilename={#OutName}
ArchitecturesInstallIn64BitMode=x64
DisableWelcomePage=no
DisableDirPage=no

[Files]
Source: "build\windows\x64\runner\{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Concorde EFB"; Filename: "{app}\concorde_efb.exe"
Name: "{group}\Uninstall Concorde EFB"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Concorde EFB"; Filename: "{app}\concorde_efb.exe"

[Run]
Filename: "{app}\concorde_efb.exe"; Description: "Launch Concorde EFB"; Flags: nowait postinstall skipifsilent

[InstallDelete]
; Clean install/update: remove everything from the previous version first so
; renamed/removed DLLs, assets and old bridge builds can't linger and break the
; new one. User settings are NOT in {app}: they live in
; %APPDATA%\com.dwaipayanray95\concorde_efb (SharedPreferences), so they
; survive. The airport-DB cache is under %LOCALAPPDATA%, also untouched. The
; app never writes into {app} (Program Files is read-only without admin). The
; Check guards against the user having picked an unrelated
; non-empty folder on the directory page -- we only wipe a real prior install.
Type: filesandordirs; Name: "{app}\*"; Check: IsExistingInstall

[UninstallDelete]
; Remove the whole install folder (Inno only removes files it installed, so
; leftovers from older versions would survive). Settings in %APPDATA% are
; deliberately left in place so a reinstall keeps them.
Type: filesandordirs; Name: "{app}"

[Code]
function IsExistingInstall: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\concorde_efb.exe'));
end;
