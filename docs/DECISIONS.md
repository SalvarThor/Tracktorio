# Decision log

Newest first. One entry per decision: date, decision, why, alternatives rejected.
Design decisions made before the build started are in SPEC.md; this log covers what is
decided during the build.

## 2026-11-18: Storage key prefix is `tt_`; debug commands have a remote twin
- Decision: storage keys use `tt_` (e.g. `storage.tt_schema`), not `tt-`. Every `/tt-*`
  debug command calls a function that is also exposed on the remote interface `tt-debug`.
- Why: Lua identifiers can't contain `-`, and `storage["tt-x"]` everywhere is noisy. Scripts
  can't execute console commands, and `helpers` can't read files (2.1.24), so tests reach
  the same code through `remote.call("tt-debug", ...)`, which returns the data.
- Rejected: `storage["tt-..."]` keys; reading script-output back from tests (no API).

## 2026-11-18: In-game tests use the native `--test-scenario` mode
- Decision: tests run with Factorio 2.1.24's built-in `--test-scenario MOD/NAME`, which is
  headless with a player, runs until `script.finish_test(passed)` and exits 0 or 1. The
  scenario `tt-tests` lives in a separate mod `train-tycoon-tests` (`tests\`), junctioned
  only into the dev instance. Its scenario script runs a small runner
  (`tests\runner.lua`: sync tests plus `ctx:wait`/`ctx:wait_until` across ticks). Results go
  to `script-output\tt-test-results.json`. `tools\run-tests.ps1` wraps it all.
- Why: no RCON client, no server process, no Node and no extra mod dependency. One run
  takes ~2.5 s. Load errors and uncaught mod errors exit 1 promptly with the error in the
  log (verified). The runner sits in the scenario's own Lua state, so its `on_tick` can't
  overwrite the mod's handlers. Tests inspect the mod through game state, `/tt-` commands and
  remote interfaces.
- Caveat (2.1 surprise): `--test-ticks N` exits with **0** when the tick limit is hit.
  The wrapper therefore accepts a pass only if a results file carrying this run's id exists
  and reports failed=0, passed>0.
- Rejected: Factorio Test (needs Node, a portal mod dependency, and has unknown 2.1 support).
  A server with RCON (more moving parts, and the process has to be killed).
- Later: unit tests of mod internals, if needed, through a `tt-test` remote interface that
  the mod registers only when `train-tycoon-tests` is active.

## 2026-11-18: Separate dev/test Factorio instance
- Decision: all dev, test and playtest runs use a separate write-data dir at
  `<repo>\.factorio\` (gitignored), selected with `factorio.exe --config`. Its mods dir holds
  junctions to `mod\` and `tests\` and a mod-list with only base, Space Age (+ its deps) and
  the project mods. Built by `tools\dev-instance.ps1`.
- Why: the real `%APPDATA%\Factorio\mods` has ~90 enabled mods (Krastorio2, Factorissimo,
  ...). Enabling train-tycoon there would mix it into the user's modpack and make tests
  depend on it. A separate write-data dir also avoids the user-data lock, so tests run while
  the user plays, and keeps logs and script-output apart.
- Findings: the unversioned folder name `train-tycoon` works for a junctioned mod (2.1.24).
  A data-stage error exits with code 1 headless, without a blocking dialog.
- Rejected: editing the real mod-list.json (PLAN 0.5 as written); `--mod-directory` alone
  (still shares the log, script-output and lock with the real game).

## 2026-11-18: Development environment
- Decision: Claude Code runs natively in PowerShell on the same Windows machine as
  Factorio. Target Factorio 2.1 with Space Age.
- Why: Factorio is a Windows program here; its user data, mods dir and log are reachable
  directly. WSL would route every path through /mnt/c and Windows interop.
- Rejected: WSL; Linux headless server (not available on this machine).

## 2026-11-18: No other mods in MVP
- Decision: no mod dependencies beyond `base` and `space-age`. Black boxes use scaled
  vanilla sprites as placeholders.
- Why: Factorissimo graphics license is unconfirmed, and depending on the mod drags in its
  mechanics.
- Rejected: Factorissimo as a dependency.
