# InfernaCore

A pre-launch mod manager for Into The Flames.
It deploys Lua mods through the game's official Mods folder only (no injection, no hooking).

---

<!-- METADATA:START -->
- Current version: 1.0.0
- Publisher: InfernaCore Contributors
- Project URL: https://github.com/beamtupgaming/infernacore
<!-- METADATA:END -->

## Table of Contents

- [Folder Layout](#folder-layout)
- [Getting Started](#getting-started)
- [Installer (Recommended)](#installer-recommended)
- [Using InfernaCore.exe](#using-infernacoreexe)
- [Command-Line Usage](#command-line-usage)
- [Included Mods](#included-mods)
- [Creating a New Mod](#creating-a-new-mod)
- [Troubleshooting](#troubleshooting)
- [Privacy & Legal](#privacy--legal)

## Folder Layout

```text
InfernaCore/
|-- InfernaCore.exe
|-- dist/
|   `-- InfernaCore-Setup.exe
|-- config.json
|-- modpacks/
|   |-- AITrafficFix/
|   `-- Example_HelloMod/
|-- profiles/
|-- schema/
|   `-- mod.schema.json
|-- GameMods/
`-- tools/
    |-- AppMetadata.json
    |-- Build-Installer.ps1
    |-- Build-ModManagerApp.ps1
    |-- InfernaCore.iss
    |-- ModManager.ps1
    |-- ModManagerStandalone.ps1
    |-- ModManagerApp.cs
    |-- EULA.txt
    `-- PRIVACY.txt
```

## Getting Started

1. Run `InfernaCore.exe`.
2. Set your game install path.
3. Select mods to load.
4. Click **Start Game With Selected Mods**.

## Installer (Recommended)

- Installer file: `dist/InfernaCore-Setup.exe`
- Default path: `%LOCALAPPDATA%\InfernaCore`
- Scope: current user (HKCU uninstall)
- No admin rights required by default

### Build installer

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\Build-Installer.ps1
```

This command now also auto-syncs `README.md` and `tools/EULA.txt` from `tools/AppMetadata.json` for future updates.

## Using InfernaCore.exe

- Configure `Game Install Path` and `Mods Folder`
- Add/remove mods from `modpacks/`
- Enable/disable selected mods
- Check `Load On Launch` for desired mods
- Launch via `Start Game With Selected Mods`

## Command-Line Usage

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\ModManager.ps1 validate
.\tools\ModManager.ps1 list
.\tools\ModManager.ps1 enable ai_traffic_fix -GameModsPath "D:\SteamLibrary\steamapps\common\Into The Flames\Mods"
.\tools\ModManager.ps1 disable ai_traffic_fix -GameModsPath "D:\SteamLibrary\steamapps\common\Into The Flames\Mods"
```

## Included Mods

### AITrafficFix

- Mod ID: `ai_traffic_fix`
- Source: `modpacks/AITrafficFix/`
- Entry: `scripts/main.lua`
- Purpose: smoother braking, better emergency yielding, safer scene-vehicle avoidance

## Creating a New Mod

1. Copy `modpacks/Example_HelloMod/`
2. Edit `mod.json`
3. Implement logic in `scripts/main.lua`
4. Open `InfernaCore.exe` and test

## Troubleshooting

- Script execution blocked:
  - Run `Set-ExecutionPolicy -Scope Process Bypass`
- Mod ID not found:
  - Run `.\tools\ModManager.ps1 list`
- Mod has no in-game effect:
  - Verify your real game `Mods` folder path

## Privacy & Legal

- No telemetry or analytics
- No background services
- Local configuration only (`config.json`)
- Full legal terms: `tools/EULA.txt`
- Privacy summary: `tools/PRIVACY.txt`
