param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('validate', 'list', 'enable', 'disable', 'install', 'create-profile', 'apply-profile')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$ModId,

    [string]$GameModsPath = '',
    [string]$TemplateRoot = '',
    [string]$ProfileName = ''
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

function Resolve-GameModsPath {
    param(
        [string]$ExplicitPath,
        [string]$Root
    )

    if ($ExplicitPath) {
        if (-not (Test-Path $ExplicitPath)) {
            New-Item -Path $ExplicitPath -ItemType Directory -Force | Out-Null
        }
        return (Resolve-Path $ExplicitPath).Path
    }

    $defaultPath = Join-Path $Root 'GameMods'
    if (-not (Test-Path $defaultPath)) {
        New-Item -Path $defaultPath -ItemType Directory -Force | Out-Null
    }
    return (Resolve-Path $defaultPath).Path
}

function Get-ModManifest {
    param([string]$ManifestPath)

    if (-not (Test-Path $ManifestPath)) {
        throw "Missing manifest: $ManifestPath"
    }

    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $required = @('id', 'name', 'version')
    foreach ($field in $required) {
        if (-not $manifest.PSObject.Properties.Name.Contains($field) -or [string]::IsNullOrWhiteSpace($manifest.$field)) {
            throw "Manifest $ManifestPath missing required field: $field"
        }
    }

    return $manifest
}

function Get-AllModFolders {
    param([string]$ModsSourceRoot)

    if (-not (Test-Path $ModsSourceRoot)) {
        return @()
    }

    return Get-ChildItem -Path $ModsSourceRoot -Directory
}

function Find-ModFolderById {
    param(
        [string]$ModsSourceRoot,
        [string]$WantedModId
    )

    foreach ($folder in (Get-AllModFolders -ModsSourceRoot $ModsSourceRoot)) {
        $manifestPath = Join-Path $folder.FullName 'mod.json'
        if (-not (Test-Path $manifestPath)) { continue }
        $manifest = Get-ModManifest -ManifestPath $manifestPath
        if ($manifest.id -eq $WantedModId) {
            return @{ Folder = $folder; Manifest = $manifest }
        }
    }

    throw "Mod id '$WantedModId' was not found under $ModsSourceRoot"
}

function Get-InstallPath {
    param(
        [string]$ModsTargetRoot,
        [object]$Manifest
    )

    return (Join-Path $ModsTargetRoot ("{0}-{1}" -f $Manifest.id, $Manifest.version))
}

function Write-ManagedMarker {
    param([string]$Path)

    $markerPath = Join-Path $Path '.managed-by-template'
    Set-Content -Path $markerPath -Value "managed=true`n" -Encoding UTF8
}

function Enable-Mod {
    param(
        [string]$ModsSourceRoot,
        [string]$ModsTargetRoot,
        [string]$WantedModId
    )

    $result = Find-ModFolderById -ModsSourceRoot $ModsSourceRoot -WantedModId $WantedModId
    $sourceFolder = $result.Folder.FullName
    $manifest = $result.Manifest
    $installPath = Get-InstallPath -ModsTargetRoot $ModsTargetRoot -Manifest $manifest

    if (Test-Path $installPath) {
        Remove-Item -Path $installPath -Recurse -Force
    }

    Copy-Item -Path $sourceFolder -Destination $installPath -Recurse -Force
    Write-ManagedMarker -Path $installPath

    Write-Host "Enabled mod: $($manifest.name) [$($manifest.id)] => $installPath"
}

function Disable-Mod {
    param(
        [string]$ModsTargetRoot,
        [string]$WantedModId
    )

    $removedAny = $false
    $candidates = Get-ChildItem -Path $ModsTargetRoot -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $candidates) {
        if ($dir.Name -like "$WantedModId-*") {
            Remove-Item -Path $dir.FullName -Recurse -Force
            Write-Host "Disabled mod: $WantedModId by removing $($dir.FullName)"
            $removedAny = $true
        }
    }

    if (-not $removedAny) {
        Write-Host "No installed copies found for mod id: $WantedModId"
    }
}

function Validate-Mods {
    param([string]$ModsSourceRoot)

    $folders = Get-AllModFolders -ModsSourceRoot $ModsSourceRoot
    if ($folders.Count -eq 0) {
        Write-Host 'No mod packages found under modpacks/.'
        return
    }

    $failed = $false
    foreach ($folder in $folders) {
        $manifestPath = Join-Path $folder.FullName 'mod.json'
        try {
            $manifest = Get-ModManifest -ManifestPath $manifestPath
            Write-Host "OK   $($manifest.id) v$($manifest.version)"
        }
        catch {
            Write-Host "FAIL $($folder.Name): $($_.Exception.Message)"
            $failed = $true
        }
    }

    if ($failed) {
        throw 'Validation failed for one or more mods.'
    }
}

function List-Mods {
    param(
        [string]$ModsSourceRoot,
        [string]$ModsTargetRoot
    )

    $folders = Get-AllModFolders -ModsSourceRoot $ModsSourceRoot
    if ($folders.Count -eq 0) {
        Write-Host 'No mod packages found under modpacks/.'
        return
    }

    foreach ($folder in $folders) {
        $manifestPath = Join-Path $folder.FullName 'mod.json'
        try {
            $manifest = Get-ModManifest -ManifestPath $manifestPath
            $installed = Get-ChildItem -Path $ModsTargetRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$($manifest.id)-*" }
            $status = if ($installed) { 'ENABLED' } else { 'disabled' }
            Write-Host ("{0,-10} {1,-28} v{2}" -f $status, $manifest.id, $manifest.version)
        }
        catch {
            Write-Host ("invalid    {0}" -f $folder.Name)
        }
    }
}

function Save-Profile {
    param(
        [string]$ProfilesRoot,
        [string]$Name,
        [string[]]$ModIds
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'Profile name is required.'
    }

    if (-not (Test-Path $ProfilesRoot)) {
        New-Item -Path $ProfilesRoot -ItemType Directory -Force | Out-Null
    }

    $profilePath = Join-Path $ProfilesRoot ("$Name.txt")
    Set-Content -Path $profilePath -Value ($ModIds -join [Environment]::NewLine) -Encoding UTF8
    Write-Host "Profile saved: $profilePath"
}

function Apply-Profile {
    param(
        [string]$ProfilesRoot,
        [string]$Name,
        [string]$ModsSourceRoot,
        [string]$ModsTargetRoot
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'Profile name is required.'
    }

    $profilePath = Join-Path $ProfilesRoot ("$Name.txt")
    if (-not (Test-Path $profilePath)) {
        throw "Profile not found: $profilePath"
    }

    $wantedIds = Get-Content -Path $profilePath | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    $managedInstalled = Get-ChildItem -Path $ModsTargetRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName '.managed-by-template') }

    foreach ($installed in $managedInstalled) {
        $idGuess = $installed.Name -replace '-[^-]+$',''
        if ($wantedIds -notcontains $idGuess) {
            Remove-Item -Path $installed.FullName -Recurse -Force
            Write-Host "Removed (not in profile): $($installed.Name)"
        }
    }

    foreach ($modId in $wantedIds) {
        Enable-Mod -ModsSourceRoot $ModsSourceRoot -ModsTargetRoot $ModsTargetRoot -WantedModId $modId
    }

    Write-Host "Applied profile '$Name'"
}

$templateRoot = Resolve-TemplateRoot -ExplicitRoot $TemplateRoot
$modsSourceRoot = Join-Path $templateRoot 'modpacks'
$profilesRoot = Join-Path $templateRoot 'profiles'
$modsTargetRoot = Resolve-GameModsPath -ExplicitPath $GameModsPath -Root $templateRoot

switch ($Command) {
    'validate' {
        Validate-Mods -ModsSourceRoot $modsSourceRoot
    }
    'list' {
        List-Mods -ModsSourceRoot $modsSourceRoot -ModsTargetRoot $modsTargetRoot
    }
    'enable' {
        if (-not $ModId) { throw 'enable requires <ModId>' }
        Enable-Mod -ModsSourceRoot $modsSourceRoot -ModsTargetRoot $modsTargetRoot -WantedModId $ModId
    }
    'install' {
        if (-not $ModId) { throw 'install requires <ModId>' }
        Enable-Mod -ModsSourceRoot $modsSourceRoot -ModsTargetRoot $modsTargetRoot -WantedModId $ModId
    }
    'disable' {
        if (-not $ModId) { throw 'disable requires <ModId>' }
        Disable-Mod -ModsTargetRoot $modsTargetRoot -WantedModId $ModId
    }
    'create-profile' {
        if (-not $ProfileName) { throw 'create-profile requires -ProfileName <name>' }
        if (-not $ModId) { throw 'create-profile requires comma-separated mod ids in <ModId> argument' }
        $ids = $ModId.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        Save-Profile -ProfilesRoot $profilesRoot -Name $ProfileName -ModIds $ids
    }
    'apply-profile' {
        if (-not $ProfileName) { throw 'apply-profile requires -ProfileName <name>' }
        Apply-Profile -ProfilesRoot $profilesRoot -Name $ProfileName -ModsSourceRoot $modsSourceRoot -ModsTargetRoot $modsTargetRoot
    }
}
