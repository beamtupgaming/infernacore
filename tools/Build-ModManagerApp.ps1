param(
    [string]$SourcePath = '',
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot   = Split-Path -Parent $scriptRoot
$metadataPath = Join-Path $scriptRoot 'AppMetadata.json'
if (-not $SourcePath) {
    $SourcePath = Join-Path $scriptRoot 'ModManagerApp.cs'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'InfernaCore.exe'
}

if (-not (Test-Path $metadataPath)) {
    throw "Metadata file not found: $metadataPath"
}

if ([string]::IsNullOrWhiteSpace($SourcePath) -or -not (Test-Path $SourcePath)) {
    throw "Source file not found: $SourcePath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    throw 'Output path is empty.'
}

if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Force
}

$source = Get-Content -Path $SourcePath -Raw

$metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
$appName = [string]$metadata.appName
$appVersion = [string]$metadata.appVersion
$appPublisher = [string]$metadata.appPublisher

if ([string]::IsNullOrWhiteSpace($appName)) { $appName = 'InfernaCore' }
if ([string]::IsNullOrWhiteSpace($appVersion)) { $appVersion = '1.0.0' }
if ([string]::IsNullOrWhiteSpace($appPublisher)) { $appPublisher = 'InfernaCore Contributors' }

$assemblyVersion = if ($appVersion -match '^\d+\.\d+\.\d+\.\d+$') { $appVersion } else { "$appVersion.0" }

$assemblyInfoPath = Join-Path $scriptRoot 'AssemblyInfo.g.cs'
$appNameEscaped = $appName.Replace('"', '""')
$appPublisherEscaped = $appPublisher.Replace('"', '""')
$appVersionEscaped = $appVersion.Replace('"', '""')
$assemblyVersionEscaped = $assemblyVersion.Replace('"', '""')
$assemblyInfo = @"
[assembly: System.Reflection.AssemblyTitle("$appNameEscaped")]
[assembly: System.Reflection.AssemblyProduct("$appNameEscaped")]
[assembly: System.Reflection.AssemblyCompany("$appPublisherEscaped")]
[assembly: System.Reflection.AssemblyVersion("$assemblyVersionEscaped")]
[assembly: System.Reflection.AssemblyFileVersion("$assemblyVersionEscaped")]
[assembly: System.Reflection.AssemblyInformationalVersion("$appVersionEscaped")]
"@
Set-Content -Path $assemblyInfoPath -Value $assemblyInfo -Encoding UTF8

$iconPath = Join-Path $repoRoot 'Images\InfernaCore_icon.ico'

$cscCandidates = @(
    'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe',
    'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
)

$cscPath = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cscPath) {
    throw 'Could not find csc.exe in .NET Framework v4.0.30319.'
}

$outArg = '/out:{0}' -f $OutputPath

$args = @(
    '/nologo',
    '/target:winexe',
    $outArg,
    '/r:System.Windows.Forms.dll',
    '/r:System.Drawing.dll',
    '/r:System.Web.Extensions.dll'
)

if (Test-Path $iconPath) {
    $args += '/win32icon:' + $iconPath
}

$args += $SourcePath
$args += $assemblyInfoPath

try {
    & $cscPath @args
    if ($LASTEXITCODE -ne 0) {
        throw "csc.exe failed with exit code $LASTEXITCODE"
    }
}
finally {
    if (Test-Path $assemblyInfoPath) {
        Remove-Item -Path $assemblyInfoPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Built: $OutputPath"

$buildLogScript = Join-Path $scriptRoot 'Update-BuildLog.ps1'
if (Test-Path $buildLogScript) {
    try {
        & $buildLogScript `
            -Category 'Technical' `
            -Title 'App executable build succeeded' `
            -Version $appVersion `
            -Details "Output: $OutputPath"
    }
    catch {
        Write-Warning "Build succeeded, but build log update failed: $($_.Exception.Message)"
    }
}
