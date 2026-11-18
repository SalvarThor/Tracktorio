# Decision log

Newest first. One entry per decision: date, decision, why, alternatives rejected.
Design decisions made before the build started are in SPEC.md; this log covers what is
decided during the build.

## 2026-11-18: 1.2 black box framework
- Decision: `mod/prototypes/blackbox.lua` `make_city(def)` builds a recipe-category, a recipe
  and an `assembling-machine` named `tt-city-<name>` from one definition table:
  - size, graphics source, crafting speed, recipe, fluid boxes
  - `fixed_recipe`, void energy, no item, not minable
  - flags: not-blueprintable, not-deconstructable, not-rotatable, no-copy-paste
- Control (`scripts/cities.lua`) places cities by script, sets operable / destructible /
  minable_flag / rotatable to false, tracks them in `storage.tt_cities`, and drops them
  through `on_object_destroyed`. It is exposed as the remote interface `tt-city`
  (`place` returns the LuaEntity, `list`, `hand_transfers`).
- Cities are recognised by the `tt-city-` name prefix, so no runtime registry is needed.
  The tests mod builds its own `tt-city-test` with the same generator in its data stage.
- Hands-off, belt and braces: `on_gui_opened` closes any city GUI, and
  `on_player_fast_transferred` counts transfers that reach a city
  (`storage.tt_hand_transfers`; expected 0, checked in playtest).
- Placeholder sprite: the source machine's `graphics_set`, with every sprite's scale and
  shift multiplied by size / source size.
- 2.1 note: `game.get_entity_by_unit_number` only works for prototypes with the
  `get-by-unit-number` flag. Remote calls pass LuaEntity objects directly instead.
- Rejected: one prototype per tier (tiers are post-MVP); a scripted crafting loop (the
  engine already does slowest-input and backpressure, verified by tests).

## 2026-11-18: 1.1 prototype restrictions
- Decision: explicit item lists in `mod/shared/config.lua`.
  - `FREE_ITEMS`: the recipe of the same name gets `ingredients = {}`, 0.002 s and category
    `tt-free`.
  - `BANNED_ITEMS`: every recipe making them is hidden and disabled, and technologies stop
    unlocking them.
- The character's `crafting_categories = {"tt-free"}`, so nothing else can be hand-crafted.
  Items on neither list (turrets, walls, accumulators, armour, intermediates) are simply
  uncraftable.
- Non-primary recipes for free items (foundry `casting-pipe`) are hidden so they don't
  duplicate the free recipe.
- Technologies left with no effects are hidden, as are planet-discovery, space-platform and
  rocket-silo techs.
- Start research is set by the mod's `on_init` on the `player` force:
  - railway
  - automated-rail-transportation
  - fluid-wagon
  - electronics
  - logistics
  - electric-mining-drill
  - steam-power (now only pipe, pipe-to-ground, offshore pump)
  - fluid-handling
  - electric-energy-distribution-1
- Why: lists are explicit and testable. Hiding instead of deleting avoids broken references
  (tips, simulations, other prototypes).
- MVP has no labs, so nothing past the start set is reachable. The tech tree gets reworked
  with the research complex (post-MVP 2).
- Consequence for 1.8: turrets can't be crafted, so the MVP map needs enemies off.
- Rejected: banning by entity type (`data.raw` names collide across types); deleting
  prototypes.

## 2026-11-18: Phase 0 follow-up decisions (user-approved)
- **Quality:** `mod/info.json` declares `"! quality"`. The game refuses to load train-tycoon
  with quality enabled ("Incompatible with quality", verified), and the dev instance runs
  with quality disabled. A smoke test asserts quality is inactive.
  Rejected: keeping quality loaded and neutralising it in data (more code, leaks
  through UI/recipes). The recycler stays loaded (Space Age requires it) and is hidden in
  data in 1.1.
- **Power city (1.4):** engine-only design. Assembling-machine water + coal → `tt-steam`,
  feeding a hidden `generator` inside the footprint through a linked fluidbox connection.
  Probe it first in 1.4. Fallback: scripted electric-energy-interface driven by
  `raise_on_crafted`.
- **Limp mode (1.7):** reserve-fuel swap driven by a light poll of tracked locomotives
  (spread across ticks), as measured in A3. The spec's "stops dead" fallback is not needed.
- **Locomotive fuel:** a dedicated `tt-locomotive` fuel category. Solid, rocket and nuclear
  fuel are not locomotive fuels until the post-MVP fuel cities add `tt-` fuels to that
  category.

## 2026-11-18: Phase 0.10 findings for assumptions A1-A7 (Factorio 2.1.24)
Method: 2.1.24 `runtime-api.json`/`prototype-api.json`, a `--dump-data` of `data.raw`, the
2.1 changelog, and a throwaway probe mod run headless with `--test-scenario` in the dev
instance (deleted afterwards, not committed). Nothing here is implemented yet.

**A1. Empty-ingredient recipes: HOLDS (near-instant, not instant).**
- `ingredients = {}` is documented as allowed, and vanilla `biter-egg` already uses it.
- `energy_required` must be `> 0.001`, so there is no true zero-time craft. With
  `energy_required = 0.002`, a 5x hand craft finished 2 items by tick 2 and all 5 by tick 10.
  That's about one item per tick (60/s), which feels instant.
- `get_craftable_count` returns uint-max (unlimited).
- 2.1 surprise: recipe `category` and `additional_categories` were merged into a
  `categories` list. The old field is a load error.

**A2. Black box as `assembling-machine`: HOLDS.**
- The probe used `fixed_recipe`, `energy_source = {type="void"}`, `minable = nil`, custom
  `crafting_categories`, placed by script.
- Runtime flags set on placement: `operable = false`, `destructible = false`,
  `minable_flag = false`, `rotatable = false` (the `not-rotatable` prototype flag alone still
  read `rotatable = true`).
- Results:
  - `player.opened = box` leaves `opened` nil.
  - `damage(1000)` does 0.
  - `player.mine_entity` returns false.
  - Burner inserters fed and drained the box exactly the same with `operable` true or false
    (22 plates/min, limited by the single inserter, so "rate of slowest input" holds).
  - A box with no output inserter stopped with status `full_output` (backpressure).
- Hand-transfer: per the API docs, `operable = false` blocks opening the GUI and "quick
  insert/input" (ctrl-click and friends). Those can't be simulated headless, so **ctrl-click,
  ctrl-right-click and drag need a playtest check in 1.2**. If anything slips through, the
  fallback is `on_player_fast_transferred` (exists in 2.1) to return the items.
- Note: in 2.x an inserter's `direction` is its pickup side.

**A3. Limp mode via reserve fuel: HOLDS with a light poll; no engine-only route.**
- `defines.train_state` has no `no_fuel`, and there's no fuel-empty event. Detection needs
  polling.
- Writing `burner.currently_burning = "tt-limp-fuel"` works for an item that was never in the
  inventory. It needs `remaining_burning_fuel` set explicitly, which otherwise reads 0.
- With `fuel_top_speed_multiplier = 0.25`, `train.max_forward_speed` dropped from 1.2 to 0.3.
  A train pushed to speed 1.0 decayed to 0.23 within a second.
- The limp item must never run out, so it gets a huge fuel value, and script swaps it out
  when real fuel shows up. That makes the poll two-way:
  - Empty inventory and nothing burning: set the limp item.
  - Limp burning and real fuel in the inventory: set `currently_burning = nil`.
- Cost: the per-locomotive check measured 1.25 µs. 1000 locomotives scanned every 60 ticks
  is about 0.02 ms/tick, and it can be spread across ticks.
- Track locomotives via build/destroy events in `storage`.

**A4. `tt-coal-fuel` only: HOLDS, cleanest option found.**
- Change: a new fuel category `tt-locomotive`, the locomotive's
  `energy_source.fuel_categories = {"tt-locomotive"}`, and `tt-coal-fuel` in that category.
- Coal is left untouched. Probe: the locomotive rejects coal and solid fuel and accepts
  `tt-coal-fuel`; the burner mining drill and burner inserter still accept coal.
- What else burns chemical fuel: stone/steel furnace, boiler, car, tank, heating tower,
  burner-generator (hidden). All of these are removed by the guardrails anyway.
- Side effect: solid, rocket and nuclear fuel also stop being locomotive fuels. That's
  intended for MVP; post-MVP fuel cities add `tt-` fuels in the same category.
- 2.1 surprise: `ItemPrototype::fuel_category` was replaced by `fuel_categories` (list).
- 2.1: locomotives auto-pull fuel from passengers, which fits "hand-fueling allowed".

**A5. Power city: options (not probed).**
- (a) **Recommended: engine-only.**
  - The box is an assembling-machine with recipe water + coal → `tt-steam` (fluid output).
  - A hidden `generator` entity sits inside the footprint, joined by a `linked` pipe
    connection (`LuaEntity.add_fluid_box_linked_connection`, which in 2.1 is on LuaEntity, not
    LuaFluidBox).
  - The generator burns steam only on electrical demand, the fluid output fills, and the box
    stalls. Backpressure, "slowest input" and the UI status all come from the engine, with
    no per-tick script.
  - Needs a probe in 1.4.
- (b) Fallback: scripted `electric-energy-interface`.
  - The recipe makes a hidden `tt-power-charge`, with `raise_on_crafted = true` (new in 2.1).
  - Each `RecipeCraftedEvent` adds energy to an EEI buffer (`power_production`/`energy` are
    writable).
  - Event-driven, but "no demand → stall" needs script, because the EEI doesn't push back.
- (c) A vanilla `burner-generator` exists (hidden) and burns coal straight to electricity,
  but it has no water input. That's against the spec (water + coal).

**A6. Restrict hand crafting and remove entities: HOLDS.**
- `character.crafting_categories = {"tt-hand"}`, with only the free recipes in `tt-hand`.
- Probe: with 50 iron plates, `iron-chest` had craftable count 0 and `begin_crafting` 0. The
  free recipe crafted.
- Removal (data-final-fixes):
  - Hide and disable the recipes of banned entities: furnaces, assemblers, refinery,
    chemical plant, centrifuge, boiler, steam engine/turbine, solar, nuclear and heat
    entities, Space Age machines, lab and silo (cities later), car, tank, spidertron, robots,
    roboports, logistic chests, personal roboport.
  - Hide technologies whose only effects are banned, and strip the banned unlocks from mixed
    technologies.
- The starting inventory is controlled by our scenario.
- 2.1 adds a vanilla `hand-crafting` category; we don't use it.
- **Quality:** 2.1 made Space Age's quality dependency a recommendation (`+ quality`).
  Verified: Space Age loads with quality disabled, and the `quality` feature flag
  disappears. A mod can't disable another mod for the user. Options:
  - declare `! quality` (incompatible) in info.json, or
  - keep quality loaded and neutralise it in data (hide tiers, techs, modules).
- **Recycler:** can't be disabled. It's a hard dependency of Space Age, and of quality.
  Disabling it fails with `Failed to load mod`. Neutralise it in data instead: hide the
  recycler entity, recipe and technology. The recycling recipes become unreachable.
- Planets/platforms: hide the space-platform, rocket and planet-discovery techs.

**A7. 2.1 vs 2.0 changes that matter here:**
- `ItemPrototype::fuel_category` → `fuel_categories`; `LuaItemPrototype` read likewise.
- `RecipePrototype::category` + `additional_categories` → `categories`.
- Recipe categories reworked: `hand-crafting` added, many combo categories removed.
- `RecipePrototype::raise_on_crafted` + `RecipeCraftedEvent` (crafting machines only). Useful
  for goal-box counting and output-rate UI without polling.
- Space Age's quality dependency is now optional; `recycler` was split out as its own mod.
- Linked fluidbox connections live on `LuaEntity` (`add_fluid_box_linked_connection`).
- Locomotives auto-pull fuel from passengers.
- `info.json` `migrates_from` (mod ownership transfer). `LuaPlayer::spectator` removed.
- New CLI test mode: `--test-scenario/--test-save/--test-ticks/--test-arg`,
  `script.finish_test`, `script.test_arg`. `--test-ticks` timeout exits 0.

## 2026-11-18: Storage key prefix is `tt_`; debug commands have a remote twin
- Decision: storage keys use `tt_` (e.g. `storage.tt_schema`), not `tt-`. Every `/tt-*`
  debug command calls a function that is also exposed on the remote interface `tt-debug`.
- Why: Lua identifiers can't contain `-`, and `storage["tt-x"]` everywhere is noisy. Scripts
  can't execute console commands, and `helpers` can't read files (2.1.24), so tests reach
  the same code through `remote.call("tt-debug", ...)`, which returns the data.
- Rejected: `storage["tt-..."]` keys; reading script-output back from tests (no API).

## 2026-11-18: In-game tests use the native `--test-scenario` mode
- Decision: tests run with Factorio 2.1.24's built-in `--test-scenario MOD/NAME`, which is
  headless with a player, runs until `script.finish_test(passed)` and exits 0 or 1. The
  scenario `tt-tests` lives in a separate mod `train-tycoon-tests` (`tests\`), junctioned
  only into the dev instance. Its scenario script runs a small runner
  (`tests\runner.lua`: sync tests plus `ctx:wait`/`ctx:wait_until` across ticks). Results go
  to `script-output\tt-test-results.json`. `tools\run-tests.ps1` wraps it all.
- Why: no RCON client, no server process, no Node and no extra mod dependency. One run
  takes ~2.5 s. Load errors and uncaught mod errors exit 1 promptly with the error in the
  log (verified). The runner sits in the scenario's own Lua state, so its `on_tick` can't
  overwrite the mod's handlers. Tests inspect the mod through game state, `/tt-` commands and
  remote interfaces.
- Caveat (2.1 surprise): `--test-ticks N` exits with **0** when the tick limit is hit.
  The wrapper therefore accepts a pass only if a results file carrying this run's id exists
  and reports failed=0, passed>0.
- Rejected: Factorio Test (needs Node, a portal mod dependency, and has unknown 2.1 support).
  A server with RCON (more moving parts, and the process has to be killed).
- Later: unit tests of mod internals, if needed, through a `tt-test` remote interface that
  the mod registers only when `train-tycoon-tests` is active.

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
