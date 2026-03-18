param(
    [string]$InstallerPath = '',
    [string]$InstallDirName = 'InfernaCore-SmokeTest',
    [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot

if ($Rebuild) {
    & (Join-Path $scriptRoot 'Build-Installer.ps1')
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "Build-Installer.ps1 failed with exit code $LASTEXITCODE"
    }
}

if (-not $InstallerPath) {
    $InstallerPath = Join-Path $repoRoot 'dist\InfernaCore-Setup.exe'
}

if (-not (Test-Path $InstallerPath)) {
    throw "Installer not found: $InstallerPath"
}

$installDir = Join-Path $env:LOCALAPPDATA $InstallDirName
$logsDir = Join-Path $repoRoot 'logs'
$installLog = Join-Path $logsDir 'install-smoke.log'
$uninstallLog = Join-Path $logsDir 'uninstall-smoke.log'

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "[SmokeTest] Installing to: $installDir"
Start-Process -FilePath $InstallerPath -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',"/DIR=$installDir", "/LOG=$installLog" -Wait

$exePath = Join-Path $installDir 'InfernaCore.exe'
$uninstallerPath = Join-Path $installDir 'unins000.exe'

$installDeadline = (Get-Date).AddSeconds(30)
while ((-not (Test-Path $exePath) -or -not (Test-Path $uninstallerPath)) -and (Get-Date) -lt $installDeadline) {
    Start-Sleep -Milliseconds 500
}

if (-not (Test-Path $exePath)) {
    throw "Install failed: InfernaCore.exe not found at $exePath"
}

if (-not (Test-Path $uninstallerPath)) {
    throw "Install failed: uninstaller not found at $uninstallerPath"
}

Write-Host "[SmokeTest] Install verification passed."
Write-Host "[SmokeTest] Running uninstall..."

Start-Process -FilePath $uninstallerPath -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=$uninstallLog" -Wait

$uninstallDeadline = (Get-Date).AddSeconds(30)
while ((Test-Path $installDir) -and (Get-Date) -lt $uninstallDeadline) {
    Start-Sleep -Milliseconds 500
}

if (Test-Path $installDir) {
    throw "Uninstall failed: install directory still exists at $installDir"
}

Write-Host "[SmokeTest] Uninstall verification passed."
Write-Host "[SmokeTest] Logs:"
Write-Host "  Install:   $installLog"
Write-Host "  Uninstall: $uninstallLog"
Write-Host "[SmokeTest] SUCCESS"

$metadataPath = Join-Path $scriptRoot 'AppMetadata.json'
$appVersion = ''
if (Test-Path $metadataPath) {
    try {
        $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
        $appVersion = [string]$metadata.appVersion
    }
    catch {
        $appVersion = ''
    }
}

$buildLogScript = Join-Path $scriptRoot 'Update-BuildLog.ps1'
if (Test-Path $buildLogScript) {
    try {
        & $buildLogScript `
            -Category 'Release' `
            -Title 'Installer smoke test passed' `
            -Version $appVersion `
            -Details "Install log: $installLog | Uninstall log: $uninstallLog"
    }
    catch {
        Write-Warning "Smoke test succeeded, but build log update failed: $($_.Exception.Message)"
    }
}
