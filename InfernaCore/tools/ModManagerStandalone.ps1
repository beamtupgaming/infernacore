param(
    [string]$TemplateRoot = '',
    [string]$GameRoot = 'D:\SteamLibrary\steamapps\common\Into The Flames',
    [string]$GameModsPath = '',
    [string]$ProfileName = '',
    [string]$ModIds = 'ai_traffic_fix',
    [switch]$NoLaunch,
    [switch]$CleanManaged
)

$ErrorActionPreference = 'Stop'

function Resolve-TemplateRoot {
    param([string]$ExplicitRoot)

    if ($ExplicitRoot -and (Test-Path $ExplicitRoot)) {
        return (Resolve-Path $ExplicitRoot).Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptRoot '..')).Path
}

function Resolve-GameRoot {
    param([string]$Path)

    if (-not $Path) {
        throw 'GameRoot is required.'
    }

    if (-not (Test-Path $Path)) {
        throw "Game root was not found: $Path"
    }

    return (Resolve-Path $Path).Path
}

function Resolve-GameModsPath {
    param(
        [string]$ExplicitPath,
        [string]$ResolvedGameRoot
    )

    if ($ExplicitPath) {
        if (-not (Test-Path $ExplicitPath)) {
            New-Item -Path $ExplicitPath -ItemType Directory -Force | Out-Null
        }
        return (Resolve-Path $ExplicitPath).Path
    }

    $candidate1 = Join-Path $ResolvedGameRoot 'Mods'
    $candidate2 = Join-Path $ResolvedGameRoot 'IntoTheFlames\Mods'

    if (Test-Path $candidate1) { return (Resolve-Path $candidate1).Path }
    if (Test-Path $candidate2) { return (Resolve-Path $candidate2).Path }

    New-Item -Path $candidate2 -ItemType Directory -Force | Out-Null
    return (Resolve-Path $candidate2).Path
}

function Resolve-GameExePath {
    param([string]$ResolvedGameRoot)

    $candidates = @(
        (Join-Path $ResolvedGameRoot 'Project_Flames.exe'),
        (Join-Path $ResolvedGameRoot 'IntoTheFlames\Binaries\Win64\Project_Flames-Win64-Shipping.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "Could not find game executable under: $ResolvedGameRoot"
}

function Get-ModManifest {
    param([string]$ManifestPath)

    if (-not (Test-Path $ManifestPath)) {
        throw "Missing manifest: $ManifestPath"
    }

    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    foreach ($required in @('id', 'name', 'version', 'entry')) {
        if (-not $manifest.PSObject.Properties.Name.Contains($required) -or [string]::IsNullOrWhiteSpace($manifest.$required)) {
            throw "Manifest $ManifestPath missing required field: $required"
        }
    }

    return $manifest
}

function Get-ModFolderById {
    param(
        [string]$ModsSourceRoot,
        [string]$ModId
    )

    $folders = Get-ChildItem -Path $ModsSourceRoot -Directory -ErrorAction SilentlyContinue
    foreach ($folder in $folders) {
        $manifestPath = Join-Path $folder.FullName 'mod.json'
        if (-not (Test-Path $manifestPath)) { continue }

        $manifest = Get-ModManifest -ManifestPath $manifestPath
        if ($manifest.id -eq $ModId) {
            return @{ Folder = $folder; Manifest = $manifest }
        }
    }

    throw "Mod id '$ModId' was not found under $ModsSourceRoot"
}

function Get-WantedModIds {
    param(
        [string]$ResolvedTemplateRoot,
        [string]$Profile,
        [string]$CsvModIds
    )

    if ($Profile) {
        $profilePath = Join-Path (Join-Path $ResolvedTemplateRoot 'profiles') ("$Profile.txt")
        if (-not (Test-Path $profilePath)) {
            throw "Profile not found: $profilePath"
        }

        return Get-Content -Path $profilePath |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
    }

    return $CsvModIds.Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
}

function Write-ManagedMarker {
    param([string]$TargetFolder)

    $markerPath = Join-Path $TargetFolder '.managed-by-standalone'
    Set-Content -Path $markerPath -Value "managed=true`n" -Encoding UTF8
}

function Clear-ManagedInstalls {
    param([string]$ResolvedGameModsPath)

    $installed = Get-ChildItem -Path $ResolvedGameModsPath -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $installed) {
        $marker = Join-Path $dir.FullName '.managed-by-standalone'
        if (Test-Path $marker) {
            Remove-Item -Path $dir.FullName -Recurse -Force
            Write-Host "Removed managed install: $($dir.FullName)"
        }
    }
}

function Enable-Mod {
    param(
        [string]$ModsSourceRoot,
        [string]$ResolvedGameModsPath,
        [string]$ModId
    )

    $result = Get-ModFolderById -ModsSourceRoot $ModsSourceRoot -ModId $ModId
    $sourceFolder = $result.Folder.FullName
    $manifest = $result.Manifest

    $entryPath = Join-Path $sourceFolder $manifest.entry
    if (-not (Test-Path $entryPath)) {
        throw "Entrypoint not found for mod '$ModId': $entryPath"
    }

    $targetPath = Join-Path $ResolvedGameModsPath ("{0}-{1}" -f $manifest.id, $manifest.version)

    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Recurse -Force
    }

    Copy-Item -Path $sourceFolder -Destination $targetPath -Recurse -Force
    Write-ManagedMarker -TargetFolder $targetPath

    Write-Host "Enabled: $($manifest.id) v$($manifest.version) -> $targetPath"
}

$resolvedTemplateRoot = Resolve-TemplateRoot -ExplicitRoot $TemplateRoot
$resolvedGameRoot = Resolve-GameRoot -Path $GameRoot
$resolvedGameModsPath = Resolve-GameModsPath -ExplicitPath $GameModsPath -ResolvedGameRoot $resolvedGameRoot
$modsSourceRoot = Join-Path $resolvedTemplateRoot 'modpacks'

if (-not (Test-Path $modsSourceRoot)) {
    throw "modpacks folder not found: $modsSourceRoot"
}

$wantedModIds = Get-WantedModIds -ResolvedTemplateRoot $resolvedTemplateRoot -Profile $ProfileName -CsvModIds $ModIds
if ($wantedModIds.Count -eq 0) {
    throw 'No mod ids provided. Use -ModIds or -ProfileName.'
}

Write-Host "TemplateRoot: $resolvedTemplateRoot"
Write-Host "GameRoot:     $resolvedGameRoot"
Write-Host "GameModsPath: $resolvedGameModsPath"
Write-Host "Wanted mods:  $($wantedModIds -join ', ')"

if ($CleanManaged) {
    Clear-ManagedInstalls -ResolvedGameModsPath $resolvedGameModsPath
}

foreach ($id in $wantedModIds) {
    Enable-Mod -ModsSourceRoot $modsSourceRoot -ResolvedGameModsPath $resolvedGameModsPath -ModId $id
}

if ($NoLaunch) {
    Write-Host 'NoLaunch enabled: mod sync complete, game not started.'
    return
}

$exePath = Resolve-GameExePath -ResolvedGameRoot $resolvedGameRoot
$workingDir = Split-Path -Parent $exePath

Write-Host "Launching: $exePath"
Start-Process -FilePath $exePath -WorkingDirectory $workingDir
