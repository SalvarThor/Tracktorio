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
- Repair pack city: 2 circuits + 4 iron -> 1 repair pack (vanilla: 2 circuits + 2 gears; the plan
  first said 1 + 2 by mistake), tier 1 30 packs/min (150 kW, one assembler 2),
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
- [x] 2.3.4 Repair pack city: prototype, tiers, costs, locale, window, port, pips; a spot on
      the test map. Existing saves get it (and depot service ports) on configuration change;
      mod 0.3.0.
- [x] 2.3.5 `/playtest` round: decay and breakdown feel, servicing station design, pack
      supply line, numbers.
      Result (2026-11-19): steps 1-7 passed, 8 (no packs) not fully tested. Fixed: a train
      stopped by hand at the stop was never serviced (now any standing train with a
      locomotive within 10 tiles of a stop in range counts; test added). Changed: limp
      top speed 10% -> 25% and acceleration 25% -> 60%, since a train with wagons barely
      moved (also applies to fuel-empty limp). Breakdown rate fine for testing, too fast
      for real play: retune later. Messages fine.

### Phase 2.4: fuel progression (proposed 2026-11-19)

Decided with the user (DECISIONS.md, 2026-11-19):
- Better fuels come from two new depot-type cities, so locomotive fuel still comes only
  from depots: a solid fuel depot and a rocket fuel depot. Each has a service port like the
  coal depot.
- A refinery city turns crude oil + water into light oil and petroleum gas; heavy oil is
  cracked inside. Gas has no use yet (plastics/blue science later); a full gas output
  stalls the refinery like any full output.
- Vanilla fuel stats: coal fuel 10 MJ (no bonus), solid fuel 12 MJ (+20% acceleration,
  +5% top speed), rocket fuel 100 MJ (+80% acceleration, +15% top speed).
- Oil is gated by the vanilla Oil gathering research (red + green, 100 units), which
  unlocks the free pumpjack. Every city works from the start, as before.

Proposed numbers (tuning values; power = the equivalent vanilla buildings):

| City | In (per s) | Out (per s) | Power T1 | Equivalent |
|---|---|---|---|---|
| Refinery city | 40 crude oil + 28 water | 26 light oil + 22 petroleum gas | ~0.95 MW | 2 refineries + cracking |
| Solid fuel depot | 20 light oil | 2 solid fuel (24 MW of fuel) | 420 kW | 2 chemical plants |
| Rocket fuel depot | 2 solid fuel + 2 light oil | 0.2 rocket fuel (20 MW of fuel) | 600 kW | 4 assemblers 2 |

Recipes: refinery 100 crude + 70 water -> 65 light + 55 gas (vanilla advanced processing
with the heavy oil cracked); solid fuel 10 light oil -> 1 (vanilla); rocket fuel 10 solid
fuel + 10 light oil -> 1 (vanilla). One refinery city at tier 1 feeds both fuel depots at
tier 1. Tiers x1/x2/x4; costs plates at tier 2, plates + circuits at tier 3.

- [x] 2.4.1 Fuels: solid fuel and rocket fuel burn in locomotives (added to the locomotive
      fuel category, vanilla stats kept, still burnable where vanilla burns them); vanilla
      coal still can't fuel a locomotive. Limp mode and breakdowns treat them like coal
      fuel. Tests: each fuel's top speed and acceleration on a real train.
- [x] 2.4.2 Fluid cities: a city can have several fluid inputs and outputs on fixed pipe
      positions. The window and description say which fluid goes where; a full fluid
      output shows "output full" naming the fluid. Tests with infinity pipes (the multi-fluid
      ones run on the refinery city, 2.4.3).
- [x] 2.4.3 Refinery city: prototype, recipe, power, tiers, costs, locale, window, port,
      pips. Graphics: it takes the oil refinery look, so the power city moves to the centrifuge
      look (all placeholders until Factorissimo art).
- [x] 2.4.4 Solid fuel depot and rocket fuel depot: depot-type cities (service port,
      servicing, window section), tiers, costs, locale.
- [x] 2.4.5 Map: a crude oil field and spots for the three cities on the test map; older
      saves get them. Research: Oil gathering is reachable and Oil processing's trigger
      (mine crude oil) fires from a pumpjack. Mod 0.4.0.
- [x] 2.4.6 `/playtest` round: oil chain, fluid wagons, fuel feel on trains, numbers.
      Result (2026-11-19): steps 1-7, 9, 10 passed; step 8 (servicing at a fuel depot) was
      not tried in game, so a test now covers it. Fuel differences noticeable (solid over
      coal, rocket over solid). Fixed: pipe positions now read "bottom left / top right"
      instead of tile counts; the coal depot is now "Coal fuel depot" (old map tags renamed
      on load, mod 0.4.1); an unpowered city's window now shows what each input holds and
      what is missing; MW figures show up to two decimals (0.95, not 1.0). Open idea
      (user): drop the "city" naming at some point; it fits less the deeper the chain goes.

### Phase 2.5: full chain to a rocket silo (proposed 2026-11-19)

Decided with the user (DECISIONS.md, 2026-11-19):
- Launching the first rocket wins. New maps have no plates goal box; in older saves it
  stays but no longer decides the win.
- Fine split, one product per city: steel, plastic, sulfur, sulfuric acid, advanced
  circuits, processing units, low density structure, blue science, rocket silo (9 new,
  22 city types in all). Sulfur gets its own city because blue science needs it as an
  item and sulfuric acid is made from it.
- Blue science is in: a blue science city, and the research complex accepts blue packs.
- The rocket silo city works from the start, like every city.

Proposed numbers (vanilla 2.0 recipes, with gears, cables, engines and pipes made inside;
power = the equivalent vanilla buildings; tuning values):

| City | In (per s) | Out (per s) | Power T1 |
|---|---|---|---|
| Steel | 5 iron | 1 steel | ~1.44 MW (8 electric furnaces) |
| Plastic | 30 petroleum gas + 1.5 coal | 3 plastic | ~315 kW |
| Sulfur | 15 petroleum gas + 15 water | 1 sulfur | ~105 kW |
| Sulfuric acid | 0.5 sulfur + 0.1 iron + 10 water | 5 sulfuric acid | ~100 kW |
| Advanced circuits | 2 green circuits + 2 plastic + 2 copper | 1 advanced circuit | ~1.35 MW |
| Processing units | 4 green + 0.4 advanced circuits + 1 sulfuric acid | 0.2 processing units | ~400 kW |
| Low density structure | 0.4 steel + 4 copper + 1 plastic | 0.2 LDS | ~600 kW |
| Blue science | 0.2 steel + 0.8 iron + 0.3 advanced circuits + 0.1 sulfur | 0.2 packs | ~1 MW |
| Rocket silo | 10 processing units + 10 LDS + 10 rocket fuel per part (own recipe; Space Age's is 1+1+1) | 1 part / 3 s; 50 parts = 1 rocket | vanilla silo |

A rocket needs 500 processing units, 500 LDS and 500 rocket fuel: about 42 minutes of
each tier 1 chain end at 0.2/s. Tiers x1/x2/x4 as usual; upgrade costs plates, then
circuits (and later advanced circuits) at tier 3.

- [x] 2.5.1 Steel city (electric from tier 1, like electric furnaces).
- [x] 2.5.2 Chemistry cities: plastic, sulfur, sulfuric acid (fluid inputs/outputs, pipe
      positions in the window).
- [x] 2.5.3 Electronics cities: advanced circuits and processing units.
- [x] 2.5.4 Low density structure city.
- [x] 2.5.5 Blue science city; the research complex accepts blue packs (all tiers, existing
      saves too). Gating tests for the blue part of the tree: what becomes reachable, and
      any research triggers that block it.
- [x] 2.5.6 Rocket silo city. First check in 2.1 whether a vanilla rocket-silo prototype can
      be a city (fixed recipe, protected, launches on its own with no space platforms,
      raises on_rocket_launched). Fallback: an assembling-machine city that builds the
      rocket from parts and a scripted launch. Window shows parts progress.
- [x] 2.5.7 Win condition: the first launch wins (victory screen, message). New maps get no
      goal box; in older saves it stays, says it no longer decides the win, and the goal
      panel shows rocket progress instead of plates.
- [x] 2.5.8 Map: spots for the 9 new cities on the test map (no new resources needed);
      older saves get them; mod 0.5.0.
- [x] 2.5.9 `/playtest` round: chain overview, blue research, the silo and a launch
      (helpers to skip ahead), numbers. Playtest 2026-11-20: all passed. Found: the
      single-tier silo drew one tier pip; fixed (no pips below 2 tiers, migration removes
      the old one, mod 0.5.1, tested). Open design question for the user: the power
      budget (T1 cities need ~13 MW against one 5.4 MW power city; all at T3 ~88 MW
      against 21.6 MW). See DECISIONS 2026-11-20.

### Phase 2.6: power expansion (approved by the user 2026-11-20)

Decided with the user (DECISIONS.md, 2026-11-20):
- The full chain needs ~13 MW at T1 and ~88 MW at T3 against one power city's 5.4 / 21.6
  MW. Two answers, so the player picks a challenge: more coal power cities, or nuclear.
- 3 more coal power cities (4 in all, ~86 MW at T3: coal alone just covers everything).
- Nuclear is its own city, not a power city tier. 20 / 40 / 80 MW. No depleted cells
  out. Gated naturally: uranium needs the vanilla Uranium mining research (red, green,
  blue) and sulfuric acid at the miner.
- Elevated rails moves to after this phase.

Proposed numbers (tuning values):

| City | In (per s) | Out | Power |
|---|---|---|---|
| Uranium (T1) | 1.43 uranium ore + 0.01 iron | 0.01 fuel cells/s (enough for a T3 nuclear city) | ~0.6 MW (1.7 centrifuges) |
| Nuclear power (T1) | 0.0025 fuel cells (1 per 400 s) + ~206 water | 20 MW | - |

Uranium ratio is vanilla without Kovarex: 10 ore -> 0.7% U-235, 1 U-235 per 10 cells, so
~143 ore per cell; spare U-238 stays inside.

- [x] 2.6.1 Three more coal power city spots and a second lake (spread out so each is its
      own route); map tags; older saves get them. Check whether coal needs a second patch.
      (East (450, 110), West (-460, -120), South (-280, 280); lake 2 at (-330, 90); no second
      coal patch; mod 0.6.0.)
- [x] 2.6.2 Uranium ore patch, far from the cities. Check in 2.1: Uranium mining is
      reachable in the red/green/blue zone (its Concrete prerequisite included), and an
      electric mining drill on uranium takes sulfuric acid. Gating test. (Patch at
      (310, 275). Concrete was unreachable: fixed by splicing hidden techs out of the tree.)
- [x] 2.6.3 Uranium city (ore + iron -> uranium fuel cells), tiers x1/x2/x4. (At (160, 0).)
- [x] 2.6.4 Nuclear power city (fuel cells + water -> electricity on the pole network),
      20 / 40 / 80 MW, window shows fuel and water use. Prefer a vanilla reactor/heat
      chain inside the city over a scripted generator if 2.1 allows it; check first.
      (Burner city + hidden 500 C generator; at (-40, 170).)
- [x] 2.6.5 Power-budget test: the total demand of every electric city per tier against
      the coal-only and the nuclear supply, so a retune can't silently break the balance.
      (Demand 17.9 / 49.0 / 94.1 MW; coal 21.6 / 43.2 / 86.4; nuclear 20 / 40 / 80.)
- [x] 2.6.6 `/playtest` round: the new power cities, uranium mining with acid, nuclear.
      Playtest 2026-11-20: all passed. Findings: slow rates read "1/min" for both 0.6 and
      1.2 (2.6.7); the user wants nuclear to behave like a vanilla reactor (2.6.8).
- [x] 2.6.7 Rates under 10/min keep one decimal in tier lines and messages (tested).
- [x] 2.6.8 Nuclear runs flat out (user): with fuel in it burns at its full rate whatever
      the demand; unused steam is vented; the window says what share of its output the
      network uses. Idea for later (user): a circuit signal for fuel control (README).
- [x] 2.6.9 Short `/playtest`: flat-out nuclear (fuel use and the usage line), decimals.
      Playtest 2026-11-20: all passed.

### Phase 2.7: elevated rails (approved by the user 2026-11-20)

Decided with the user (DECISIONS.md, 2026-11-20):
- Space Age's Elevated rail tech needs production science (100 x red/green/blue/purple,
  after Concrete and Production science pack). The research complex takes no purple, so
  the tech is retuned to red + green + blue, after Concrete and Chemical science pack.
  Proposed cost (tuning): 500 units x 30 s. Rejected: a purple science city (needs stone,
  bricks, and opens the whole purple tree).
- No map change in this phase; terrain that rewards elevated rails comes with procedural
  maps.

- [x] 2.7.1 Retune the Elevated rail tech (red + green + blue, 500 units, after Concrete
      and Chemical science pack). Gating test: reachable, and nothing else changed.
      (mod/prototypes/technology.lua, data-final-fixes.)
- [x] 2.7.2 Ramps, supports, elevated rails and signals: free once researched, locked
      before (restrictions test). Check rail supports on water (the lakes become
      crossable) and note what 2.1 allows. (Supports stand on water and deep water.)
- [x] 2.7.3 End-to-end test: a train drives up a ramp, over a ground line, down to a stop.
- [x] 2.7.4 Limp mode, breakdowns and depot servicing for trains on elevated track (no
      elevated train stops, so servicing stays on the ground). (Limp and breakdown tested
      on elevated track; servicing needs a stop, so it is unchanged.)
- [x] 2.7.5 `/playtest` round: research, building up and over, trains on elevated track. (Research, items, ramps and elevated track checked by hand; water, limp and breakdown left to the automated tests, as vanilla behaviour.)

### Phase 2.8: procedural maps (approved by the user 2026-11-20)

Decided with the user (DECISIONS.md, 2026-11-20):
- New Game on Nauvis: the mod works from the normal New Game screen and its map settings
  (seed, preview, resource sliders). The scenario stays as the fixed, hand-made map, which
  the tests use.
- Vanilla Nauvis terrain: lakes, trees, cliffs, rocks. Vanilla ore, coal, oil and uranium
  patches, with no resources near spawn.
- Cities take no account of where resources are.
- Biters are forced off, whatever the map settings say.
- The player finds the cities by uncovering the map; the layout is not shown up front.
- Cities are far apart: at least 1,000 tiles between any two (a starting value; the user
  wants it as close to the upper limit as is playable). A startup setting, "City spacing",
  scales it from 0.5x to 3x.
- Cities later in the production chain are more likely to be far from spawn, but at
  random, not in fixed rings.

At 1,000 tiles, 28 cities fill a disc of roughly 3,600 tiles' radius around spawn.

- [x] 2.8.1 Chain depth of every city type, worked out from the city recipes (raw inputs
      are 0, a city is one more than its deepest input). Test: the coal fuel depot and
      the coal power city are shallow and the rocket silo is the deepest. A new city type
      gets a depth with no extra code.
- [x] 2.8.2 Layout planner: pure Lua, seeded by the map seed. Places one of each layout
      city (the 28 of today's map), with the coal fuel depot near spawn and the others at
      least the spacing apart. Distance from spawn is drawn at random, weighted by depth.
      Startup setting "City spacing" (0.5x to 3x, default 1x = 1,000 tiles). Tests: the
      same seed gives the same layout, different seeds differ, spacing is never broken,
      the multiplier scales it, and deeper cities sit further out on average.
- [ ] 2.8.3 Sites on real terrain: a planned spot moves to the nearest land that fits
      the city and a margin (no water, no cliffs), and trees, rocks and cliffs on the
      footprint are cleared. Only the chunks around each city are generated, not the
      whole disc. Tests on a surface with vanilla terrain: every city stands on land, is
      not on an island, and nothing overlaps.
- [ ] 2.8.4 Nauvis start: on a New Game, the mod sets up Nauvis instead of its own
      surface. Biters forced off (no enemy bases, peaceful). No resources within 300 tiles of spawn (tuning); spawn and the depot are
      on land. Freeplay extras are replaced: no crash site, and starting items limited to
      the coal fuel of today's scenario. The scenario keeps its fixed map, and old saves
      are unchanged.
- [ ] 2.8.5 Finding cities: nothing is charted up front. A city gets its map tag when
      the player first charts its chunk (walking, trains, radar), so the layout is
      discovered. Test: no tag before charting, tag after.
- [ ] 2.8.6 Start-up time: creating the map stays fast (target under 10 s at 3x spacing,
      tested).
- [ ] 2.8.7 `/playtest` round: a New Game from the menu with the map preview, the spacing
      setting, the layout on the map, and the first routes on real terrain.
