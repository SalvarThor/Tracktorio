#Requires -Version 7
<#
.SYNOPSIS
  Launch the Factorio GUI client on the dev instance with a scenario, for a manual playtest.
.DESCRIPTION
  Uses the dev instance (.factorio\), never the user's real Factorio data. Returns
  immediately; the game keeps running until the user quits it.
  The first launch of the dev instance uses default graphics settings (they are saved in
  .factorio\config\config.ini afterwards).
.PARAMETER Scenario
  [MOD/]NAME, default train-tycoon/train-tycoon (the MVP scenario, Phase 1.8).
#>
[CmdletBinding()]
param([string]$Scenario = 'train-tycoon/train-tycoon')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

& "$PSScriptRoot\dev-instance.ps1" | Out-Null
$p = Start-Process -FilePath $TT.Exe -PassThru -ArgumentList @('--config', "`"$($TT.Config)`"", '--load-scenario', $Scenario)
Write-Host "Factorio started (pid $($p.Id)) with scenario $Scenario."
Write-Host "Log: $($TT.Log)"
Write-Host "Script output: $($TT.ScriptOutput)"
