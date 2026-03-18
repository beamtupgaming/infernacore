param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Technical', 'Release')]
    [string]$Category,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$Details = '',
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot
$logsDir = Join-Path $repoRoot 'logs'
$buildLogPath = Join-Path $logsDir 'BUILD_LOG.md'

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

if (-not (Test-Path $buildLogPath)) {
    Set-Content -Path $buildLogPath -Value "# InfernaCore Build Log`r`n" -Encoding UTF8
}

$content = Get-Content -Path $buildLogPath -Raw

if ($content -notmatch '(?m)^## Automated Change Entries\s*$') {
    $content = $content.TrimEnd() + "`r`n`r`n## Automated Change Entries`r`n"
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$entry = "### [$timestamp] $Category - $Title`r`n"

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $entry += "- Version: $Version`r`n"
}

if (-not [string]::IsNullOrWhiteSpace($Details)) {
    $entry += "- Details: $Details`r`n"
}

$entry += "`r`n"

Set-Content -Path $buildLogPath -Value ($content.TrimEnd() + "`r`n`r`n" + $entry) -Encoding UTF8
Write-Host "Build log updated: $buildLogPath"
