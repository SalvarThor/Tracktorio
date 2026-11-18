# Train Tycoon (Factorio 2.1 mod + scenario)

A Factorio mod where trains are the whole game. Production is handled by fixed-location
"black box" cities that convert inputs to outputs automatically. The player mines raw
resources, builds the rail network and designs the stations that feed and drain the cities.

The design spec is authoritative:

@docs/SPEC.md

## Environment
- Windows, native PowerShell (not WSL). Factorio 2.1 with the Space Age DLC, same machine.
- Machine-specific paths (factorio.exe, user data dir, mods dir, log, script-output) live in
  `docs/ENV.md`. Phase 0 creates that file. Read it before running anything against the game.
- Never touch `saves\` in the Factorio user data dir. Ask before changing anything in
  `config\`.

## How to work
- Work from `docs/PLAN.md`: take the first unchecked item, finish it, tick it, commit.
- Stop at the end of every phase and report to the user before starting the next one.
- An item is done only when `/test` passes. Anything player-facing also needs a `/playtest`
  round before its phase is closed.
- Commit after each completed item. Message: `<phase>.<item>: <what changed>`.
- Do not push, and do not add git remotes, unless the user asks.
- Record every non-trivial technical or design decision in `docs/DECISIONS.md` (date,
  decision, why, alternatives rejected).
- Ask the user before: changing anything the spec decides, adding a mod dependency,
  deleting files outside the repo, or picking between options the spec leaves open.
- When unsure about a Factorio API detail, check https://lua-api.factorio.com/latest/ or the
  vanilla prototype files in the Factorio install (`data\base`, `data\space-age`) instead of
  guessing. Training knowledge is mostly 2.0; 2.1 may differ. Note any surprises in
  DECISIONS.md.

## Design guardrails (summary; SPEC.md has the detail)
- Transformation (smelting, assembling, refining, chemistry, power generation) happens only
  inside black boxes. The player gets no furnaces, assemblers, refineries, chemical plants,
  boilers, steam engines or solar.
- Transportation means trains. No cars, tanks, spidertrons or robots.
- Black boxes are hands-off: items go in and out only through inserters and pumps, never
  the player's inventory.
- Locomotive fuel comes only from depot cities (`tt-coal-fuel` in MVP). Vanilla coal is not
  a locomotive fuel. Hand-fueling is allowed; no fueling location is enforced.
- Train infrastructure, station logistics and extraction entities are free (no ingredients),
  gated by research.
- Everything not named above stays vanilla: rails, signals, schedules, interrupts, fuel,
  inserters, belts, circuits, ore patches.
- Prefer vanilla prototypes and engine behaviour over scripted reimplementation. Script only
  what the engine cannot do.
- Quality, planets and space platforms are disabled.

## Technical conventions
- Internal mod name `train-tycoon`. Prefix every prototype and storage key with `tt-`.
- Lua rules for this codebase are in `.claude/rules/factorio-lua.md` (load automatically for
  .lua files).
- Every prototype gets a locale entry in `mod/locale/en/`.
- Persistent state lives in `storage`. Schema changes go through `on_configuration_changed`
  migrations.
- Debug commands are prefixed `/tt-` and must keep working: they are how tests and playtests
  inspect state.

## Project layout
```
CLAUDE.md                this file
docs/SPEC.md             design spec (authoritative)
docs/PLAN.md             phased build plan with checkboxes
docs/DECISIONS.md        decision log
docs/ENV.md              machine paths and commands (created in Phase 0)
.claude/settings.json    permissions
.claude/rules/           path-scoped coding rules
.claude/skills/          /test and /playtest procedures
mod/                     the mod (info.json, settings.lua, data.lua, control.lua, locale/, ...)
mod/scenarios/           the MVP scenario ships inside the mod
tests/                   in-game automated tests
tools/                   PowerShell helper scripts (launch server, run tests, read log)
```

## Commands
Filled in during Phase 0. Keep this section accurate.
- Static check: `<TBD in Phase 0>`
- In-game tests: `<TBD in Phase 0>`
- Launch game with the scenario for a playtest: `<TBD in Phase 0>`
