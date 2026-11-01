#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define BundleSource "..\..\build\windows\x64\runner\Release"
#define InstallerOutput "..\..\build\installers"

[Setup]
AppId={{A7A014BE-8027-4334-9636-B300C158D5FC}
AppName=Tamba IPTV
AppVersion={#AppVersion}
AppPublisher=Tamba IPTV
DefaultDirName={localappdata}\Programs\Tamba IPTV
DefaultGroupName=Tamba IPTV
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir={#InstallerOutput}
OutputBaseFilename=Tamba-IPTV-Windows-{#AppVersion}-Setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\filimu_plus.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#BundleSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Tamba IPTV"; Filename: "{app}\filimu_plus.exe"
Name: "{autodesktop}\Tamba IPTV"; Filename: "{app}\filimu_plus.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\filimu_plus.exe"; Description: "Launch Tamba IPTV"; Flags: postinstall nowait skipifsilent
