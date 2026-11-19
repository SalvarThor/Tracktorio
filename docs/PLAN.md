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

### Phase 2.1: city tier upgrades (approved by the user 2026-11-18)

Decided with the user (DECISIONS.md, 2026-11-18):
- 3 tiers at x1 / x2 / x4 of tier 1's cap.
- A city's upgrade never uses its own product. Until intermediate cities exist, costs are
  other cities' plates.
- Smelting cities go electric from tier 2: no coal, they draw power like electric furnaces.
- Materials are delivered to a construction port beside each city. The upgrade happens
  automatically when the port has everything.

Proposed numbers (tuning values, revisited in playtest):

| City | T1 | T2 | T3 | T2 cost | T3 cost |
|---|---|---|---|---|---|
| Iron smelting | 900 plates/min, coal | 1800/min, ~8.6 MW, no coal | 3600/min, ~17.3 MW | 2,000 copper | 6,000 copper |
| Copper smelting | same | same | same | 2,000 iron | 6,000 iron |
| Depot | 2 fuel/s, 840 kW | 4/s, 1.68 MW | 8/s, 3.36 MW | 1,000 iron + 1,000 copper | 3,000 + 3,000 |
| Power | 5.4 MW | 10.8 MW | 21.6 MW | 1,000 iron + 1,000 copper | 3,000 + 3,000 |

Electric smelting power: an electric furnace makes 0.625 plates/s at 180 kW, so 30 plates/s
needs 48 furnaces, about 8.6 MW. Upgrading the smelters therefore needs the power city
upgraded first. That's an intended chain.

- [x] 2.1.1 Tier definitions and prototypes. Each upgradable city gets a per-tier table
      (speed, power, recipe) in `prototypes/cities.lua`, and the generator builds
      `tt-city-<name>-t2/-t3`. Tier 1 keeps its current name so MVP saves still load. Tier 2+
      smelting recipes have no coal. Each power city tier has its own hidden generator.
      Locale for every new prototype.
- [x] 2.1.2 Construction port. A fixed 1x1 container on the tile west of the city's top-left
      corner (its east side touches the city; north, west and south are free for
      inserters). It is placed and protected like a city. No inserter or power between port
      and city: once a second the script empties the port into the upgrade's progress
      counter (the goal-box mechanism), and materials never enter the city. Slot filters
      list only the materials the next tier still needs. It closes at max tier. Delivery
      rate tops out around 7 plates/s (3 fast inserters); a 1x2 port is the fallback if
      that is too slow.
- [x] 2.1.3 Upgrade in place. When the port is complete, the city is replaced by its next tier
      at the same position. Input and output contents carry over. Leftover inputs the new
      recipe can't use (coal after going electric) move to the port's output slot or are
      dropped beside the city. The power city's generator is replaced and relinked, and
      storage, the open window and rate sampling follow the new entity. Tests cover:
      - new cap and power draw
      - backpressure still working
      - the power city's output
- [x] 2.1.4 UI. The city window shows the tier, the cap now and at the next tier, and the
      next tier's materials with progress. The port has its own window. Map tags show the
      tier ("Iron smelting city T2"). Notifications (user request):
      - On upgrade: a chat message with a map link, naming what changed for the station
        (new cap; power draw; "no longer uses coal" when going electric). It adds a warning
        if the city's pole network looks too weak for the new draw.
      - A custom alert with the city's icon; clicking it zooms to the city, and it clears
        after a while.
      - Flying text over the city.
      - One heads-up message when a port reaches 90%, so power can be ready before the
        automatic swap.
- [x] 2.1.5 Save migration and map. MVP saves get tier 1 records and ports placed on
      configuration change. Check the scenario layout has room for every port. Tests load an
      MVP-era state and upgrade it.
- [x] 2.1.6 `/playtest` round: upgrade path, numbers, port placement. (Playtest helper:
      `/tt-port-fill <percent>` on the city or port under the cursor.) Round 2026-11-18: all
      steps passed (ports, windows, real delivery, heads-up, upgrade to tier 2 and 3, electric
      city on the power network); no errors in the log. Numbers fine for now; revisit after a
      full run. Finding: no visible sign of a city's tier in the world (2.1.7).
- [x] 2.1.7 Visual tier indicator on the city in the world (user request, playtest 2.1.6).
      User chose pips: one per tier on the city's top edge, filled up to its tier. Built and
      tested; playtest 2026-11-18: fine, radius cut to 75% (0.34).

### Phase 2.2: intermediate cities, research complex, research gating (approved 2026-11-18)

Decided with the user (DECISIONS.md, 2026-11-18):
- Scope: red and green science. Oil and blue science come with the rocket chain (SPEC step 5).
- The research complex is a fixed, protected lab prototype; the engine runs research. Labs
  stay banned for the player. Tiers raise its research speed.
- Research gates player items and bonuses only (vanilla tree). Every city works from the start.
- The win condition stays the plates goal.

Proposed numbers (tuning values; power = the equivalent vanilla buildings):

| City | Inputs | Output T1 | Power T1 | Equivalent |
|---|---|---|---|---|
| Circuit city | 5 iron/s + 7.5 copper/s | 300 circuits/min | ~1.25 MW | 8 assemblers 2 |
| Red science city | 2 iron/s + 1 copper/s | 60 packs/min | ~1.1 MW | 7 assemblers 2 |
| Green science city | 4.5 iron/s + 1 circuit/s | 60 packs/min | ~1.5 MW | 10 assemblers 2 |
| Research complex | red + green packs | speed of 20 labs | 1.2 MW | 20 labs |

All get 3 tiers at x1/x2/x4 and a construction port; upgrades never use the city's own
product. Gears and cables stay inside the cities; circuits are shipped.

- [x] 2.2.1 City framework: any fixed recipe with several inputs, tiers, power, port, window
      and pips works from a city definition alone (no per-city code).
- [x] 2.2.2 Circuit, red science and green science cities: prototypes, recipes, power, tiers,
      costs, locale.
- [x] 2.2.3 Research complex: lab-based city, protected, tiers by research speed, port. Its
      window shows the current research and missing packs, or "no research selected".
- [x] 2.2.4 Research gating: every technology needing only red and green science is
      researchable; techs needing other packs stay locked and visible; techs whose unlocks are
      all banned stay as prerequisites. Tests prove the red/green tree can be completed.
- [x] 2.2.5 Upgrade costs use intermediates: tier 3 costs of the existing cities partly move to
      circuits.
- [x] 2.2.6 Bigger map (about 960x600) with the new cities, a second iron patch and room for
      every port. 2.1 saves get the new cities where the tiles are free, otherwise a message.
- [x] 2.2.7 UI and map tags for the new cities, including research complex statuses.
- [x] 2.2.8 `/playtest` round: research flow, rates, power demand, map layout.
      Result (2026-11-19): all 10 steps passed. Fixed: the city window repeated the
      tooltip's "Click it for details"; the tier line ran "labsDraws" together (tests added).
      Follow-ups (user, 2026-11-19; see DECISIONS.md):
      - Distances are far too short for a real train network. The map stays small while
        the main mechanics are built; a full-size map comes for whole-mod testing.
      - Inserting is almost always the bottleneck. No inserter or city changes for now.

### Phase 2.3: reliability, depot servicing, repair pack city (proposed 2026-11-19)

Decided with the user (DECISIONS.md, 2026-11-19):
- Reliability is the locomotive's health. It drains with driving; the vanilla health bar
  shows it, and manual repair is the vanilla repair-pack tool.
- Servicing: a locomotive stopped at any train stop near a depot city is repaired, using
  repair packs from the depot's service port (a fixed 1x1 port that takes only repair packs).
  Inserters can't put packs into the depot itself (only recipe ingredients go in).
- Starting decay: about 10 minutes of driving until breakdowns get frequent.
- One locomotive type for now; the decay rate is per locomotive prototype so tiers can come
  later.

Proposed numbers (tuning values):
- Driving (speed above zero) drains 7.5% of max health per minute: 100% -> 25% in 10 min.
  Decay never takes a locomotive below 10%, so wear alone never destroys one.
- While moving, each second a locomotive may break down with chance
  0.02 x (1 - health)^2: about 0 when new, ~1.1% per second at 25% (a breakdown within
  about 1.5 minutes).
- Broken: the locomotive burns the limp fuel even with real fuel inside (same slow top speed
  as fuel-empty limp mode), so its whole train crawls. Cured at full health, by servicing or
  by hand.
- Servicing restores 100 HP per second and uses 1 repair pack per 300 HP (the vanilla
  pack's durability): a full service from 25% takes ~8 s and 2.5 packs.
- Service area: a train stop within 30 tiles of the depot city's edge.
- Repair pack city: 1 circuit + 2 iron -> 1 repair pack (vanilla), tier 1 30 packs/min,
  power as the equivalent assemblers. Tiers x1/x2/x4; costs plates, circuits at tier 3.

- [x] 2.3.1 Reliability: decay with driving (per-prototype rate, 10% floor), periodic sliced
      polling like limp mode, `/tt-reliability <percent>` on the selected locomotive (and its
      remote twin). Tests: decay while driving, none while stopped, the floor.
- [x] 2.3.2 Breakdowns: chance per second from health, broken locomotives limp until at full
      health, manual repair cures. Alert and chat message with a map link when a train breaks
      down. Tests: forced breakdown limps the whole train; repairing to full cures it; a
      fuel-empty limp and a breakdown don't fight.
- [x] 2.3.3 Service port and servicing: fixed port beside every depot tier (placed,
      protected, survives upgrades), stop-within-range detection, repair at the set rate,
      pack use, no packs = no servicing. Depot window shows packs in the port and trains
      serviced. Tests for each.
- [ ] 2.3.4 Repair pack city: prototype, tiers, costs, locale, window, port, pips; a spot on
      the test map. Existing saves get it (and depot service ports) on configuration change;
      mod 0.3.0.
- [ ] 2.3.5 `/playtest` round: decay and breakdown feel, servicing station design, pack
      supply line, numbers.
