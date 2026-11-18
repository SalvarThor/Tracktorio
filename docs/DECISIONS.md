# Decision log

Newest first. One entry per decision: date, decision, why, alternatives rejected.
Design decisions made before the build started are in SPEC.md; this log covers what is
decided during the build.

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
