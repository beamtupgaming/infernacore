param(
    [string]$MetadataPath = '',
    [string]$ReadmePath = '',
    [string]$EulaPath = ''
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot

if (-not $MetadataPath) { $MetadataPath = Join-Path $scriptRoot 'AppMetadata.json' }
if (-not $ReadmePath)   { $ReadmePath   = Join-Path $repoRoot 'README.md' }
if (-not $EulaPath)     { $EulaPath     = Join-Path $scriptRoot 'EULA.txt' }

if (-not (Test-Path $MetadataPath)) { throw "Metadata file not found: $MetadataPath" }
if (-not (Test-Path $ReadmePath))   { throw "README not found: $ReadmePath" }
if (-not (Test-Path $EulaPath))     { throw "EULA not found: $EulaPath" }

$meta = Get-Content -Path $MetadataPath -Raw | ConvertFrom-Json
$appName = [string]$meta.appName
$appVersion = [string]$meta.appVersion
$appPublisher = [string]$meta.appPublisher
$appUrl = [string]$meta.appUrl

if ([string]::IsNullOrWhiteSpace($appName)) { $appName = 'InfernaCore' }
if ([string]::IsNullOrWhiteSpace($appVersion)) { $appVersion = '1.0.0' }
if ([string]::IsNullOrWhiteSpace($appPublisher)) { $appPublisher = 'InfernaCore Contributors' }
if ([string]::IsNullOrWhiteSpace($appUrl)) { $appUrl = 'https://github.com/beamtupgaming/infernacore' }

$readme = Get-Content -Path $ReadmePath -Raw
$markerStart = '<!-- METADATA:START -->'
$markerEnd = '<!-- METADATA:END -->'

$metaBlock = @"
$markerStart
- Current version: $appVersion
- Publisher: $appPublisher
- Project URL: $appUrl
$markerEnd
"@

$allMetaPattern = [regex]::Escape($markerStart) + '[\s\S]*?' + [regex]::Escape($markerEnd)
$readme = [regex]::Replace($readme, $allMetaPattern, '').TrimEnd()
$readme = [regex]::Replace($readme, '(?m)^---\s*\r?\n', "---`r`n`r`n$metaBlock`r`n`r`n", 1)

Set-Content -Path $ReadmePath -Value $readme -Encoding UTF8

$eulaLines = Get-Content -Path $EulaPath
$effectiveDate = 'March 2026'
$versionLineIndex = -1

for ($i = 0; $i -lt $eulaLines.Count; $i++) {
    if ($eulaLines[$i] -match '^Version\s+') {
        $versionLineIndex = $i
        if ($eulaLines[$i] -match 'Effective:\s*(.+)$' -and -not [string]::IsNullOrWhiteSpace($Matches[1])) {
            $candidateDate = $Matches[1].Trim()
            if ($candidateDate -match '^[A-Za-z]+\s+\d{4}$') {
                $effectiveDate = $candidateDate
            }
        }
        break
    }
}

if ($versionLineIndex -ge 0) {
    $eulaLines[$versionLineIndex] = "Version $appVersion  |  Effective: $effectiveDate"
}

Set-Content -Path $EulaPath -Value $eulaLines -Encoding UTF8

Write-Host "Synced metadata -> README and EULA (version $appVersion)."

$buildLogScript = Join-Path $scriptRoot 'Update-BuildLog.ps1'
if (Test-Path $buildLogScript) {
    try {
        & $buildLogScript `
            -Category 'Release' `
            -Title 'Metadata sync completed' `
            -Version $appVersion `
            -Details 'Updated README metadata block and EULA version header.'
    }
    catch {
        Write-Warning "Metadata sync succeeded, but build log update failed: $($_.Exception.Message)"
    }
}
