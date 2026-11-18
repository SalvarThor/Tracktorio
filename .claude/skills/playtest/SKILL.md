---
name: playtest
description: Prepare a manual playtest for the user, then process their findings. Only the user starts this.
disable-model-invocation: true
---

# Playtest round

1. Run `/test`. Do not start a playtest on a failing build.
2. Make sure the mod is enabled in `mod-list.json` and no Factorio server is still running.
3. Give the user a numbered checklist, short and concrete:
   - How to start: `<TBD in Phase 0: launch command or menu path to the scenario>`
   - What to do, step by step, covering what changed since the last playtest.
   - The expected result for each step, so a deviation is obvious.
   - Which debug commands to run at the end (at least `/tt-dump`).
4. Wait for the user's report. Do not continue until they reply.
5. Then read `factorio-current.log` and `script-output\tt-dump.json` (paths in
   docs/ENV.md).
6. Turn findings into new or reopened items in `docs/PLAN.md`. Design questions go to the
   user. Bugs get fixed, each with a test where possible.
