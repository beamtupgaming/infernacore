param(
    [string]$IsccPath = '',
    [string]$IssPath = ''
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot
$metadataPath = Join-Path $scriptRoot 'AppMetadata.json'

if (-not $IssPath) {
    $IssPath = Join-Path $scriptRoot 'InfernaCore.iss'
}

if (-not $IsccPath) {
    $candidates = @(
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Inno Setup 6\ISCC.exe')
    )

    $IsccPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
    throw 'ISCC.exe not found. Install Inno Setup 6, or pass -IsccPath "<full path to ISCC.exe>".'
}

if (-not (Test-Path $IssPath)) {
    throw "Installer script not found: $IssPath"
}

if (-not (Test-Path $metadataPath)) {
    throw "Metadata file not found: $metadataPath"
}

$metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
$appName = [string]$metadata.appName
$appVersion = [string]$metadata.appVersion
$appPublisher = [string]$metadata.appPublisher
$appUrl = [string]$metadata.appUrl

if ([string]::IsNullOrWhiteSpace($appName)) { $appName = 'InfernaCore' }
if ([string]::IsNullOrWhiteSpace($appVersion)) { $appVersion = '1.0.0' }
if ([string]::IsNullOrWhiteSpace($appPublisher)) { $appPublisher = 'InfernaCore Contributors' }
if ([string]::IsNullOrWhiteSpace($appUrl)) { $appUrl = 'https://github.com/beamtupgaming/infernacore' }

$buildAppScript = Join-Path $scriptRoot 'Build-ModManagerApp.ps1'
if (-not (Test-Path $buildAppScript)) {
    throw "App build script not found: $buildAppScript"
}

$syncScript = Join-Path $scriptRoot 'Sync-Metadata.ps1'
if (-not (Test-Path $syncScript)) {
    throw "Metadata sync script not found: $syncScript"
}

Write-Host 'Syncing README and EULA from AppMetadata.json...'
& $syncScript

Write-Host 'Building InfernaCore.exe...'
& $buildAppScript `
    -SourcePath (Join-Path $scriptRoot 'ModManagerApp.cs') `
    -OutputPath (Join-Path $repoRoot 'InfernaCore.exe')
if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
    throw "Build-ModManagerApp.ps1 failed with exit code $LASTEXITCODE"
}

Write-Host "Compiling installer with: $IsccPath"
Push-Location $scriptRoot
try {
    $isccArgs = @(
        "/DAppName=$appName",
        "/DAppVersion=$appVersion",
        "/DAppPublisher=$appPublisher",
        "/DAppURL=$appUrl",
        $IssPath
    )

    & $IsccPath @isccArgs
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "ISCC failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$distDir = Join-Path $repoRoot 'dist'
if (-not (Test-Path $distDir)) {
    throw "Expected output folder not found: $distDir"
}

$installer = Get-ChildItem -Path $distDir -Filter 'InfernaCore-Setup*.exe' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $installer) {
    throw "Installer .exe was not found in $distDir"
}

Write-Host "Installer built: $($installer.FullName)"

$rootInstallerPath = Join-Path $repoRoot 'InfernaCore-Setup.exe'
Copy-Item -Path $installer.FullName -Destination $rootInstallerPath -Force
Write-Host "Installer copied to root: $rootInstallerPath"

$buildLogScript = Join-Path $scriptRoot 'Update-BuildLog.ps1'
if (Test-Path $buildLogScript) {
    try {
        & $buildLogScript `
            -Category 'Release' `
            -Title 'Installer build succeeded' `
            -Version $appVersion `
            -Details "Output: $($installer.FullName) | Root copy: $rootInstallerPath"
    }
    catch {
        Write-Warning "Installer build succeeded, but build log update failed: $($_.Exception.Message)"
    }
}
