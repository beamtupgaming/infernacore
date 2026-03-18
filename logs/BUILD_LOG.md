# InfernaCore Build Log

## Auto-Logging Criteria
- Automatic entries are appended by `tools/Update-BuildLog.ps1`.
- A change is logged when one of these scripts completes successfully:
	- `tools/Sync-Metadata.ps1`
	- `tools/Build-ModManagerApp.ps1`
	- `tools/Build-Installer.ps1`
	- `tools/Smoke-TestInstaller.ps1`
- Failed runs are not logged as success entries.

## Step-by-Step Build History (Chronological)

### Technical Changes
1. Created/organized core workspace structure (`modpacks/`, `schema/`, `tools/`, `profiles/`, `GameMods/`).
2. Kept a working reference mod (`Example_HelloMod`) and schema file for pack validation.
3. Implemented and iterated `tools/ModManagerApp.cs` for mod-management workflow.
4. Added executable build script `tools/Build-ModManagerApp.ps1` with output target `InfernaCore.exe`.
5. Added Inno Setup script `tools/InfernaCore.iss` with non-invasive user-scope install defaults.
6. Added installer automation script `tools/Build-Installer.ps1`.
7. Added metadata source `tools/AppMetadata.json` and sync script `tools/Sync-Metadata.ps1`.
8. Added icon packaging for app and installer (`Images/InfernaCore_icon.ico`).
9. Included legal/privacy assets in installer (`tools/EULA.txt`, `tools/PRIVACY.txt`).
10. Updated installer payload set: app binary, modpacks, schema, scripts, docs, runtime folders.
11. Fixed metadata/EULA sync behavior to prevent invalid effective-date text propagation.
12. Normalized EULA text artifacts (encoding/mojibake cleanup in active sections).
13. Added reusable smoke test runner `tools/Smoke-TestInstaller.ps1`.
14. Created centralized `logs/` directory and updated smoke script output paths.

### Release Changes
15. Established release/distribution target: standalone manager executable plus Windows installer.
16. Wired metadata sync to update README/EULA version and project URL before build.
17. Rebuilt and validated installer successfully (`dist/InfernaCore-Setup.exe`).
18. Performed silent install/uninstall smoke test and confirmed complete cleanup.
19. Moved existing build/smoke logs under `logs/` and re-ran smoke tests with new paths.
20. Reverted project version from `1.0.1` back to `1.0.0` in metadata and installer defaults.
21. Synced docs from metadata to align README/EULA at version `1.0.0`.
22. Recompiled app and installer successfully for baseline release state.

## Build 0001 - Initial Baseline
- Date: 2026-03-17
- Version: 1.0.0
- Status: Success

### Commands Run
- `./tools/Sync-Metadata.ps1`
- `./tools/Build-Installer.ps1`

### Outputs
- `InfernaCore.exe` (repo root)
- `dist/InfernaCore-Setup.exe`

### Notes
- Metadata and docs synced from `tools/AppMetadata.json`.
- Installer compiled with Inno Setup 6.7.1 in non-admin user-mode configuration.

## Automated Change Entries

### [2026-03-17 21:11:35] Release - Metadata sync completed
- Version: 1.0.0
- Details: Updated README metadata block and EULA version header.

### [2026-03-17 21:11:35] Technical - App executable build succeeded
- Version: 1.0.0
- Details: Output: C:\Users\blade\OneDrive\Desktop\InfernaCore\InfernaCore.exe

### [2026-03-17 21:11:37] Release - Installer build succeeded
- Version: 1.0.0
- Details: Output: C:\Users\blade\OneDrive\Desktop\InfernaCore\dist\InfernaCore-Setup.exe


