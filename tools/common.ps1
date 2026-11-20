# Shared paths for tools\*.ps1. Dot-source it: . "$PSScriptRoot\common.ps1"
# Machine paths are documented in docs\ENV.md; keep both in sync.

$repo = Split-Path $PSScriptRoot -Parent
# Two instances: "test" (.factorio, used by check/run-tests) and "play" (.factorio-play, used
# by playtest.ps1), so tests can run while a playtest is open. Set $TTInstance before
# dot-sourcing to pick one.
if (-not $TTInstance) { $TTInstance = 'test' }
$root = Join-Path $repo $(if ($TTInstance -eq 'play') { '.factorio-play' } else { '.factorio' })
$writeData = Join-Path $root 'data'

$TT = [ordered]@{
    Repo         = $repo
    Exe          = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
    InstallDir   = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio'
    Root         = $root
    ConfigDir    = Join-Path $root 'config'
    Config       = Join-Path $root 'config\config.ini'
    WriteData    = $writeData
    ModsDir      = Join-Path $writeData 'mods'
    Log          = Join-Path $writeData 'factorio-current.log'
    ScriptOutput = Join-Path $writeData 'script-output'
    # mod folder name in the instance -> repo folder
    Junctions    = [ordered]@{
        'tracktorio'       = Join-Path $repo 'mod'
        'tracktorio-tests' = Join-Path $repo 'tests'
    }
}
if ($env:TT_FACTORIO_EXE) { $TT.Exe = $env:TT_FACTORIO_EXE }

# Run factorio.exe against the dev instance. Returns @{ ExitCode; TimedOut; Stdout }.
function Invoke-TTFactorio {
    param([string[]]$Arguments, [int]$TimeoutSec = 300)
    $out = Join-Path $TT.Root 'last-stdout.txt'
    $err = Join-Path $TT.Root 'last-stderr.txt'
    $allArgs = @('--config', "`"$($TT.Config)`"") + $Arguments
    $p = Start-Process -FilePath $TT.Exe -ArgumentList $allArgs -PassThru -NoNewWindow `
        -RedirectStandardOutput $out -RedirectStandardError $err
    Set-Content (Join-Path $TT.Root 'factorio.pid') $p.Id
    $timedOut = -not $p.WaitForExit($TimeoutSec * 1000)
    if ($timedOut) { try { $p.Kill($true) } catch {} ; $p.WaitForExit() }
    Remove-Item (Join-Path $TT.Root 'factorio.pid') -ErrorAction SilentlyContinue
    [pscustomobject]@{
        ExitCode = if ($timedOut) { -1 } else { $p.ExitCode }
        TimedOut = $timedOut
        Stdout   = (Get-Content $out -Raw -ErrorAction SilentlyContinue) + (Get-Content $err -Raw -ErrorAction SilentlyContinue)
    }
}

# Kill a dev-instance factorio left over from an earlier run (only the one we started).
function Stop-TTStale {
    $pidFile = Join-Path $TT.Root 'factorio.pid'
    if (Test-Path $pidFile) {
        $stale = Get-Process -Id ([int](Get-Content $pidFile)) -ErrorAction SilentlyContinue
        if ($stale -and $stale.Path -eq $TT.Exe) { Write-Host "stopping stale test instance $($stale.Id)"; $stale.Kill($true) }
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
}
