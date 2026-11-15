; Inno Setup script for the Windows installer. CI passes the version and the
; folders: ISCC /DAppVersion=1.0.0 /DBuildDir=... /DOutputDir=... gem-hunters.iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build"
#endif

[Setup]
; Fixed id: upgrades replace the installed version instead of adding a second one.
AppId={{7B7C2E4A-3F5D-4C8B-9A61-2E8F0D5C4B19}
AppName=Gem Hunters: Tag & Trap
AppVersion={#AppVersion}
AppVerName=Gem Hunters {#AppVersion}
AppPublisher=Wennovate
DefaultDirName={autopf}\Wennovate\Gem Hunters
DefaultGroupName=Gem Hunters
DisableProgramGroupPage=yes
; Lets the player choose "only for me" (no admin rights) or all users.
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=..\..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=GemHunters-windows-x86_64-setup
SetupIconFile=..\..\icon.ico
UninstallDisplayIcon={app}\icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\GemHunters.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"
Source: "..\..\README.md"; DestDir: "{app}"
Source: "..\..\icon.ico"; DestDir: "{app}"

[Icons]
Name: "{group}\Gem Hunters"; Filename: "{app}\GemHunters.exe"; IconFilename: "{app}\icon.ico"
Name: "{group}\{cm:UninstallProgram,Gem Hunters}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Gem Hunters"; Filename: "{app}\GemHunters.exe"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\GemHunters.exe"; Description: "{cm:LaunchProgram,Gem Hunters}"; Flags: nowait postinstall skipifsilent
