$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot
$hooksDir = Join-Path $repoRoot '.git\hooks'
$hookPath = Join-Path $hooksDir 'pre-commit'

if (-not (Test-Path $hooksDir)) {
    throw "Git hooks folder not found: $hooksDir"
}

$hookScript = @'
#!/bin/sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tools\GitHook-PreCommit.ps1"
exit $?
'@

Set-Content -Path $hookPath -Value $hookScript -Encoding ASCII

Write-Host "Installed pre-commit hook: $hookPath"
Write-Host "Hook target: tools/GitHook-PreCommit.ps1"
