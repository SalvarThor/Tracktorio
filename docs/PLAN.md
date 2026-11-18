# Build plan

Work top to bottom. Tick an item only when `/test` passes. Stop and report at the end of
each phase. Items marked (ASK) need the user's decision before implementation.

## Phase 0: toolchain and test harness

Goal: a trivial mod that loads in Factorio 2.1, passes static checks, and has one in-game
test that Claude Code can run and read the result of without the user.

- [x] 0.1 Locate `factorio.exe`, the Factorio user data dir (normally
      `%APPDATA%\Factorio`), the mods dir, `factorio-current.log` and `script-output\`.
      Confirm the exact Factorio version (`factorio.exe --version`) and that the
      `space-age`, `quality` and `elevated-rails` mods are present in the install's `data\`.
      Write all of it to `docs/ENV.md`.
- [x] 0.2 Fix up `.claude/settings.json` for the real paths: confirm `additionalDirectories`
      reaches the user data dir, add the Factorio install dir so vanilla prototype files in
      `data\base` and `data\space-age` can be read, and adjust the `tools/` allow rule to
      match how scripts are actually invoked. Report any rule that did not match as expected.
- [x] 0.3 `git init`, add `.gitignore`, first commit of the starter files. (Repo and
      initial commit already existed; this item extended `.gitignore`.)
- [x] 0.4 Mod skeleton in `mod/`: `info.json` (name `train-tycoon`, `factorio_version`
      matching 0.1, dependencies `base` and `space-age`), empty `settings.lua`, `data.lua`,
      `control.lua`, `locale/en/train-tycoon.cfg`.
- [x] 0.5 Make the mod live without copying: create a directory junction from the mods dir
      to `mod/`. Verify whether the folder name must be `train-tycoon` or
      `train-tycoon_<version>`. Enable it in `mod-list.json`. Confirm in
      `factorio-current.log` that the mod loads. (Done in the separate dev instance
      `.factorio\`, not the real user data dir; see DECISIONS.md.)
- [x] 0.6 Static checks: set up `lua-language-server --check` (or an equivalent that works
      headlessly on Windows) with Factorio 2.1 API type definitions. Wrap it in
      `tools/check.ps1`. A deliberate typo must fail it; clean code must pass.
- [x] 0.7 In-game test runner. (Native 2.1.24 `--test-scenario` used; see DECISIONS.md.) First try Factorio Test (mod + `npx factorio-test` CLI) on
      Windows. If that does not work, build the fallback: `tools/run-tests.ps1` starts
      `factorio.exe --start-server-load-scenario` with RCON enabled, triggers the tests
      through RCON, reads results the mod writes to `script-output\`, then shuts the server
      down. Whichever works, one trivial test must pass and one deliberately failing test
      must be reported as failed.
- [x] 0.8 Debug command skeleton: `/tt-dump` writes a JSON snapshot of `storage` to
      `script-output\tt-dump.json`.
- [x] 0.9 Fill in the Commands section of CLAUDE.md and the placeholders in
      `.claude/skills/test/SKILL.md` and `.claude/skills/playtest/SKILL.md`.
- [x] 0.10 Investigate the technical assumptions below and record findings in
      DECISIONS.md. Do not implement them yet; report options where an assumption fails.
  - A1. Recipes with an empty ingredient list are allowed in 2.1 and craft instantly.
  - A2. A black box can be an `assembling-machine` prototype with `fixed_recipe`, a void
        energy source, no item to place it, not minable, not player-destructible, placed by
        script. Engine behaviour then already gives "rate of slowest input" and output
        backpressure. Also find how to stop the player moving items into or out of a
        black box by hand (opening its GUI, ctrl-click, ctrl-right-click, drag). Inserters
        and pumps must still work. If the engine has no clean flag for this, a scripted
        fallback that returns hand-moved items is acceptable.
  - A3. Limp mode can be done without per-tick scripting, for example a hidden reserve fuel
        item with a low `fuel_top_speed_multiplier` inserted by script when a locomotive's
        fuel runs out, removed when real fuel arrives. Find out whether this or another
        approach works, and what it costs in UPS.
  - A4. Coal fuel: a new item `tt-coal-fuel` is the only locomotive fuel in MVP, and
        vanilla coal must stop being accepted as locomotive fuel (for example by removing
        its fuel value or moving it to a fuel category locomotives don't burn). Check what
        that breaks: burner mining drills, burner inserters and anything else that burns
        coal. Report options for those.
  - A5. Power city: how a black box turns water + coal into electricity on the player's
        network (for example scripted output into an `electric-energy-interface` scaled by
        actual throughput).
  - A6. How to restrict hand crafting to the free logistics recipes, and fully remove
        vehicles, robots and transformation entities (recipes, technologies, items in
        starting inventory).
  - A7. Any 2.1 API changes relevant to the above compared with 2.0.

Stop. Report to the user.

## Phase 1: MVP

Goal: the MVP described in SPEC.md, playable start to win.

- [x] 1.1 Prototype restrictions (A6): remove transformation entities, vehicles and robots
      from the player; free logistics recipes (A1 or its fallback); MVP starting research.
      Quality and planets off.
- [x] 1.2 Black box framework (A2): one definition table per box type (recipe profile,
      crafting speed, size, sprite), prototype generation in the data stage, script
      placement, protection and hands-off enforcement (A2) in the control stage.
- [x] 1.3 Iron smelting city, copper smelting city and depot city (coal in, `tt-coal-fuel`
      out), plus the `tt-coal-fuel` item and the change that stops vanilla coal working as
      locomotive fuel (A4).
- [x] 1.4 Power city (A5).
- [x] 1.5 Goal box and win condition: counts cumulative iron and copper plates delivered,
      targets from a runtime mod setting (default 20,000 each), victory when both totals
      are reached. Show progress to the player.
- [x] 1.6 Black box UI: recipe, current output rate/min, status (running, starved on which
      input, output full).
- [x] 1.7 Limp mode for fuel-empty trains (A3). No fueling restriction is enforced; hand
      fueling stays allowed. If limp mode proves too complex, (ASK) about the spec's
      fallback.
- [x] 1.8 Scenario: generated by script on init so it is reproducible (tiles, water, ore
      and coal patches, box placement, starting inventory). Patches far from the boxes they
      feed, with one depot city near the start. Small map.
- [x] 1.9 End-to-end in-game test: a scripted setup where a train hauls ore and coal to a
      smelting city and plates to the goal box, and the goal box registers the rate.
- [x] 1.10 `/playtest` round with the user. Fix findings. Tune targets.
  Round 1 (2026-11-18) findings:
  - [x] Power city showed as "Power city generator", couldn't be clicked and never showed
        "Output full": the hidden generator was selectable over the city. It now has no
        selection box.
  - [x] Crafting menu listed non-free recipes as red, uncraftable entries: now hidden from
        player crafting.
  - [x] Map labels for cities: chart tags with icon and name.
  - [x] Goal box kept accepting a metal past its target: slots for a met metal now close.
  - [x] `!` prompt runs Git Bash, so `! ./tools/playtest.ps1` failed: docs fixed.
  - [x] Playtests and tests shared `.factorio\`, so tests couldn't run while a playtest was
        open: playtests now use `.factorio-play\` (no tests mod).
  - [x] Steam asks "run with custom arguments?" on GUI launch: accepted by the user (one click).
  - [x] Cities need power (user, SPEC updated): the depot draws up to 840 kW (chemical plant
        equivalent), shows No power / Low power; smelting cities stay coal-fired.
  - [x] Limp speed lowered to 10%; locomotives stay free (user).
  Round 2 (2026-11-18) findings:
  - [x] Re-checked in game: power city window, crafting menu, map tags, depot power, goal box
        closing per metal and victory, limp 10%. `tt_hand_transfers` = 0, log clean.
  - [x] Crash clicking the power city: `LuaEntity.fluidbox` no longer exists in 2.1 (the
        fluid-input path of the city window). Fixed with `get_fluid_count`, plus a regression
        test that opens a fluid-starved city's window.
  - [x] Power city window said "Output full: take products out": now "Idle: no power demand"
        for the power city; other cities show a short status plus a hint line.
  - [x] City windows now start with the same description as the tooltip.
  - [x] Clicking the goal box did nothing: it now has a window (delivered / target / rate,
        accepting or closed, per metal).
  - [x] Low power couldn't be tested by hand: covered by an automated test (depot on a
        300 kW supply reports low power and keeps crafting slowly).
  Carried over (user, at close):
  - Rates and the 20,000 goal are judged in longer playthroughs, not tuned yet. City caps are
    the first tier's limit; tier upgrades (post-MVP 1) raise them.
  - Round 2's last fixes (window descriptions, power idle wording, goal box window) are
    covered by tests but not yet seen in game.
Stop. Report to the user.

## Phase 2 onwards

Follow the post-MVP order in SPEC.md. Break each step into items here before starting it,
and get the user's OK on the breakdown.
