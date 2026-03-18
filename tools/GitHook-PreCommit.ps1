$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot

Push-Location $repoRoot
try {
    $stagedFiles = @(git diff --cached --name-only --diff-filter=ACMR)
    if (-not $stagedFiles -or $stagedFiles.Count -eq 0) {
        exit 0
    }

    $relevantFiles = @(
        $stagedFiles | Where-Object {
            $_ -and
            $_ -notmatch '^(logs/|logs\\)' -and
            $_ -notmatch '^(dist/|dist\\)' -and
            $_ -notmatch '^\.git/'
        }
    )

    if (-not $relevantFiles -or $relevantFiles.Count -eq 0) {
        exit 0
    }

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

    $changeSummary = ($relevantFiles | Sort-Object -Unique) -join ', '
    if ($changeSummary.Length -gt 400) {
        $changeSummary = $changeSummary.Substring(0, 397) + '...'
    }

    $logScript = Join-Path $scriptRoot 'Update-BuildLog.ps1'
    if (Test-Path $logScript) {
        & $logScript `
            -Category 'Technical' `
            -Title 'Manual staged changes detected' `
            -Version $appVersion `
            -Details "Pre-commit tracked files: $changeSummary"

        git add -- logs/BUILD_LOG.md | Out-Null
    }

    exit 0
}
catch {
    Write-Host "[BuildLog Hook] Warning: $($_.Exception.Message)"
    exit 0
}
finally {
    Pop-Location
}
