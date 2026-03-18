; =============================================================================
;  InfernaCore — Inno Setup 6 Installer Script
;  Non-invasive: installs to user-space only, no admin rights required,
;  no background services, no telemetry, no network access.
; =============================================================================

#ifndef AppName
	#define AppName      "InfernaCore"
#endif
#ifndef AppVersion
	#define AppVersion   "1.0.0"
#endif
#ifndef AppPublisher
	#define AppPublisher "InfernaCore Contributors"
#endif
#ifndef AppURL
	#define AppURL       "https://github.com/beamtupgaming/infernacore"
#endif
#define ExeName      "InfernaCore.exe"

[Setup]
AppId={{F3A2C1D0-8B4E-4F7A-9E6C-2D5B0A3F1E8D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
AppPublisher={#AppPublisher}
AppCopyright=Copyright (C) 2026 InfernaCore Contributors

; ── Non-invasive: installs entirely inside the user's own AppData folder ──────
DefaultDirName={localappdata}\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=

; ── Registry uninstall key goes into HKCU (no elevation needed) ──────────────
UsedUserAreasWarning=no

; ── Minimal footprint ─────────────────────────────────────────────────────────
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableFinishedPage=no
DisableWelcomePage=no

; ── Legal / Privacy ───────────────────────────────────────────────────────────
LicenseFile=EULA.txt
InfoBeforeFile=PRIVACY.txt

; ── Appearance ────────────────────────────────────────────────────────────────
WizardStyle=modern
WizardSizePercent=120
SetupIconFile=..\Images\InfernaCore_icon.ico
UninstallDisplayIcon={app}\Images\InfernaCore_icon.ico
UninstallDisplayName={#AppName}

; ── Output ────────────────────────────────────────────────────────────────────
OutputDir=..\dist
OutputBaseFilename=InfernaCore-Setup
Compression=lzma2/ultra64
SolidCompression=yes

; ── Misc ──────────────────────────────────────────────────────────────────────
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Mod Manager
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";  Description: "Create a &desktop shortcut";  GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
; ── Main executable ───────────────────────────────────────────────────────────
Source: "..\{#ExeName}";                DestDir: "{app}";                          Flags: ignoreversion

; ── Mod source packages ───────────────────────────────────────────────────────
Source: "..\modpacks\*";                DestDir: "{app}\modpacks";                 Flags: ignoreversion recursesubdirs createallsubdirs

; ── Schema ────────────────────────────────────────────────────────────────────
Source: "..\schema\mod.schema.json";    DestDir: "{app}\schema";                   Flags: ignoreversion

; ── Icon / images ─────────────────────────────────────────────────────────────
Source: "..\Images\InfernaCore_icon.ico"; DestDir: "{app}\Images";                 Flags: ignoreversion

; ── PowerShell utilities (runtime scripts only — no build-time dev scripts) ───
Source: "..\tools\ModManager.ps1";          DestDir: "{app}\tools";                Flags: ignoreversion
Source: "..\tools\ModManagerStandalone.ps1"; DestDir: "{app}\tools";               Flags: ignoreversion

; ── Documentation ─────────────────────────────────────────────────────────────
Source: "..\README.md";                 DestDir: "{app}";                          Flags: ignoreversion
Source: "EULA.txt";                     DestDir: "{app}";                          Flags: ignoreversion

; ── Empty placeholder folders (created, not populated) ───────────────────────
; profiles/ and GameMods/ are created at runtime by the app

[Dirs]
; Ensure user-writable folders exist after install
Name: "{app}\profiles"
Name: "{app}\GameMods"

[Icons]
Name: "{group}\{#AppName}";            Filename: "{app}\{#ExeName}";  IconFilename: "{app}\Images\InfernaCore_icon.ico"
Name: "{group}\Uninstall {#AppName}";  Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}";    Filename: "{app}\{#ExeName}";  IconFilename: "{app}\Images\InfernaCore_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#ExeName}"; Description: "Launch {#AppName} now"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove the auto-created config and runtime folders on uninstall
Type: filesandordirs; Name: "{app}\GameMods"
Type: files;          Name: "{app}\config.json"
