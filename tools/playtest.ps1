#Requires -Version 7
<#
.SYNOPSIS
  Launch the Factorio GUI client on the dev instance with a scenario, for a manual playtest.
.DESCRIPTION
  Uses the playtest instance (.factorio-play\), never the user's real Factorio data, and not
  the test instance (.factorio\), so tests can run while the game is open. Returns
  immediately; the game keeps running until the user quits it.
  The first launch uses default graphics settings (saved in .factorio-play\config\config.ini
  afterwards). The tests mod is not loaded here.
.PARAMETER Scenario
  [MOD/]NAME, default tracktorio/tracktorio (the MVP scenario, Phase 1.8).
#>
[CmdletBinding()]
param([string]$Scenario = 'tracktorio/tracktorio')
$ErrorActionPreference = 'Stop'
$TTInstance = 'play'
. "$PSScriptRoot\common.ps1"

& "$PSScriptRoot\dev-instance.ps1" -Instance play | Out-Null
$p = Start-Process -FilePath $TT.Exe -PassThru -ArgumentList @('--config', "`"$($TT.Config)`"", '--load-scenario', $Scenario)
Write-Host "Factorio started (pid $($p.Id)) with scenario $Scenario."
Write-Host "Log: $($TT.Log)"
Write-Host "Script output: $($TT.ScriptOutput)"
