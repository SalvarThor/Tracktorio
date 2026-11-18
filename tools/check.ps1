#Requires -Version 7
<#
.SYNOPSIS
  Static check: lua-language-server --check over mod/ and tests/ with Factorio 2.1 API types.
  Exits 0 when clean, 1 on any diagnostic at Warning or above, 2 on tool failure.
.PARAMETER Regenerate
  Regenerate tools/types from the installed Factorio's doc-html JSON (needed after a game
  update or a fresh clone).
#>
[CmdletBinding()]
param([switch]$Regenerate)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# winget installs update PATH for new shells only; pick up the current machine/user PATH.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

$types = Join-Path $TT.Repo 'tools\types\factorio'
if ($Regenerate -or -not (Test-Path (Join-Path $types 'config.json'))) {
    $docs = Join-Path $TT.InstallDir 'doc-html'
    Push-Location $TT.Repo
    try {
        if (-not (Test-Path 'node_modules\factoriomod-debug')) { npm install --silent | Out-Null }
        npx fmtk luals-addon -d "$docs\runtime-api.json" -p "$docs\prototype-api.json" tools/types | Out-Host
    } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { Write-Host 'type generation failed'; exit 2 }
}

$logDir = Join-Path $TT.Root 'luals'
Remove-Item (Join-Path $logDir 'check.json') -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $logDir | Out-Null

$lls = Get-Command lua-language-server -ErrorAction SilentlyContinue
if (-not $lls) { Write-Host 'lua-language-server not found on PATH (winget install LuaLS.lua-language-server)'; exit 2 }

& $lls.Source --check="$($TT.Repo)" --checklevel=Warning --check_format=json --logpath="$logDir" | Out-Null

$report = Join-Path $logDir 'check.json'
if (-not (Test-Path $report)) {
    # LuaLS writes no file (or "[]") when there is nothing to report.
    Write-Host 'static check: PASS (no diagnostics)'; exit 0
}
$json = Get-Content $report -Raw
if ([string]::IsNullOrWhiteSpace($json) -or $json.Trim() -eq '[]') { Write-Host 'static check: PASS (no diagnostics)'; exit 0 }

$diag = $json | ConvertFrom-Json -AsHashtable
$count = 0
$sev = @{ 1 = 'error'; 2 = 'warning'; 3 = 'info'; 4 = 'hint' }
foreach ($uri in $diag.Keys) {
    $path = [Uri]::UnescapeDataString($uri) -replace '^file:///', ''
    $rel = [IO.Path]::GetRelativePath($TT.Repo, $path)
    foreach ($d in $diag[$uri]) {
        $count++
        $line = $d.range.start.line + 1
        $col = $d.range.start.character + 1
        Write-Host ("{0}:{1}:{2}: {3} [{4}] {5}" -f $rel, $line, $col, $sev[[int]$d.severity], $d.code, $d.message)
    }
}
if ($count -eq 0) { Write-Host 'static check: PASS (no diagnostics)'; exit 0 }
Write-Host "static check: FAIL ($count diagnostics)"
exit 1
