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
Filled in by 0.7 results.

## Toolchain
Filled in by 0.6.
