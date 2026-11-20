#Requires -Version 7
<#
.SYNOPSIS
  Create or repair the isolated dev/test Factorio instance in <repo>\.factorio.
.DESCRIPTION
  Idempotent. Writes config.ini, junctions the project's mods into the instance mods dir and
  writes mod-list.json. Never touches %APPDATA%\Factorio.
  Dot-source tools\common.ps1 for the paths it uses.
#>
[CmdletBinding()]
param(
    # Extra mods to disable in mod-list.json (for probes, e.g. -Disable quality,recycler)
    [string[]]$Disable = @(),
    # "test" (.factorio) or "play" (.factorio-play)
    [ValidateSet('test', 'play')][string]$Instance = 'test'
)
$ErrorActionPreference = 'Stop'
$TTInstance = $Instance
. "$PSScriptRoot\common.ps1"

New-Item -ItemType Directory -Force $TT.ConfigDir, $TT.ModsDir, $TT.ScriptOutput | Out-Null

$writeData = $TT.WriteData -replace '\\', '/'
@"
[path]
read-data=__PATH__executable__/../../data
write-data=$writeData
[other]
check-updates=false
enable-new-mods=false
[sound]
master-volume=0
"@ | Set-Content -Path $TT.Config -Encoding utf8NoBOM

# Junctions: <mods>\<name> -> repo folder. Recreate if pointing elsewhere.
# The playtest instance gets the mod only, not the tests mod.
$links = [ordered]@{}
foreach ($k in $TT.Junctions.Keys) { if ($Instance -eq 'test' -or $k -ne 'tracktorio-tests') { $links[$k] = $TT.Junctions[$k] } }
# Stale junctions into this repo that are no longer wanted (a renamed mod, e.g. the
# train-tycoon -> tracktorio rename; the tests mod in the playtest instance) would load a
# second copy of the mod. Unlink them: non-recursive, removes the link only.
if (Test-Path $TT.ModsDir) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
    foreach ($item in Get-ChildItem $TT.ModsDir -Force -Directory -ErrorAction SilentlyContinue) {
        if ($item.LinkType -ne 'Junction' -or $links.Contains($item.Name)) { continue }
        $target = [string]$item.Target
        if ($target.TrimEnd('\').StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            [System.IO.Directory]::Delete($item.FullName)
            Write-Host "removed stale junction $($item.Name)"
        }
    }
}
foreach ($link in $links.GetEnumerator()) {
    $path = Join-Path $TT.ModsDir $link.Key
    $target = $link.Value
    if (-not (Test-Path $target)) { continue }
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item) {
        if ($item.LinkType -eq 'Junction' -and $item.Target -eq $target) { continue }
        if ($item.LinkType -ne 'Junction') { throw "$path exists and is not a junction; refusing to touch it." }
        [System.IO.Directory]::Delete($path)   # non-recursive: removes the link only
    }
    New-Item -ItemType Junction -Path $path -Target $target | Out-Null
    Write-Host "junction $($link.Key) -> $target"
}

$enabled = [ordered]@{}
foreach ($m in @('base', 'elevated-rails', 'recycler', 'space-age')) { $enabled[$m] = $true }
$enabled['quality'] = $false   # tracktorio declares "! quality"
foreach ($m in $links.Keys) { if (Test-Path $links[$m]) { $enabled[$m] = $true } }
foreach ($m in $Disable) { $enabled[$m] = $false }
$modList = @{ mods = @($enabled.GetEnumerator() | ForEach-Object { [ordered]@{ name = $_.Key; enabled = $_.Value } }) }
$modList | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $TT.ModsDir 'mod-list.json') -Encoding utf8NoBOM

Write-Host "dev instance ready: $($TT.Root)"
