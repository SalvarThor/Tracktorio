# Environment (this machine)

Created in Phase 0.1. Keep it accurate; tools/ scripts read the same paths.

## Factorio install (Steam, read-only)
- Install dir: `C:\Program Files (x86)\Steam\steamapps\common\Factorio`
- Executable: `C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe`
- Version: **2.1.24** (build 87808, win64, steam). Check with `factorio.exe --version`.
- Built-in mods in `data\`: `base`, `core`, `elevated-rails`, `quality`, `recycler` (new in
  2.1), `space-age`. All 2.1.24.
- API docs for this exact version: `doc-html\runtime-api.json`, `doc-html\prototype-api.json`
  (plus the HTML pages in `doc-html\`).
- The Steam exe runs directly (no Steam relaunch) for `--version`/`--help` while Steam is
  running. Unattended headless runs: see "Unattended launch" below.

## Real user data dir (read-only for this project)
- `C:\Users\Notandi\AppData\Roaming\Factorio` (`%APPDATA%\Factorio`)
- Holds the user's own modpack (~90 mods), saves and config. **The project never writes
  here.** `saves\` is denied in settings.json.

## Dev/test instance (used by all tools)
A separate Factorio write-data dir inside the repo, gitignored. Only base, Space Age and
the project's mods are enabled. It does not lock or touch the real user data dir, so tests
can run while the user plays.

- Root: `<repo>\.factorio\` (`C:\Users\Notandi\Documents\GitHub\TrainTycoon\.factorio\`)
- Config: `.factorio\config\config.ini` (pass with `--config`)
  - `read-data=__PATH__executable__/../../data`
  - `write-data=<repo>/.factorio/data`
- Mods dir: `.factorio\data\mods\` (junctions to `mod\` and `tests\`, plus `mod-list.json`)
- Log: `.factorio\data\factorio-current.log`
- Script output: `.factorio\data\script-output\`
- Created and repaired by `tools\dev-instance.ps1` (idempotent).
- Playtest instance: `<repo>\.factorio-play\`, same layout, created with
  `tools\dev-instance.ps1 -Instance play` and used by `tools\playtest.ps1`. It loads
  train-tycoon only (no tests mod). It is separate so tests can run while a playtest is open
  (Factorio locks the write-data folder of a running game). Its log is
  `.factorio-play\data\factorio-current.log`; `/tt-dump` writes
  `.factorio-play\data\script-output\tt-dump.json`.

**Junctions:** never `Remove-Item -Recurse` a junction in `.factorio\data\mods\`, because it
can delete the repo's files through it. Remove junctions with
`[System.IO.Directory]::Delete($path)` (non-recursive).

## Useful command-line options (2.1.24)
- `--test-scenario [MOD/]NAME`: headless with a player, runs until a script calls
  `script.finish_test(passed)`. Exit 0 = passed, 1 = failed or error.
- `--test-ticks N`: exit 0 after N ticks if the test hasn't finished (so scripts must call
  `finish_test(false)` themselves on timeout).
- `--test-arg STRING`: readable as `script.test_arg`.
- `--dump-data`: writes `data.raw` as JSON to script-output and exits (prototype probes).
- `--load-scenario [MOD/]NAME`: GUI client, singleplayer (playtests).
- `--start-server-load-scenario`, `--rcon-port`, `--rcon-password`: server mode (not used
  by the test runner).

## Unattended launch
Verified 2026-11-18 with the Steam client running: launching
`bin\x64\factorio.exe` directly works unattended for `--version`, `--help`, `--dump-data`
and `--test-scenario`. Steam doesn't relaunch it, nothing needs a click, and no window opens
(`Running in headless mode`). A test run takes ~2.5 s wall-clock.
GUI launches (`tools\playtest.ps1`) behave differently: Steam opens and shows a dialog asking
whether to run Factorio with custom arguments, and the game starts after the user approves
it (playtest 1.10). Headless runs (`--test-scenario`, `--dump-data`) show no dialog.

Also verified 2026-11-18 with the Steam client **closed**: the test suite passes the same
way, and Steam is not started.

## In-game tests
- `./tools/run-tests.ps1 [-Filter <text>] [-SelfTest]`: see the script header.
- Results: `.factorio\data\script-output\tt-test-results.json`. Each line also goes to
  the log as `TT-TEST PASS|FAIL <name>`.
- Exit codes: 0 pass, 1 test failures, 2 harness error (load error, mod crash, timeout,
  no or stale results). The log tail is printed for 2.

## Toolchain
- Node.js 26.13.1 (`winget install OpenJS.NodeJS.LTS`), `C:\Program Files\nodejs\`.
- lua-language-server 3.19.2 (`winget install LuaLS.lua-language-server`), on PATH as
  `lua-language-server`.
- FMTK (`factoriomod-debug` 2.1.9, repo devDependency) generates LuaLS types from the
  install's `doc-html\*.json` into `tools\types\` (gitignored):
  `npx fmtk luals-addon -d <runtime-api.json> -p <prototype-api.json> tools/types`.
  `tools\check.ps1` does this automatically when the types are missing; run
  `./tools/check.ps1 -Regenerate` after a Factorio update.
- LuaLS config: `.luarc.json` (Lua 5.2, FMTK plugin, `undefined-global`/`undefined-field`
  as errors, ignores `.factorio\` so the junctions aren't scanned twice).
- winget changes PATH only for new shells. The tools scripts re-read PATH from the registry
  so they work in an already-open session.
