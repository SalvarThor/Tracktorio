#Requires -Version 7
<#
.SYNOPSIS
  Run the in-game test suite headless in the dev instance and report the results.
.DESCRIPTION
  Uses Factorio 2.1.24's --test-scenario: the test scenario (tracktorio-tests/tt-tests)
  runs the tests, writes script-output\tt-test-results.json and calls
  script.finish_test(passed). A run counts as passed only if the game exits 0 AND a results
  file with this run's id reports failed=0, passed>0. (--test-ticks exits 0 on timeout, so
  the exit code alone is not trusted.)

  Exit codes: 0 pass, 1 test failures, 2 harness/game error (no or stale results, crash,
  load error, timeout).
.PARAMETER Filter
  Only run tests whose name contains this text.
.PARAMETER SelfTest
  Check the runner itself: also run the deliberately failing tests in tests\cases\selftest.lua
  and verify each one was reported as expected. Exit 0 means the runner behaves correctly.
#>
[CmdletBinding()]
param(
    [string]$Filter = '',
    [switch]$SelfTest,
    [int]$MaxTicks = 216000,     # 1 h game time at 60 UPS; a backstop, not a test timeout
    [int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

Stop-TTStale
& "$PSScriptRoot\dev-instance.ps1" | Out-Null

$resultsPath = Join-Path $TT.ScriptOutput 'tt-test-results.json'
Remove-Item $resultsPath -ErrorAction SilentlyContinue

$runId = [guid]::NewGuid().ToString('N').Substring(0, 12)
$testArg = "run=$runId;filter=$Filter;selftest=$(if ($SelfTest) { 1 } else { 0 })"
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-TTFactorio -TimeoutSec $TimeoutSec -Arguments @(
    '--test-scenario', 'tracktorio-tests/tt-tests',
    '--test-arg', "`"$testArg`"",
    '--test-ticks', "$MaxTicks",
    '--disable-audio'
)
$secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)

function Show-LogTail {
    Write-Host "--- last log lines ($($TT.Log)):"
    if (-not (Test-Path $TT.Log)) { return }
    $lines = Get-Content $TT.Log
    # Start at the first error if there is one, otherwise show the tail.
    $first = 0..($lines.Count - 1) | Where-Object { $lines[$_] -match '^\s*\d+\.\d+ Error ' } | Select-Object -First 1
    $from = if ($null -ne $first) { [math]::Max(0, $first - 3) } else { [math]::Max(0, $lines.Count - 25) }
    $lines[$from..($lines.Count - 1)] | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
}

$results = $null
if (Test-Path $resultsPath) { $results = Get-Content $resultsPath -Raw | ConvertFrom-Json }

if ($r.TimedOut) { Write-Host "HARNESS ERROR: game did not exit within ${TimeoutSec}s (killed)"; Show-LogTail; exit 2 }
if (-not $results -or $results.run -ne $runId) {
    Write-Host "HARNESS ERROR: no results for run $runId (game exit code $($r.ExitCode), ${secs}s). Load error, crash, or --test-ticks backstop hit."
    Show-LogTail; exit 2
}

foreach ($t in $results.results) {
    $tag = if ($t.status -eq 'pass') { 'PASS' } else { 'FAIL' }
    Write-Host ("{0}  {1}  ({2} ticks)" -f $tag, $t.name, $t.ticks)
    if ($t.message) { ($t.message -split "`n" | Select-Object -First 6) | ForEach-Object { Write-Host "      $_" } }
}
Write-Host ("tests: {0} passed, {1} failed; game exit {2}; {3}s" -f $results.passed, $results.failed, $r.ExitCode, $secs)

if ($SelfTest) {
    # Expected outcome of tests\cases\selftest.lua plus the normal suite passing.
    $byName = @{}; foreach ($t in $results.results) { $byName[$t.name] = $t }
    $expect = [ordered]@{
        'selftest: passing test still passes'       = 'pass'
        'selftest: failing assertion is reported'   = 'fail'
        'selftest: runtime error is reported'       = 'fail'
        'selftest: failure inside wait is reported' = 'fail'
        'selftest: wait_until timeout is reported'  = 'fail'
    }
    $bad = @()
    foreach ($e in $expect.GetEnumerator()) {
        $got = $byName[$e.Key].status
        if ($got -ne $e.Value) { $bad += "'$($e.Key)' expected $($e.Value), got $got" }
    }
    foreach ($t in $results.results) { if ($t.name -notlike 'selftest:*' -and $t.status -ne 'pass') { $bad += "normal test failed: $($t.name)" } }
    if ($r.ExitCode -ne 1) { $bad += "game exit code expected 1 (failures present), got $($r.ExitCode)" }
    if ($bad.Count) { Write-Host 'SELFTEST: runner misbehaved:'; $bad | ForEach-Object { Write-Host "  $_" }; exit 2 }
    Write-Host 'SELFTEST: runner reported every deliberate failure correctly'
    exit 0
}

if ($r.ExitCode -ne 0 -or $results.failed -gt 0 -or $results.passed -eq 0) { exit 1 }

# Timing budgets (2.8.6): a test logs "TT-TIMING budget_ms=<n> name=<name> Duration: <ms>ms".
$slow = $false
foreach ($m in (Select-String -Path $TT.Log -Pattern 'TT-TIMING budget_ms=(\d+) name=(\S+) Duration: ([\d.]+)ms')) {
    $budget, $name, $ms = [double]$m.Matches[0].Groups[1].Value, $m.Matches[0].Groups[2].Value, [double]$m.Matches[0].Groups[3].Value
    if ($ms -gt $budget) { Write-Host ("TIMING FAILED: {0} took {1:N0} ms (budget {2:N0} ms)" -f $name, $ms, $budget); $slow = $true }
    else { Write-Host ("timing: {0} {1:N0} ms (budget {2:N0} ms)" -f $name, $ms, $budget) }
}
if ($slow) { exit 1 }

# Smoke runs (2.8.10): the Tracktorio scenario (the way to play) and Freeplay with the mod
# on (the fallback) must both load, run, and lay out Nauvis with every city.
# (--test-ticks exits 0 when the ticks run out, 1 on any error.)
if (-not $Filter) {
    foreach ($run in @(@{ Scenario = 'tracktorio/tracktorio'; How = 'scenario' }, @{ Scenario = 'base/freeplay'; How = 'freeplay' })) {
        $s = Invoke-TTFactorio -TimeoutSec 300 -Arguments @(
            '--test-scenario', $run.Scenario, '--test-ticks', '300', '--disable-audio')
        $line = Select-String -Path $TT.Log -Pattern "tracktorio: Nauvis layout \($($run.How)\): (\d+) cities placed, (\d+) without a site" | Select-Object -Last 1
        if ($s.TimedOut -or $s.ExitCode -ne 0 -or -not $line -or $line.Matches[0].Groups[2].Value -ne '0') {
            Write-Host "SMOKE FAILED: $($run.Scenario) (exit $($s.ExitCode)) $($line.Line)"
            Show-LogTail; exit 2
        }
        Write-Host "smoke: $($run.Scenario) runs 300 ticks and lays out Nauvis ($($line.Matches[0].Groups[1].Value) cities, none missing)"
    }
}
exit 0
