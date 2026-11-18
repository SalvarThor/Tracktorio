# Decision log

Newest first. One entry per decision: date, decision, why, alternatives rejected.
Design decisions made before the build started are in SPEC.md; this log covers what is
decided during the build.

## 2026-11-18: 2.1.7 tier pips on cities
- Decision: each tiered city shows one pip per tier along its top edge, filled gold up to its
  tier, dark for the rest (user choice after playtest 2.1.6). Drawn with `rendering.draw_circle`
  targeted at the city, so they vanish with it; the upgraded city is a new entity and gets
  fresh pips from the `on_any_placed` hook. Render object ids live in `record.tier_marks`.
  Every configuration change redraws missing pips (idempotent), and the mod version goes to
  0.1.1 so existing saves get them; no storage schema change.
- Why: readable at a glance and without language; no new art needed.
- Rejected: text label (small when zoomed out), colour tint per tier (subtle, colour-only).

## 2026-11-18: 2.1.5 save migration (schema 2, mod version 0.1.0)
- Decision: `state.migrate(steps)` runs on configuration change and from the test hook
  `tt-city.migrate`.
  - Schema 1 → 2 closes window records stored in the old format (a unit number).
  - Every run calls `ports.ensure_all()`, which gives each upgradable city its port.
  - The steps are idempotent.
- Port placement never removes player entities. If the port tile is taken (an old save where
  the player built there), the city waits: the player gets one message with a map link to
  the tile, and `ports.tick` retries every second until the tile is clear.
- The mod version goes 0.0.1 → 0.1.0, because `on_configuration_changed` does not fire for
  an unchanged version. Verified on a real Phase 1 save (the playtest round 2 autosave)
  loaded headless: "schema 1 -> 2; cities with a port: 4, still waiting: 0". It ran
  180 ticks without errors.
- Rejected: placing the port on the nearest free tile (the location must be predictable);
  removing what blocks it.

## 2026-11-18: 2.1.4 tier UI and upgrade notifications
- City window: a tier section, "Tier N of 3: <what it does>". It shows the next tier's
  description and each material with delivered / needed and a progress bar, and says where
  the port is. Construction ports open the same section ("Construction port for X").
- Window state now stores the shown LuaEntity (city or port) instead of a unit number. The
  upgrade re-points only the windows that showed the replaced city or its port (captured
  before destruction).
- Notifications (`scripts/notify.lua`):
  - An upgrade message to the force with a `[gps]` map link and what changed: rate or power
    output, max draw, "no longer uses coal" when going electric.
  - A custom alert with the city's icon (removed after 30 s).
  - Local flying text for players on the same surface.
  - A heads-up once per tier at 90% of materials.
- Power warning: "not connected" if the city is off-grid. "Weak network" if the max draw of
  all tracked cities on the city's electric network exceeds the output of the power cities
  on that network. That's deterministic, and matches the numbers in the city windows; drills
  and inserters come on top. Factorio has no simple "spare capacity" API.
- Map tags get " (tier N)" on upgrade.
- The last 20 messages are kept in `storage.tt_notify_log` (shown by `/tt-dump`, read by
  tests).
- Test note: test cases share one game. A test that changes the shared `tt-map-test`
  surface broke later map tests, so each test that mutates a generated map uses its own
  surface.

## 2026-11-18: 2.1.3 upgrade in place
- Decision: `scripts/upgrade.lua` replaces a city when its port completes:
  1. Copy input and output contents.
  2. Remove the old storage record **before** destroying anything, so the deferred
     `on_object_destroyed` finds nothing to clean.
  3. Destroy the old city, its generator and its port.
  4. Place the next tier with `cities.place`, which brings its own protections, generator
     (relinked) and a fresh port for the following tier (none at max tier).
  5. Restore what fits. What the new recipe can't take (coal after going electric) is
     spilled beside the port.
  6. Re-point open city windows to the new unit number. Rate samples restart.
- Completions are collected during the port loop and swapped after it: adding table
  entries while iterating with `pairs` is undefined in Lua.
- Hook `upgrade.on_upgraded(old_name, city)` is for notifications (2.1.4). Tests use
  `tt-city.upgrade_now(city)`.
- Rejected: `create_entity{fast_replace = true}` (cities have no item or fast-replace
  group, and explicit copying lets coal be handled on purpose); keeping one entity and
  changing its speed (not possible).

## 2026-11-18: 2.1.2 construction ports
- Decision: `tt-construction-port` is a 1x1 container on the tile west of a city's top-left
  corner (user's choice). Protected like a city, 4 filtered slots. `scripts/ports.lua`
  places one through a new any-city placement hook for every city with a next tier (none
  for the goal box or max-tier cities). The port is destroyed with its city.
- Every 60 ticks: count and remove port contents into `record.upgrade.delivered`, then
  refilter the slots to what is still needed. Otherwise the placeholder `tt-port-closed`.
  At 100% the upgrade is marked complete and an `on_complete` hook fires (2.1.3 does the
  swap). Materials never enter the city, so no inserter or power sits between port and
  city.
- Exposed for tests and UI: `tt-city.upgrade_status(city)`, `tt-city.port_tick()`.
- Not a `tt-city-` name on purpose: the port isn't a city (no window, rate sampling or map
  tag), but it uses the same protection.

## 2026-11-18: 2.1.1 tier prototypes
- Decision: all city definitions (tiers, rates, power, upgrade costs) live in one plain-data
  module, `mod/shared/city_defs.lua`, read by both stages. `prototypes/cities.lua` builds
  one assembling-machine per tier. Tier 1 keeps the MVP name `tt-city-<name>`, so MVP saves
  load; tiers 2-3 are `tt-city-<name>-t<N>`. Each power tier has its own hidden generator
  (`tt-power-generator`, `-t2`, `-t3`; 3 / 6 / 12 steam per tick). `config.CITY_COMPANIONS`
  is derived from the defs.
- Verified:
  - output x1 / x2 / x4 for every city
  - tier 2-3 smelting has no coal and draws 8.64 / 17.28 MW
  - depot draws 0.84 / 1.68 / 3.36 MW
  - no upgrade costs a city's own product
  - a tier 2 power city delivers 8.00 MW to an 8 MW demand
  - an electric smelter runs without coal
- Test note: measure a power source with the generator's `energy_generated_last_tick`.
  An electric-energy-interface consumer's buffer also drains by its own usage, so reading
  it understated delivery (2.9 MW measured vs 8 MW actual).
- Rejected: changing crafting speed at runtime (not possible: crafting speed is a
  prototype property; modules and beacons are banned).

## 2026-11-18: City tier upgrades, design (user decisions, Phase 2.1)
- 3 tiers at x1 / x2 / x4 of tier 1's cap (roughly yellow, red and blue belt for smelting).
- A city's upgrade never uses its own product: the materials must come from another city,
  so every upgrade adds a route. (User's point: own-product costs are a trivial
  output-to-input loop.) With only MVP cities that means:
  - iron city ← copper plates; copper city ← iron plates
  - depot and power city ← both
  When intermediate cities arrive (post-MVP 2), costs switch to their products.
- Smelting cities go electric from tier 2: no coal, and they draw what electric furnaces
  would for the same output. Upgrading changes what the station must deliver, not just the
  rate.
- Materials go into a construction port beside the city (like the goal box, it only takes
  what is still needed). The upgrade happens automatically when the port has everything.
- Rejected:
  - 5 doubling tiers, or a gentle x1.5 / x2
  - waiting for intermediates before building tiers
  - extra coal-fuel costs
  - a coal/electric choice at tier 2
  - an Upgrade button
  - delivering materials through the city's own inputs
- Numbers are proposals in PLAN.md 2.1, to tune in playtest.

## 2026-11-18: 2.1 removed LuaEntity.fluidbox (playtest round 2 crash)
- Finding (A7 addendum): `LuaEntity.fluidbox` and the `LuaFluidBox` class do not exist in
  2.1.24. Fluid access is through LuaEntity methods (`get_fluid`, `get_fluid_count`,
  `get_fluid_box_prototype`, `fluids_count`, ...).
- Why it slipped through: the parameter was untyped, so the static check saw `any`. The
  power tests never opened the window of a fluid-starved city. Both are now covered: a
  regression test, and a rule to annotate Factorio-object parameters.

## 2026-11-18: Locomotives stay free; limp speed 10% (user decision)
- Decision: rolling stock stays free (SPEC). Limp top speed goes from 15% to 10%
  (1.2 → 0.12 tiles/tick, about 26 km/h). Acceleration stays at ×0.25.
- Why: the cost of a train is running it (coal fuel, later reliability), not building it.
  Free trains plus limp mode do allow a large, never-fuelled fleet of slow trains. The user
  accepts that: a network that carries a hundred slow trains is a legitimate way to play.
- Rejected: charging for locomotives (a rolling-stock city stays a possible post-MVP idea);
  limp only towards a fueling stop; limp only after a first real refuel.

## 2026-11-18: Cities draw electricity like their vanilla equivalents (user decision)
- Decision (SPEC updated): a city draws electricity when its vanilla equivalent uses
  electric buildings, at the power those buildings need for the same output.
  - The city generator takes an optional `power`, which gives an electric energy source
    (secondary-input) with `energy_usage = power`.
  - The engine draws it while crafting, slows down on low power and stops without it. Idle
    drain is the engine default (1/30).
- MVP:
  - The depot counts as chemical plants: 210 kW and 0.5 fuel/s each, so 4 of them make
    2 fuel/s = 840 kW.
  - Smelting cities stay coal-fired (coal is the fuel ingredient); electric smelting is a
    later upgrade.
  - The goal box needs no power.
- The city window shows "No power" / "Running slowly: not enough power".
- Consequence for bootstrapping: coal fuel now needs a working power city (water + coal)
  and a pole line to the depot. The starting 20 coal fuel is meant to cover that.
- Rejected: treating the depot as assembling machine 2 (about 600 kW); keeping it unpowered.

## 2026-11-18: Playtests get their own instance
- `.factorio-play\` (`dev-instance.ps1 -Instance play`, used by `playtest.ps1`) loads
  train-tycoon only. Factorio locks a running game's write-data folder, so with a shared
  folder tests couldn't run during a playtest. The Steam "custom arguments" dialog on GUI
  launch is accepted (user).

## 2026-11-18: Playtest round 1 fixes
- Power city generator: `selectable_in_game = false`, no selection box. The
  `not-selectable-in-game` flag alone still let it win selection over the city (2.1.24).
- Non-free recipes get `hide_from_player_crafting`, so the crafting menu shows only free
  items.
- City map tags: `force.add_chart_tag` needs charted chunks, and charting is async, so tags
  are queued at generation and placed from the 60-tick handler until all exist.
- Goal box demand (user request): when a metal reaches its target, its slots are filtered
  to the hidden placeholder `tt-goal-closed`, so inserters stop feeding it. Raising the
  target reopens them. Overshoot is at most one counting interval (about 1 s of deliveries).

## 2026-11-18: Hand-carrying cargo into chests is allowed (user decision, playtest 1.10)
- Decision: the player may carry ore, coal or plates by hand into a chest whose inserter
  feeds a city or the goal box. Only direct insertion into a city is blocked.
- Why: like hand-fueling, it can't scale (20,000 plates by hand loses to any train), and it
  helps the bootstrap (first coal to the power city and depot). No code.
- Rejected: banning cargo items from the player inventory; letting the goal box accept only
  inserters that pick up from cargo wagons.

## 2026-11-18: 1.9 end-to-end test
- Decision: `tests/cases/e2e.lua` builds a 300-tile line with a two-headed train
  (loco-wagon-loco, hand-fuelled with coal fuel) and three stations:
  - **A:** chests load 100 ore and 10 coal (leaves after 3 s of inactivity).
  - **B:** inserters feed the iron smelting city and load its plates back (leaves at
    100 plates).
  - **C:** filtered fast inserters unload plates into the goal box.
- It passes when the goal box counts the 100 plates and reports a rate (about 77 s game
  time). It also checks the city crafted and the train never went into limp mode.
- 2.1.24 rail geometry, measured with a throwaway calibration run:
  - Straight rails snap to odd coordinates.
  - An eastbound stop sits 2 tiles south of the rail centre; a westbound one 2 tiles north.
  - The wagon of a loco-wagon-loco train stops 10 tiles behind the stop.
  The test hard-codes these.
- Test-rig power comes from vanilla electric-energy-interfaces under substations. That's
  test-only; the real game uses the power city.

## 2026-11-18: 1.8 MVP scenario map
- Decision: `scripts/map.lua` (remote `tt-map`) builds the map on its own surface,
  `train-tycoon`. Map gen is grass only, 640x400, no resources, trees, cliffs, water or
  enemies (`no_enemies_mode`, `peaceful_mode`). Lake, patches and cities are placed by
  script at fixed positions, so the map is fully reproducible (a test builds it twice and
  compares).
- The scenario (`mod/scenarios/train-tycoon`) only calls `tt-map.generate` and
  `tt-map.setup_player`.
- Layout (tile coordinates):
  - spawn (0, 4); depot city (0, -24)
  - power city (-64, 40); iron smelting (160, -96); copper smelting (160, 96)
  - goal box (272, 0)
  - iron ore (-240, -140) r14; copper ore (-240, 140) r14; coal (-40, -165) r12
    (each patch is over 200k)
  - lake (60, 165) r10
  - every patch and the lake is at least 100 tiles from every city
- Start inventory: 20 coal fuel (SPEC: hand-fueling helps at the start). Everything else is
  free to hand-craft.
- Enemies off: turrets can't be crafted (1.1), so enemies would be unwinnable. Confirmed
  by the user at the end of Phase 1.
- Own surface instead of nauvis: avoids clearing and regenerating nauvis inside on_init,
  and leaves nauvis untouched.
- `run-tests.ps1` now also loads the shipped scenario for 300 ticks and fails on any script
  error.

## 2026-11-18: 1.7 limp mode
- Decision: a hidden item `tt-limp-fuel` in the locomotive fuel category: 100 GJ, top speed
  ×0.15 (later 0.10, see "limp speed 10%"), acceleration ×0.25. It is never an item
  stack.
- `scripts/limp.lua` tracks locomotives in an array (on built / script-raised / cloned
  events, plus a full map scan on init and configuration change). Every 10 ticks it checks a
  slice, so each locomotive is seen about once a second:
  - Nothing burning and an empty fuel inventory: set `currently_burning` to the limp fuel
    with a full `remaining_burning_fuel`.
  - Limp fuel burning and real fuel present: clear `currently_burning`, and the burner takes
    the real fuel.
  - Invalid entries are swap-removed.
- Verified:
  - An unfuelled locomotive limps at max 0.18.
  - A limping train drives a temporary-rail schedule, slowly.
  - Refuelling ends limp mode within a pass.
  - Fuelled locomotives are untouched.
  - The poll picks up new locomotives by itself.
- Cost: about 1.25 µs per locomotive per second, measured in A3.
- Known limit: while limping, the burner never asks for fuel, so 2.1's "auto-pull fuel from
  passengers" doesn't kick in. The player inserts fuel by hand (or an inserter does), and
  the next pass restores normal running. Acceptable for MVP; revisit with reliability.
- Rejected: the SPEC fallback (stop dead), which wasn't needed; a per-tick scan.

## 2026-11-18: 1.6 city UI
- Hover: the vanilla entity tooltip (crafting machines already show their recipe and
  status), plus a "Click it for details" line in each city's description.
- Click: cities are `operable = false`, so the normal open-GUI click does nothing. The
  custom input `tt-open-city` (`linked_game_control = "open-gui"`) opens a draggable window
  (`scripts/city_gui.lua`) instead. It shows:
  - status: running / starved, naming the missing input / output full
  - inputs and outputs per cycle, with the max rate per minute
  - the measured output per minute
  It refreshes every 60 ticks and closes with E/Esc or the close button.
- Rate: `scripts/city_info.lua` samples `products_finished` every 60 ticks over a 60 s
  window. Output per minute = crafts per minute × product amount.
- "Missing": inputs that are completely absent are named first. Only if none are absent does
  it list those below one cycle's worth, so a slowly arriving input isn't blamed alongside
  the one that isn't coming at all (found by a test).
- Exposed for tests as `tt-city.info(entity)` and `tt-city.open_gui(player_index, entity)`.
- Rejected: opening the vanilla assembler GUI (it would allow hand insertion and break
  hands-off).

## 2026-11-18: 1.5 goal box and win condition
- Decision: the goal box `tt-city-goal` is a 9x9 `container` (40 slots, filtered by script:
  half iron plates, half copper plates). Inserters can only deliver plates; the player can't
  open it (same city protections).
- Every 60 ticks `scripts/goal.lua` empties every goal box and adds what it held to
  `storage.tt_goal.delivered`, which only ever grows. Buffering upstream doesn't help, which
  matches the SPEC.
- Win when both totals reach the runtime-global settings `tt-goal-iron` / `tt-goal-copper`
  (default 20000): `set_win_ending_info` + `set_game_state{game_finished, player_won,
  can_continue = true}`. The game finishing doesn't stop the headless test runner (verified).
- Progress panel top-left: delivered / target per metal, with a per-minute rate over a
  60 s window.
- Tuning: `/tt-goal <iron> <copper>` (admin), remote twin `tt-goal.set_targets`. A 2.1
  finding: runtime-global settings can only be written by the owning mod, so tests and
  scenarios go through the remote call.
- Rejected: an assembling-machine "consumer" recipe (one recipe needing both metals would
  count at the rate of the slower one); `raise_on_crafted` companions (more prototypes, same
  result).

## 2026-11-18: 1.4 power city (engine-only, verified)
- Decision: `tt-city-power` (9x9) runs 1 coal + 150 water → 150 steam at 165 °C, 1 s, at
  speed 1.2. Water comes in on the south edge (centre tile).
- Steam goes out through a `linked` fluidbox to a hidden `generator`, `tt-power-generator`:
  - same footprint, empty collision mask, not selectable
  - 3 steam/tick, so 5.4 MW cap
- Control places the generator with the city (`config.CITY_COMPANIONS`), links them with
  `add_fluid_box_linked_connection`, protects it, and destroys it with the city.
- Verified by tests:
  - A pole beside the city carries 1 MW to a consumer.
  - With no demand the city reaches `full_output` and stops burning coal (backpressure).
  - It starves without water.
  - The generator is removed with the city.
- Note: after `full_output` first shows, one more craft still flows into the generator's own
  200-unit buffer before everything holds still.
- Rejected: a scripted electric-energy-interface (needs script to fake backpressure);
  `burner-generator` (no water input).

## 2026-11-18: 1.3 smelting cities, depot city, coal fuel (rates are tuning values)
- Iron smelting / copper smelting: 9x9, 10 ore + 1 coal → 10 plates, 1 s, speed 1.5. Cap is
  15 plates/s (one yellow belt) and 1.5 coal/s.
- Depot: 9x9, 2 coal → 1 `tt-coal-fuel`, 1 s, speed 2. Cap is 2 fuel/s.
- `tt-coal-fuel` gives 10 MJ (coal is 4 MJ, so refining is a small bonus), with acceleration
  and top-speed multipliers of 1. It's in fuel category `tt-locomotive`, which every burner
  locomotive now burns exclusively. `auto_recycle = false`: Space Age otherwise generates a
  `tt-coal-fuel-recycling` recipe (caught by a test).
- Why: the spec leaves rates open. These give a fast network a real edge over a slow one at
  the 20k-plate goal. To be tuned in the 1.10 playtest.
- Placeholder sprites: scaled electric furnace (smelting) and assembling machine 3 (depot).

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
