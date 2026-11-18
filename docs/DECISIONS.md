# Decision log

Newest first. One entry per decision: date, decision, why, alternatives rejected.
Design decisions made before the build started are in SPEC.md; this log covers what is
decided during the build.

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
