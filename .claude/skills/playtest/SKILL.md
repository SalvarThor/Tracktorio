---
name: playtest
description: Prepare a manual playtest for the user, then process their findings. Only the user starts this.
disable-model-invocation: true
---

# Playtest round

1. Run `/test`. Do not start a playtest on a failing build.
2. Run `./tools/dev-instance.ps1 -Instance play`. Playtests use their own instance,
   `.factorio-play\` (mod junction, base + Space Age + train-tycoon only, no tests mod), so
   `/test` still works while the game is open. Playtests never use the user's real
   `%APPDATA%\Factorio` mods or saves.
3. Give the user a numbered checklist, short and concrete:
   - Steam shows a "run with custom arguments?" dialog on launch; the user approves it.
   - How to start: Claude runs `./tools/playtest.ps1` (MVP scenario), or
     `./tools/playtest.ps1 -Scenario <mod>/<name>`, with the PowerShell tool. If the user
     wants to start it themselves from the Claude Code prompt, the `!` prefix runs Git Bash,
     so the command is `! pwsh -NoProfile -File tools/playtest.ps1` (not `! ./tools/...`).
     The dev instance has its own graphics settings; the first launch uses defaults.
   - What to do, step by step, covering what changed since the last playtest.
   - The expected result for each step, so a deviation is obvious.
   - Which debug commands to run at the end (at least `/tt-dump`).
4. Wait for the user's report. Do not continue until they reply.
5. Then read `.factorio-play\data\factorio-current.log` and
   `.factorio-play\data\script-output\tt-dump.json`.
6. Turn findings into new or reopened items in `docs/PLAN.md`. Design questions go to the
   user. Bugs get fixed, each with a test where possible.
