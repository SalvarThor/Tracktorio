# Decision log

Newest first. One entry per decision: date, decision, why, alternatives rejected.
Design decisions made before the build started are in SPEC.md; this log covers what is
decided during the build.

## 2026-11-21: 2.15.10 city icons show the product
- User, playtest 2.15.10: the city items all looked alike in the quickbar (the building art
  with a tiny product badge). Now the product (or roof icon: steam engine, reactor, lab) is
  the full-size icon, the city building a small mark top left; coal smelting gets a coal
  mark and electric smelting a lightning mark bottom right. Entity and item share the icon.
- Playtest finding: a stray copy of the scenario in `.factorio-play\data\scenarios\` (saved
  at 18:03, old text) also shows as "Tracktorio"; started from there it is a user scenario,
  so the mod's on_init skips the layout (no plots, no tags). Moved aside to
  `.factorio-play\data\stray-scenario-tracktorio-1803`.
- Rejected: keeping the building as the main icon with a bigger badge (still reads as
  "a building" first).

## 2026-11-21: 2.15.7 cities at half rate
- `city_defs.RATE = 0.5` scales every city's crafting speed, research speed, power,
  burner power and steam (generator usage) after the list, so the derivations in the file
  ("speed 2 = 2 refineries") stay as written for the full rate. Iron smelting 7.5
  plates/s (half a yellow belt), depot 1 fuel/s at 420 kW, water 300/s, research complex
  like 10 labs, nuclear 10 MW (a cell lasts 800 s). The rocket silo keeps its rate: its
  output is the win, not a flow (my call). City descriptions quote the new numbers.
- Throttle (found by the tests at half rate): a slow city's 0.6 s stock target was less
  than one craft's ingredients, so the depot ran short. Stock targets now never go below
  1.2 crafts (target), 2 (plenty) and 0.4 (low), what they were for the depot before. The
  stock correction is relative to the target (0.3 per target's worth off; the same as 0.5
  per second at the 0.6 s target), so a long target doesn't push a slow city harder.
- A slow city settles slower: an electric smelting city fed half its rate from an empty
  start swings 40-60% for about 50 s, then holds 50% (the test now samples 75-90 s). A
  test-only loader at a quarter of yellow speed gives that exact feed.
- Tests: rate expectations are the full vanilla-equivalent numbers times RATE where the
  test derives them; fixed numbers (water, nuclear, research) state the halves.

## 2026-11-21: 2.15.6 map generation lays out plot sites
- scripts/layout.lua plans sites, not cities: the starter site (4 plots) 40-80 tiles from
  spawn, then sites of 1-3 plots (equally likely) on rings stepping outward, each with its
  own elbow room of 1-2 spacings (skewed low; two sites keep the larger of their two), until
  there are at least 75 plots. Spacing = 300 x the "City spacing" startup setting (it was
  500 between cities). Typical game: 34-38 sites, 75-76 plots (smoke runs).
- A site's plots sit in a 2 x 2 grid at a 22-tile pitch: 12-tile plots with 10 tiles of
  ground between (room for a belt run or a rail; a tuning value). 1 plot alone, 2 side by
  side, 3 in an L, 4 in a square. A site is at most 34 x 34, which sites.lua checks (plus
  its margin) for every site.
- Placement reuses the land finder (dry mainland near the planned spot, else turned around
  spawn or a little further out). The site is cleared; painting a plot also removes ore and
  anything else not the player's under it, so a plot is clean ground.
- Each site is charted and tagged ("Start: 4 city plots", "3 city plots", "City plot"; icon
  refined hazard concrete, the plot's border). The land between stays dark.
- Gone with the city planner: depth-weighted distances, the starter depot / power / water
  rules, water cities on lake shores (sites.find_shore), compass names for repeated cities,
  and their tests. Chain depth stays: it orders the city items.
- The smoke runs check the new log line (sites, plots, none without land).

## 2026-11-21: 2.15.5 cities unlocked by research (table approved by the user)
- From the start: coal fuel depot, coal power, water, iron and copper smelting, red
  science, research complex, circuits (Electronics is a starting technology).
- Repair pack city: Repair pack. Steel: Steel processing. Green science: Logistic science
  pack. Electric iron and copper smelting: Advanced material processing (red + green;
  vanilla's electric furnace is on Advanced material processing 2, the user's call: mid-game
  is better for getting coal off the smelting lines). Refinery and solid fuel depot: Oil
  processing. Plastic: Plastics. Sulfur and sulfuric acid: Sulfur processing. Advanced
  circuits: Advanced circuit. Blue science: Chemical science pack. Processing units:
  Processing unit. Low density structure: Low density structure. Rocket fuel depot: Rocket
  fuel. Uranium: Uranium processing. Nuclear power: Nuclear power. Rocket silo: Rocket silo.
- The unlocks are added in data-final-fixes before restrictions.lua, so a technology that
  had nothing else left (Advanced material processing: the steel furnace only) stays
  visible instead of being spliced out of the tree.
- Rocket silo leaves HIDDEN_TECH_PATTERNS; its other effects (vanilla silo, rocket part,
  cargo landing pad, platform starter pack) are dropped. Planet and platform techs stay
  hidden.

## 2026-11-21: 2.15.4 building and removing cities
- One path for every city that appears: `cities.adopt(entity)` (protection, hidden
  generator, record, placement hooks). `cities.place` (script) calls it after
  create_entity; control.lua's build handler calls it for on_built_entity,
  on_robot_built_entity (newly registered), script_raised_built/revive and cloning.
- Cities stay minable (decision 5); operable, destructible and rotatable stay off. Before
  a player or robot mines one (on_pre_player_mined_item, on_robot_pre_mined), every
  inventory, its fluids and a silo's rocket parts are cleared: nothing reaches the player.
- In-place swap (upgrade planner, fast replace): when a city appears, records whose city
  is gone are cleared at once, so the old belt ports are gone before the new ones are
  made. One that stood on the same spot was replaced: the replace hooks run first, and
  signals.lua copies the player's wires from the old signal point to the new one.
  Contents carry over or not as the engine's fast replace does.
- The one-lane throttle test allows 4 short samples in 150 (was 2 for a full belt into a
  tier 2 city): a side-loaded lane arrives in clumps. It failed at 3 only after the tests
  before it moved its start tick relative to the once-a-second control.

## 2026-11-21: 2.15.3 plots and city items
- A plot is two tiles: tt-plot (a copy of refined concrete) inside a one-tile ring of
  tt-plot-border (refined hazard concrete, the "painted border"), both bright yellow-orange
  on the map. Not minable, no item places them.
- Both carry a custom collision layer, tt_plot. Cities require it under their whole
  footprint: `tile_buildability_rules = { { area = footprint, required_tiles = { layers =
  { tt_plot = true } } } }` (2.1 rules take collision masks, not tile names). The engine
  then shows the placement red off a plot and refuses it; `can_place_entity` with
  build_check_type manual agrees (tested). `create_entity` by script checks nothing.
- A tile item's `place_as_tile.condition` is a mask its target must not have: data-final-
  fixes adds tt_plot to every tile item's (concrete, landfill, other mods' floors), so a plot
  can't be covered. Rejected: re-painting plots by script after the fact.
- Each city kind is an item of the same name (icon: the city's source building with its
  product as a badge; subgroup "tt-cities" in Production, ordered by chain depth) and a free
  hand-craft "tt-build-<entity>". The city entity drops "not-blueprintable", "not-
  deconstructable" and "not-upgradable", mines into its item, and electric smelting is
  the coal-fired kind's next_upgrade (same fast_replaceable_group).
- Until map generation lays plots (2.15.6), the fixed map and the Nauvis layout paint a plot
  under each city they place (scripts/plots.lua), only where nothing of the player's
  stands. cities.snap gives the real position of an even-sized city for placement checks.

## 2026-11-21: 2.15.2 tier growth removed
- City definitions are flat (crafting_speed, power, recipe, ... on the definition; no
  `tiers` list), at today's tier 1 numbers until 2.15.7 halves them. Entity names stay
  "tt-city-<name>"; `city_defs.by_entity[name] = { def = def }`.
- Every city is the 12x12 Factorissimo building (factory-2 art); ports keep the +-2.5 lines
  (8 spots), so no port moved for a city's first layout. No double ports.
- Electric iron and copper smelting are separate kinds ("tt-city-electric-iron-smelting",
  `upgrade_from` names the coal-fired kind): same 15 plates/s, no coal, 4.32 MW (24
  electric furnaces). The upgrade planner swap comes with building (2.15.4).
- The signal point keeps the west tile of the door; it no longer sends T (tier).
  Wire save/restore stays for the upgrade planner swap.
- Removed with the tiers: construction ports and their chest, upgrade progress, upgrade and
  heads-up messages, tier pips, the dashed outline of the largest building, tier suffixes
  on map tags, /tt-port-fill, the save migrations of the tier era (pre-release: no saves to
  keep), and the power and water budget tests, which balanced tiers against the fixed map.
- The service port window said "Construction port for ..." (shared locale key): now
  "Service port of ...".
- Tests: 214 (from 263; upgrade, tier and migration tests removed). The steady-throttle
  test now feeds an electric smelting city one lane of a yellow belt (side-loaded, 7.5/s,
  half its rate) instead of a tier 2 city a full belt.

## 2026-11-21: player-built cities on plots (user; phase 2.15 proposed)
- Direction (user, after the 2.14.0 playtest): the player builds the cities, for free once
  researched, but only on plots that map generation paints. There are many more plots
  than today's cities, and each city is weaker, so a product comes from several cities
  and the vanilla stops-with-one-name feature (a train goes to the nearest open stop)
  matters again. Replaces the fixed city per product (SPEC "placement is fixed by the
  world").
- Rejected: unassigned buildings already on the map that the player gives a role once
  (no blueprints; a scripted swap instead of normal building; a wrong pick can't be
  undone).
- Agreed with it: no tier growth (you scale by building more cities), no rotation, plots
  in small sites far apart (so belts between sites don't replace trains).
- Details (user): every city 12x12 (rejected 8x8: small next to a train); tiers that change
  the kind (coal -> electric smelting) become separate city kinds swapped in place by the
  upgrade planner, speed-only tiers go; output half of today's tier 1 to start (rejected a
  third); sites of 1-3 plots, 300+ tiles apart, ~75 plots, a starter site of 4; removing a
  city loses its contents (rejected: no removal); the hand-made MVP scenario leaves the menu
  and stays only as the tests' fixed map (rejected: converting it to plots).
- 2.14.1 onward is parked until 2.15 is done: a recorded full run would tune numbers
  that are about to change.

## 2026-11-21: 2.14.0 the user's QoL mods in the playtest
- Playtest (~73 min, no errors in the log): Far Reach, Infinity Invo, Jetpack, Quick
  Adjustable Inserters (with inserter-throughput-lib), Squeak Through 2 and Speedy Bot
  Start load after the user updated them in the instance's mod manager. Even Distribution
  2.1.0 crashes on init (it reads `fuel_category`) and is left out of
  tools/playtest-mods.txt.
- The round led to the personal robots rule (entry below) and the plots redesign
  (entry above).

## 2026-11-21: personal construction robots (user)
- Rule change (user): building is free, so building fast is fine. Personal construction
  robots are allowed; roboports on the ground and logistic robots stay out, so robots never
  move cargo between places. Options rejected by the user: also allowing ground roboports
  for construction (networks could span the map); getting the kit by research.
- Start kit (scripts/start_kit.lua, once per player, in the scenario and the generated test
  map): power armor (6x8 grid) with a fission reactor equipment (750 kW, needs no fuel), two
  personal roboports, two batteries; 20 construction robots. Equipment goes into the grid
  with LuaEquipmentGrid.put (player.insert can't fit it).
- Construction robots are a free hand-craft, unlocked from the start (Construction
  robotics joins the start research), to replace lost ones. Armor and equipment stay
  uncraftable: the kit is all there is.
- Construction robots fly 5x the vanilla speed (0.3 tiles/tick) and use no energy, like
  the user's Speedy Bot Start, so they never wait at a personal roboport to recharge
  (user asked for fast bots). Research speed bonuses come on top.
- Robots repair damaged entities near the player with repair packs from the player's
  inventory, locomotives included. That matches the spec's manual repair on site.
- Speedy Bot Start (the user's QoL mod) adds nothing in a Tracktorio game: it hands out its
  items through the freeplay interface, which the scenario doesn't use.

## 2026-11-21: 2.13.1-2.13.5 a clearer city window
- One compact page (user's pick over tabs). Order: coloured status (green running, red
  starved, orange output full, yellow power or other) with a short hint only when
  something is wrong (starved: "Belt X into its port, top left"); a flows table (item,
  in/out/fuel, now/min, max/min, held); ports one line each with a belt icon for the belt
  it needs (rate in the tooltip); "Signals at the door" with what they send in its
  tooltip; servicing in one line; tier, next tier and one row per material (icon, count,
  bar).
- Explanations moved into tooltips: the description on the title, the port rules on
  "Ports", servicing rules, where to deliver materials (tier lines), the silo's recipe.
- Dropped: "One cycle takes N s of work at speed 1" (no use to a player) and the "per
  cycle" amounts (the table shows rates).
- Element names and locale keys tests rely on were kept (status, hint, port-i, tier,
  service, silo, also_missing, power_use).
- LuaLS mistypes LocalisedString tables assigned to GUI fields; such locals are typed
  `any`, as elsewhere in the code.

## 2026-11-21: 2.12.10 throttle momentum
- User asked for more momentum, and whether a city could wait for a big enough buffer and
  then use it at a rate set by its size. The engine caps what a crafting machine takes in
  (about 1.2 s at full speed; loaders respect it), so the stock inside a city stays
  small; the belt in front of the port is the real buffer and backs up while the city
  runs slower than it is fed. So instead: fed and taken rates are averaged over ~10 s;
  the speed moves at most one 5% step every 2 s and only when the wanted speed is more
  than a step away (or at the 100% / 20% ends); under 0.2 s of stock it may slow a step
  every run, so it doesn't fall back into stop-start.
- The window's "max per minute" uses the prototype's full crafting speed; the entity's
  crafting speed includes the throttle.

## 2026-11-21: 2.12.9 playtest bugs
- 2.1: moving an item on a transport line (remove_item / insert_at_back) invalidates the
  LuaItemStack references from an earlier get_detailed_contents of that line. The lane
  balancer now copies name and quality when it takes its snapshot.
- The "not-selectable-in-game" flag alone did not keep the player out of the throttle
  beacon. It now has no selection box (selectable_in_game = false) and is protected like
  the other hidden parts (not operable, minable or destructible).

## 2026-11-21: 2.12.6 coal fuel icon
- Coal fuel is drawn as briquettes: Space Age's carbon icon (also as its belt picture) in a
  warm tint. User's pick from mock-ups of briquettes, glowing coal and coal with a big
  flame. A different shape reads apart from coal at belt size; a small badge didn't.
  Carbon itself never appears in play (planets are off).

## 2026-11-21: 2.12.2-2.12.5 throttle controller
- Every crafting city with ingredients and the research complex gets a throttle beacon at
  its centre; power cities (is_power: power and nuclear), water cities and the silo don't.
  Replaced on upgrade, destroyed with the city.
- Crafting cities, each second (rates over the real time since the last run):
  fed = crafts done + change in input stock (scarcest ingredient, a craft under way counts
  as stock); want = fed / full + 0.5 x (stock in seconds - 0.6). A second of stock or
  more: 100%. Output past one second of stock and still being taken away: at most the
  rate it is taken. Smoothed half-way per second, rounded to 5% steps, floor 20%.
- A side where nothing moved for 2 s stops limiting: with no input at all a city uses up
  its stock and reports starved; with nothing taken away it fills up and reports output
  full. Crawling at 20% would only delay what the player needs to see (found by the
  uranium and refinery tests).
- Research complex: one step slower per second while short of a pack its research needs
  (1 or fewer), one faster with 2 or more of each.
- Measured: a tier 2 smelting city fed one yellow belt (half its 30/s) settles at about
  50% and never stops over 15 s of sampling.
- "Low power" flickers for a moment when the module count changes; the status signal
  already counts it as running.

## 2026-11-21: 2.12.1 throttle spike
- A hidden beacon (void energy, profile {1}, distribution effectivity 1, empty collision
  mask, supply area distance 1 around a 0.8-tile box at the city's centre) with N modules
  of speed -5% and consumption -5% gives its city exactly -5N% on both: 10 modules ->
  50% crafting speed, 16 -> 20% (the floor). Effects add up linearly in one beacon.
- The supply area overlaps only the city: a drill at the wall and a machine just outside
  get no effect.
- Cities now allow speed and consumption effects (they had none); only the throttle
  beacon gives them, since the player has no beacons or modules.
- The beacon hides its module icons in alt mode (icon scale 0).

## 2026-11-21: 2.11.5-2.11.6 locomotive tiers
- Mk2 and Mk3 are copies of the vanilla locomotive with the user-approved stats (900 kW /
  1.2 MW, 290 / 324 km/h, fuel effectivity 125% / 150%, wear 5% / 3% per minute). Free
  recipes through config.FREE_ITEMS; technologies Mk2 (red + green, after Railway and
  Logistic science pack, 200 units) and Mk3 (red + green + blue, after Mk2, Advanced
  circuits and Chemical science pack, 300 units). Counts are a first guess for the full
  run (2.12) to tune.
- Look: the vanilla art in a different default colour (blue, purple), icons with the tier
  digit. No new art.
- Limp mode is relative: a limping Mk3 runs at 25% of its own top speed (0.375 tiles/tick).
- 2.1 surprise: a technology named `x-2` is read as level 2 of `x`, so its locale lookup
  goes to `technology-name.x`. The tier technologies set `localised_name` outright.
- LuaEntityPrototype has no top speed field for locomotives; tests read
  `train.max_forward_speed`.

## 2026-11-21: 2.11.1-2.11.3 city signal points
- Signal points are copies of the vanilla constant combinator, kept visible (the plain
  combinator look says "wire here"), with an empty collision mask so they sit inside the
  building, selection priority above the city, protected and not operable (the player
  can't edit them; script writes one section every second).
- 2.1 surprise: a constant combinator filter needs a quality on every signal, not only
  items. Without `quality = "normal"` fluid and virtual signals are silently not sent.
- A combinator's output reaches the network one tick after it is written (tests wait a
  tick).
- Upgrades: the player's wires (origin "player") on the old points are saved and
  reconnected to the new points, with a reach check; wires to things cleared from the
  bigger footprint go with them.
- Status signals are custom virtual signals (running, starved, output full, no power);
  low power counts as running. Tier is the vanilla signal T. Silo: rocket parts as the
  rocket-part item signal.
- Clicking a signal point opens its city's window, except with something in the cursor
  (a wire being connected).
- Not verifiable by test: a player dragging a wire by hand onto a non-operable point.
  The playtest (2.11.8) checks it.

## 2026-11-21: 2.10.20 playtest round 2
- Cities don't show the engine's recipe icon in alt mode (`show_recipe_icon = false`; the
  map icon stays): it drew the product and the source building's icon over the roof icon.
- Footprint outline a little stronger: 15% grey at 20% opacity (was 12%/12%).
- The window's construction text points at the steel chest marker instead of "top-left
  corner (west side)", which ports no longer follow.

## 2026-11-21: 2.10 playtest fixes (2.10.13-2.10.18)
- Tier pips: radius 0.2 (was 0.34), 0.55 apart, centred on the top edge between the port
  markers. They never scaled with the building; they were just big next to the markers.
- Construction port: marked with the steel chest icon everywhere (wall marker, window,
  README); user choice over the upgrade arrow and a tier number. Construction and service
  ports are separate loader prototypes, so hovering each shows its own name and
  description.
- Port loaders draw no belt: a transparent 1x20 sheet (20 belt directions, one frame)
  replaces the belt animation, so an unconnected port shows no moving sliver.
- Footprint outline: near-black at 12% opacity, 1 px, short dashes.
- Coal fuel: the coal icon with a flame badge (the "fire" signal icon) in the corner; user
  choice over tinted coal and a solid-fuel look.
- Upgrade power warning: with no power city on the network it now says so ("No power city
  is on its pole network yet") instead of "power cities on it make up to 0 MW"; the weak
  case reads "... but the power cities on it make only Y MW". Checked it was not a fault:
  a power city on the same poles is counted (new test).
- Output lanes (2.10.19, user: both lanes evenly). At 15/s a port fills both lanes evenly
  (12/12 ... 84/84), but a slow output (the depot's 2 coal fuel/s) went entirely onto one
  lane until it backed up, then the other: the engine's loader puts single items on one
  lane, and no loader setting changes that. The input side plays no part. Scripted fix:
  each output port keeps a tally of items per lane and moves a new item from the busier
  lane to the other (items told apart by unique id, so none counts twice). A port is
  looked at every other tick, only output ports are kept in the list, and backed-up ports
  are skipped: the test suite runs 94 s against 88 s without it (a first version that
  walked every city record each tick took 174 s).
## 2026-11-20: roof icons (user, before the 2.10 playtest)
- Every city but the silo has a large icon of what it makes painted on its roof, as in
  Factorissimo, so cities tell apart at a glance: its first product, or `roof_icon` in its
  definition (power city: steam engine; nuclear: reactor; research complex: lab). About 3.6
  tiles on the 8x8 building, scaled with the size; centred on the roof in the art.
## 2026-11-20: 2.10.9 ports in the city window
- The window's "Pipe connections" list became "Ports": one line per port at this tier,
  with the item or fluid icon, in or out, where on the wall ("top left", ...) and what it
  carries at full output: the slowest belt that is enough (yellow 15/s, red 30/s, blue
  45/s, turbo 60/s) or the fluid flow. Construction and service ports say so. Tier 3
  smelting lists its two ports per item at 30/s each (red belts).
- City descriptions no longer mention inserters or pipe positions; they point at the
  ports.
- 2.1: `LuaEntityPrototype.fixed_recipe` is the recipe prototype, not its name.
## 2026-11-20: 2.10.8 footprint
- Below its last tier a city shows a dashed grey outline on the ground (decal layer, under
  belts) of the 16x16 building it grows to. Drawn on the city entity, so the next tier
  redraws it and the last tier has none.
- Sites already reserve 16x16 (2.10.3). On the fixed test map every city's 16x16 footprint
  is clear of water, ore and other cities; nothing had to move.
## 2026-11-20: 2.10.7 growing on upgrade
- Before the bigger building goes in, what the player built inside its footprint is mined
  (contents too, like a player mining it) and goes to the nearest connected player of the
  city's force; what doesn't fit, or with nobody online, is spilled just south of the
  building. Characters there step outside. Mod entities stay for the swap.
- Belts keep working: a belt that ran into a tier 1 port is now 2 tiles shorter and runs
  into the same port on the moved wall (tested with a station built at tier 1).
- Inserters within 3 tiles of the new walls are checked as if just built; one that now
  reaches the city goes back to that player.
- Not handled: rails under a train can't be mined, so a train standing in the footprint
  keeps its rails under the new building. Sites reserve the 16x16 footprint (2.10.8 marks
  it), so a player has to build there on purpose.
## 2026-11-20: 2.10.6 construction and service by port
- The construction and service chests are hidden inside the building (no collision, not
  selectable, no picture). Each is fed by a port in the wall like the item ports, marked
  with a green upgrade arrow (construction) or a repair pack (service). The chests' slot
  filters still decide what they take, so a wrong item jams the belt.
- On the 8x8 building the item ports at the corners share their front tiles, so a chest
  one tile behind a port could steal another port's items. These ports use a second
  loader prototype, `tt-belt-port-box`, that reaches two tiles in (container_distance 2),
  and the chest sits there, clear of every item port's front tile.
- A hidden chest can't be blocked by the player, so the "port tile is blocked" messages
  and their retry logic are gone.
- Clicking any port opens its city's window.
## 2026-11-20: 2.10.5 no inserters on cities
- Engine flags "no-automated-item-insertion/removal" were tried first: they block loaders
  too, so they can't be used. The rule is scripted instead.
- An inserter built (by a player or raised by script) or turned so that it picks from or
  drops into a city or a port goes back to the player's inventory, with a flying message
  to use the belt ports; with no player it is removed. The construction and service chests
  still take inserters until 2.10.6; the MVP goal box (old saves, tests) keeps them.
- An inserter finds its targets a tick after it is built, so the check runs on the
  following ticks (up to 10).
- Build events now go through one handler in control.lua (a mod gets one handler per
  event), shared with the locomotive tracker.
- Tests still create inserters by script without raising the build event, to feed cities
  in tests about other things; 2.10.10 moves the helpers to belts.
## 2026-11-20: 2.10.4 belt ports
- A port is a hidden loader (`tt-belt-port`, from loader-1x1) under the wall tile, filtered
  to its item, input loaders facing in and output loaders facing out. The player's belt
  ends on the tile just outside and runs into it, as in Factorissimo.
- Speed 0.125 (turbo, 60/s), so the player's belt is always the limit. Measured: one
  yellow belt per item runs tier 1 smelting at its full 15 plates/s; tier 3 smelting's two
  blue belts per item run it at 60/s.
- 2.1 requires a loader's collision mask to collide with belts: it has the transport_belt
  layer only, so it sits inside the building without colliding with it. No structure
  sprite; the building covers it.
- Markers: an arrow on the ground outside each port (in or out) and the item's or
  fluid's icon on the wall. They are drawn on the city, so they go with it. Hovering the
  port shows "City port".
- A loader finds what it feeds a tick after it is built.
- Inserters still reach cities until 2.10.5; one dropping next to a port puts items on
  the port's belt. The end-to-end train test now feeds the city by belt.
## 2026-11-20: 2.10.2-2.10.3 building art and sizes
- Cities draw the Factorissimo building of their tier (8x8, 12x12, 16x16) at its own
  scale and shift. The research complex too. The rocket silo keeps the vanilla silo (9x9,
  one tier): its rocket and launch animation is the point of it.
- The vanilla machine a city used to look like still lends its icon and sound. 2.1
  refuses a sound that names a working visualisation the new graphics lack (the
  electromagnetic plant's "warm-up"), so those parts are dropped; if none is left, the
  loop plays for all of the working time.
- Even sizes centre on a tile corner. `cities.place` snaps to the corner at the top left of
  the tile asked for, so the north and west walls stay where a 9x9 city's were and an
  upgrade (same centre) grows evenly on every side.
- Port layout in shared/port_layout.lua, used by both stages: inputs take the north wall
  first, outputs the south; construction and service take what is left. Fluid
  connections are laid out the same way, so pipes moved (refinery: inputs now north,
  outputs south). Tier 3 smelting's second ports sit one line further out.
- Sites reserve the 16x16 building: HALF 8. The margin around it went from 8 to 4 (it was
  for the port chests, which go in 2.10.6), so the dry, cleared area is 24x24, about the
  25x25 it was. Shore and lake checks behave as before.
- Interim until 2.10.6: when a depot grows, its service port chest moves outward; the
  packs move to the new chest and the old one goes.
## 2026-11-20: 2.10.1 loaders as belt ports (spike result)
- A 2.1 loader-1x1 only connects to entities with the "player-creation" flag. Vanilla
  machines have it; our cities didn't, so loaders ignored them (inserters don't care).
  Cities, the silo and the goal box now carry the flag. Found by elimination: protection
  flags (operable, destructible, ...), collision box, energy source, fixed recipe and
  crafting category made no difference.
- With the flag, a loader at the wall fills an assembling-machine city's inputs, the
  nuclear city's fuel slot, the rocket silo and the research complex (a lab), and takes a
  city's output.
- A wrong item is refused and stays on the belt, blocking it (like vanilla).
- A chest placed inside the building, on the tile in front of a port, wins the loader's
  target over the city. That is how construction materials and repair packs will enter:
  a hidden chest per such port, counted by script.
- Loader direction is the direction items move: an input loader faces the city, an
  output loader faces away from it.
- Throughput not settled yet: the vanilla loader-1x1 is yellow speed. The mod's port
  loader gets its own prototype with a top speed (2.10.4).
## 2026-11-20: phase 2.10, Factorissimo buildings and belt ports (user decisions)
- Art: the Factorissimo 3 buildings (MIT, (c) MagmaMcFry, checked in the 3.11.19 package;
  no separate art license), copied in with the license notice. No dependency, no code:
  Factorissimo's belt connections link to an inside surface, which we don't have.
- Size grows with tier: 8x8, 12x12, 16x16. Rejected: one size for every tier; size by
  city type.
- Items go in and out only by belt ports; inserters can't reach a city. Rejected: ports
  alongside inserters. Fluids stay on pipes, at port spots.
- One port per item. Tier 1 peaks at 15/s (one yellow belt), tier 2 at 30/s (red). Tier 3
  smelting (60/s) gets two ports per item: turbo belts need Vulcanus research, unreachable
  with planets off. Rejected: tier 3 smelting slowed to 45/s; turbo belts made
  researchable.
- Port lines stay put through upgrades: the upgrade clears the new footprint and a belt
  into the old port runs into the new one. The 16x16 footprint is marked from the start.
- The construction and service chests go: those items enter through ports on the
  building too (user: conceptually they are part of the city).
- Every port is clearly marked (item icon, in/out arrow); which spots are used matters
  less (user).
## 2026-11-20: water stays plentiful
- Water cities keep 600/1,200/2,400 water/s. Four tier 1 water cities supply 2,400/s
  against 979/1,958/3,916 demand at tiers 1-3, so supply is never the limit.
- Why: the user wants shipping water to be the challenge, not running short of it.
- Rejected: 300/s at tier 1, which would make supply about equal to demand at each tier.
- The spec's rules list no longer names offshore pumps as free; its MVP section notes
  they were removed later.

## 2026-11-20: 2.9.4-2.9.5 water cities in the layout, the starter trio
- Four water cities join the layout: 30 cities now. The first is the starter water city;
  the others spread like the coal power cities (each further copy one level deeper,
  compass names, at least 3x the minimum apart). Each stands on a lake shore: dry site,
  water within 12 tiles of its edge, at least 600 tiles of lake within 40. If no shore is
  in reach (640 tiles), it takes any land.
- Placement order: the depot, then the starter water city on the lake shore nearest spawn
  (within 600 tiles), then the starter power city 30-80 tiles from it (pipe distance),
  then the rest. Without a shore near spawn, the starter water city stands 30-80 tiles from
  the starter power city instead. The trio is exempt from the minimum among itself.
- Measured (3 seeds at 1x): starter pair 55-64 tiles apart, the starter water city 40-112
  tiles from spawn, 4 of 4 water cities on a shore every time.
- Speed. Adding shores first made a layout take 8-20 s. Changes:
  - searches whose whole circle is ruled out by a placed city return at once;
  - the "turn around spawn" fallback only searches (96 tiles) at spots that are free, and
    steps 15% further out (up to 4 times) when a ring is crowded, which also fixed a city
    finding no site (seed 161803, Sulfur city);
  - grids are built in stages (96, then 320; shores 160, 400, 640);
  - shores forecast on an 8-tile grid;
  - a shore candidate generates only the chunks under its lake circle.
  Now 2.8-5 s per layout at 1x, and 3.8 s at 3x.
- The fixed test map gets water cities at (-220, 30), (70, -170), (290, -10) and
  (-440, 110), each at least 110 tiles from every patch, lake and city.

## 2026-11-20: water city (phase 2.9), user decisions
- Starter pair: a starter water city stands within pipe distance (30-80 tiles) of the
  starter power city. Filling a fluid wagon needs an electric pump, so the first power
  can't come from a water train. Rejected: a one-off water store in the starter power
  city; water cities that fill wagons without a pump.
- Four water cities at 600 / 1,200 / 2,400 water/s per tier. Rejected: 3 at 1,200; 6 at
  300.
- Water cities stand on lake shores. Rejected: anywhere.
- Offshore pumps are removed outright. The user has no saves to keep ("We're literally
  building this from nothing"). Pre-release, save migrations and old-save compatibility
  are suspended (CLAUDE.md).
- No inputs and no power: the 2.x offshore pump draws no power (SPEC power rule).

## 2026-11-20: 2.8.14 starter power city, power cities further apart (user, playtest 2.8.13)
- User: "make sure one appears fairly close to the start. you really need power and fuel
  to even start properly." The first coal power city is the starter. It plans 200-350
  tiles from spawn, right after the depot, and the depot-starter pair is the one pair
  exempt from the 500-tile minimum (they only keep 100 apart). The starter's elbow room is
  the minimum, like the depot's.
- Power cities (coal and nuclear) keep at least 3x the minimum apart: 1,500 tiles at 1x.
- One function (layout.need) gives the distance any two cities must keep. The planner and
  the site search on real terrain both use it, so moving a site can't break these rules.
- Measured (10 seeds, 1x): starter 200-350 tiles from spawn; mean distance of the other
  coal power cities 4,400 / 5,200 / 7,000; nearest neighbour otherwise min 527, median
  956. All tuning.
- Rejected: making the starter keep the full 500 from the depot (~550 tiles from spawn),
  which is the walk the user wants to avoid.

## 2026-11-20: 2.8.12 varied city distances (user, playtest 2.8.11)
- At 750 tiles the layout was "too uniform": every city kept the same distance, which
  packs them into an even grid. User: "I'd like the minimum distance to be as low as 500
  but the variance should be a lot higher."
- The minimum is 500 tiles at 1x, a hard floor (the site search no longer allows 0.8x).
  Each city draws its own elbow room: spacing x (1 + 3 x random^2.5), so 1x to 4x, mean
  ~1.75x. Two cities stay at least the larger of their two elbow rooms apart. The coal
  fuel depot keeps only the minimum, so it doesn't push the early game away. Distance
  from spawn is more random too: 1.5 + 5 x (0.4 x depth share + 0.6 x random) spacings.
- Measured, 10 seeds at 1x: nearest neighbour min 515, median 974, 10% under 581, 10%
  over 1,852, max 2,355 tiles. The furthest city is ~4,000 tiles from spawn. All tuning.
- Rejected: one wider random range of distance from spawn alone, which still packs the
  cities evenly, because the uniform minimum is what sets the grid.

## 2026-11-20: Tracktorio is its own game (user, playtest 2.8.9)
- Starting through "Freeplay (Space Age)" was misleading: its description is of another
  game, and a mod can't change it. Tracktorio's own scenario is now the way to play.
  "Tracktorio" under Mod scenarios has its own title and description, and sets up
  procedural Nauvis. It has no pre-built map, like Sandbox and Rocket rush, so it should
  get the map settings screen (seed, preview); the 2.8.11 playtest checks that. The mod
  detects the scenario with `script.level` (mod "tracktorio", level "tracktorio") in its
  on_init. It gives the 20 coal fuel itself and charts 200 tiles around spawn, as
  freeplay does.
- Freeplay with the mod on still sets up the same game, so nothing breaks (normal
  Freeplay can't work with furnaces and assemblers removed). A message says this is
  Tracktorio and where to start it properly. Rejected: only a warning, which leaves an
  unplayable game.
- The fixed hand-made map is no longer a playable scenario. The tests still build it
  through the tt-map remote interface, and old saves on it keep working. Rejected:
  keeping it as a second "classic" scenario, one more thing to keep up to date.
- The scenario's locale used the key "tracktorio=" instead of "scenario-name=", so the
  menu showed the raw "Tracktorio/tracktorio".
- run-tests.ps1 smoke-runs both the Tracktorio scenario and Freeplay, and checks each
  lays out Nauvis with every city.

## 2026-11-20: playtest 2.8.7 findings
- All four coal power cities landed near the start, because they all have depth 1. Now
  only the first copy of a city type plans at its own depth, and each further copy plans
  one level deeper. Over 10 seeds at 1,000 tiles, the mean distances of the four copies
  are 1,875 / 2,235 / 2,700 / 3,217 tiles. Rejected: a fixed ring for copies, which goes
  against the user's "at random" rule.
- Repeated cities are named for their direction from spawn (8 compass sectors): "North
  power city", "South-west power city", and "East power city 2" when two share a sector.
  User's choice over numbering by distance or identical names. This applies to
  procedural maps only; the fixed scenario map keeps its names.
- City spacing at 1x is 500 tiles, down from 1,000, so the next playtest can compare
  ("1,000 tiles feels a bit much maybe"). Playtest 2.8.9: 500 is "too tight", so 1x is
  now 750 tiles; the user will get a feel for it in the next playtest.
- The goal box targets are no longer map settings: new maps have no goal box, and the
  settings only confused. They live in storage.tt_goal.targets with a default of 20,000;
  `/tt-goal <iron> <copper>` still sets them. A custom target set through the old
  settings goes back to 20,000. No migration: the default applies when the field is
  missing.
- Playtest tooling: the playtest copy's config.ini needs "; version=13" first, or the main
  menu says "Configuration file has invalid contents". Earlier playtests launched straight
  into the scenario and never reached the menu. My first guess, an obsolete check-updates
  key, was wrong.

## 2026-11-20: cities are on the map from the start (user, playtest 2.8.7)
- Reverses the 2.8 plan decision that cities are found by uncovering the map. The user:
  "Running around the map looking for the city you need without biters or any real
  challenge isn't what's fun about this mod."
- At the start, 16 tiles around each city are charted, so every city's tag shows from the
  first moment. The land between cities stays dark. The on_chunk_charted tagging stays as
  is: it puts the tags on when those small areas are charted.
- Rejected: charting the whole layout area, which at 1x is ~7,000 tiles across and slow to
  chart, and gives away the terrain for free.

## 2026-11-20: 2.8.4 New Game on Nauvis
- A game counts as a New Game when the freeplay remote interface exists. Then the mod's
  on_init sets up Nauvis (scripts/nauvis.lua). Freeplay's own on_init runs first and waits
  for remote calls, so the mod turns off the crash site (its ship and debris hold furnaces
  and drills) and the intro, and replaces the starting items with the scenario's 20 coal
  fuel. Respawn items are emptied. The Tracktorio scenario and the test scenario are not
  freeplay, so they leave Nauvis alone.
- Biters off: enemy-base autoplace at 0 and no_enemies_mode, the surface set peaceful,
  expansion and evolution off. Enemy entities in any chunk are destroyed, both chunks that
  exist at the start and chunks generated later (on_chunk_generated). Resources within 300
  tiles of spawn (tuning) are destroyed the same way.
- Verified (user question): after prepare, the generator places no nests at all; the
  clean-up is only a backstop. Same seed and area, biters left on: 865 nests. Prepared:
  0 enemies removed from the newly generated chunks. What stops them is the enemy-base
  autoplace set to 0; no_enemies_mode alone did not.
- A city that finds no site near its planned spot, for example behind a big lake, tries
  spots at the same distance from spawn, turned +15, -15, +30, -30 degrees and so on
  around it. That keeps the depth weighting. (Seed 271828: the Circuit city needed it.)
- run-tests.ps1 now also smoke-tests base/freeplay with the mod and checks the log for
  "Nauvis layout: 26 cities placed, 0 without a site".
- Rejected: waiting for on_player_created, which comes after freeplay has already given
  its items; a Tracktorio scenario with random maps, which the user turned down.

## 2026-11-20: 2.8.3 city sites on real terrain
- Water is forecast from the map generator's `elevation` property, read with
  `LuaSurface.calculate_tile_properties`: below 0 is water on Nauvis. Land counts only
  from elevation 1, a little above the shoreline. This needs no chunk generation (10,000
  points in ~9 ms; a chunk costs ~3 ms). Points in chunks that already exist use the real
  tile. A planned spot that is fine is checked directly. Otherwise one grid, a point per 4
  tiles, covers the whole search. Only the chunks under the chosen site are generated,
  and its real tiles are checked again. All 26 cities take ~3.4 s on a vanilla Nauvis
  surface (first try: 9.2 s with per-candidate queries; 74 s when whole squares of chunks
  were generated).
- A site is the 9 x 9 city plus an 8-tile margin, with no water. It counts as mainland
  when at least 6 of 16 rays out of it stay on land for 96 tiles: an island fails nearly
  all rays, and a shore with water on one side still passes. Trees, rocks, cliffs, fish,
  decoratives and enemy entities on the site are cleared. Cliffs are cleared rather than
  avoided, because elevation can't forecast them.
- A site moves at most 320 tiles from its planned spot. Cities stay at least 0.8 x the
  spacing apart after the move (seed 314159: furthest move 264 tiles).
- 2.1 surprises: `game.default_map_gen_settings` mixes every planet's autoplace (oil
  ocean, lava, ice tiles, gleba spawners). Use `game.surfaces.nauvis.map_gen_settings`
  for Nauvis terrain. `no_enemies_mode = true` still placed biter spawners in the chunks
  generated by script. Rejected: avoiding cliffs, which needs the chunks generated first.

## 2026-11-20: 2.8.2 layout planner
- Cities are placed one at a time: the coal fuel depot 40-80 tiles from spawn, then the
  rest from shallow to deep. Each draws a distance from spawn of 1 + 2.5 x (half its
  depth share + half random) spacings and tries 30 random angles there. If none is at
  least the spacing from every placed city, the distance grows 10% and it tries again.
  Measured (10 seeds, 1x): mean distance 1,650 tiles at depth 1 up to 3,400 at depth 5.
  The furthest city is about 1,700 / 3,450 / 10,350 tiles out at 0.5x / 1x / 3x. All of
  these numbers are for tuning.
- 2.1 surprise: LuaRandomGenerator treats seeds below 341 alike (seeds 7 and 8 gave the
  same layout), so the map seed is spread first (`layout.mix_seed`).
- Rejected: Poisson-disc filling of a fixed disc, which gives no control by depth;
  rings by depth, which the user turned down.

## 2026-11-20: procedural maps (phase 2.8), user decisions
- New games start from the normal New Game screen on Nauvis, with vanilla terrain (lakes,
  trees, cliffs) and vanilla resource patches, and no resources near spawn. The scenario
  stays as the fixed hand-made map that the tests use. Rejected: a scenario that makes
  random maps of its own; flat grass with scripted features; scripted patches only.
- Cities take no account of resources ("cities shouldn't even know where their raw
  resources are located").
- At least 1,000 tiles between cities, starting value: the user wants it as near the
  upper limit as is playable. "Everything is free so it's much easier than in vanilla."
  A startup setting scales it from 0.5x to 3x. Rejected: 200, 300 or 500 tiles.
- Deeper cities in the production chain are more likely to be far from spawn, but at
  random. Rejected: purely random positions; strict rings by depth.
- Biters are forced off. The layout is not charted up front: the player finds cities by
  uncovering the map, and a city's tag appears when its chunk is first charted.

## 2026-11-20: playtest 2.7.5, keep vanilla behaviour out of playtests
- The user checked research gating, free items, ramps and elevated track, and skipped the
  water, limp and breakdown steps as standard Factorio behaviour. Those are covered by the
  automated tests in tests/cases/elevated.lua. Phase 2.7 is closed.
- From now on, playtest checklists cover only what the mod changes or adds. Vanilla
  behaviour that a mod change could affect is left to automated tests.
- Rejected: repeating the skipped steps. They test the engine, not the mod, and the
  automated tests already cover the places where the mod's own systems (limp, reliability)
  meet elevated track.

## 2026-11-20: 2.7.3-2.7.4 trains on elevated track
- Tested on a scripted overpass (ground line, ramp up, elevated rails over a crossing
  ground line, ramp down, ground stop): a fuelled train makes the trip; a fuel-empty train
  limps over it under the limp speed cap and arrives; a train that breaks down on
  elevated track limps and a repair to full health cures it. No mod code needed changing.
- 2.1 notes: a script-created rail ramp is 16 tiles long; facing east, its ground end is
  8 tiles west of its centre and its elevated end 8 east. `LuaEntity.rail_layer` works
  only on rail signals; elevated rails are told apart by type ("elevated-...").
- Servicing still needs a train stop near a depot. Elevated track has no stops, so a train
  is serviced on the ground as before.

## 2026-11-20: 2.7.1-2.7.2 elevated rail research and items
- Elevated rail retuned in mod/prototypes/technology.lua (data-final-fixes, before the
  restrictions pass): 500 x red/green/blue x 30 s after Concrete and Chemical science pack.
  Unlocks unchanged. The gating test finds no new trigger blockers.
- Rail ramp and rail support were already free items; elevated rails are placed with the
  free rail item and signals with the free signal items. Before the research the ramp and
  support recipes are locked and the rail planner can't build elevated track.
- 2.1 check: water tiles (water and deepwater) don't collide with the layers a rail
  support uses, so supports stand in the lakes and elevated track can cross them. Ground
  rail can't. Only deep oil ocean (not on this map) refuses supports.

## 2026-11-20: Project renamed to Tracktorio
- User decision: the project is called Tracktorio. Internal mod name `tracktorio` (was
  `train-tycoon`), test mod `tracktorio-tests`, scenario `tracktorio/tracktorio`, map
  surface `tracktorio`, locale files renamed. The `tt-` prefix of prototypes, storage keys,
  commands and remote interfaces stays.
- Older entries in this log, finished PLAN items and START.md keep the old name: they
  record what was true then.
- Saves made before the rename don't load the mod (Factorio sees a different mod). Only
  playtest saves existed, so no migration.
- tools/dev-instance.ps1 now removes junctions into the repo that it no longer manages, so
  the old `train-tycoon` junction can't load a second copy of the mod.
- Not renamed: the repo folder (`TrainTycoon`) and any GitHub repository; the user can do
  that outside the session.

## 2026-11-20: Phase 2.7 elevated rails, gating
- Found: in 2.1 Space Age, Elevated rail (unlocks rail ramp, rail support and building
  elevated rails) costs 100 x red/green/blue/purple after Concrete and Production science
  pack, so it was unreachable (the complex takes no purple).
- User decision: retune it to red + green + blue (proposed 500 units x 30 s), after
  Concrete and Chemical science pack. Rejected: a production science city (needs a stone
  patch and bricks, and opens the whole purple tree, which would need its own review).
- User decision: no test-map terrain for elevated rails now; it comes with procedural maps.

## 2026-11-20: 2.6.6 playtest: nuclear runs flat out
- User decision: the nuclear power city can't throttle, like a vanilla reactor. With fuel
  in it burns at its full rate (one cell per 400 s at T1) whatever the demand. Unused steam
  is vented every second (scripts/nuclear.lua; steam output enlarged to 4000 so a T3 city
  never backs up between vents). The window adds "your network uses N% of its output; the
  rest is wasted".
- Rejected for now: load-following (nuclear becomes coal power with cheaper fuel). Noted as
  a future idea (user): a circuit signal of the city's steam level so players can control
  the fuel inserter, as in vanilla nuclear builds.
- Rates under 10/min now show one decimal (the uranium city's 0.6 and 1.2 cells/min both
  read "1").
- 2.1 surprise: `LuaEntity.remove_fluid(index, amount)` takes a fluid storage index and
  returns a Fluid; the 2.0 table form crashes. The static check missed it on an untyped
  `record.entity`; annotated now. Added to .claude/rules/factorio-lua.md.

## 2026-11-20: 2.6.5 power budget test
- Measured from the prototypes of every city on the map, at full output with the silo at
  its 4 MW launch peak and engine drain included: demand 17.9 / 49.0 / 94.1 MW at tier
  1 / 2 / 3; the four coal power cities give 21.6 / 43.2 / 86.4 MW; the nuclear city
  20 / 40 / 80 MW.
- The test holds the agreed balance: coal covers tier 1; coal at tier 3 is within 90-115%
  of demand (now 92%); nuclear + one tier 3 coal city covers tier 3; nuclear alone does
  not (so it stays a choice, not a replacement). The player's miners, pumps and inserters
  come on top and are not counted.

## 2026-11-20: 2.6.4 nuclear power city
- Built like the coal power city (assembling machine + linked hidden generator), with a
  burner instead of a coal ingredient: uranium fuel cells go into its fuel slot by
  inserter and burn at 20 / 40 / 80 MW while it turns water into 500 C steam (97 kJ/unit,
  206.2/s per 20 MW, vanilla's heat exchanger figure). The hidden generator
  (tt-nuclear-generator[-tN]) burns that steam at the same rate. A burner only burns while
  crafting, so with no demand the steam backs up and the cell lasts (tested).
- Why not a real reactor + heat exchangers + turbines inside: heat connections, three
  hidden entity types and neighbour bonuses for the same result. Why not a coal-style
  ingredient: one 8 GJ cell would need ~82,000 water per craft and give power in 400 s
  bursts.
- The vanilla fuel cell's burnt result is removed (no depleted cells, user); a burner with
  no burnt slot refuses fuel that has one.
- Window: fuel cells listed as an input ("1 lasts 400 s"); no fuel = starved, naming them.
  Upgrades carry the fuel slot and the cell burning now.
- Upgrade costs (tuning): T2 2000 plates each + 1000 circuits, T3 4000 + 2000.
- Map spot (-40, 170), 100 tiles west of the first lake (it is the thirstiest city).
- Placeholder art: the reactor's picture, scaled. The uranium city and the coal power city
  both use the centrifuge look for now; the recipe icon and map colour tell them apart.

## 2026-11-20: 2.6.3 uranium city
- One recipe: 143 uranium ore + 1 iron plate -> 1 uranium fuel cell in 100 s at speed 1
  (0.01 cells/s), 600 kW, centrifuge graphics. Vanilla ratio without Kovarex; the spare
  U-238 vanishes inside (no output to drain). Tiers x1/x2/x4, upgrade costs as the other
  chain cities (plates, then circuits).
- Map spot (160, 0), between the iron and copper smelting cities. In older saves that spot
  may be under the player's rails; it is then reported and waits like any blocked city.

## 2026-11-20: 2.6.2 uranium patch; hidden techs no longer cut the tree
- Uranium patch at (310, 275), radius 10, ~470k ore (a T1 uranium city uses ~1.4/s).
  Vanilla mining applies: Uranium mining (red, green, blue) turns on mining with fluid, an
  electric mining drill on uranium needs sulfuric acid, and mining it completes Uranium
  processing's trigger (now in the gating test's met list).
- Found: Concrete, and so Uranium mining, was unreachable. Restrictions hide a tech whose
  only unlocks are banned (Advanced material processing: steel furnace; Automation 2:
  assembler 2), which cut every tech behind it. Now a hidden tech's dependents take its
  prerequisites instead (transitively). Planet and platform techs are left as they were.
  Newly reachable besides Concrete: Low density structure (tech), Research speed 1 (speeds
  up the research complex, as vanilla labs), Production science pack (useless: the complex
  takes no purple), Tank and Portable solar panel (their recipes aren't free, so the
  player still can't make anything from them). Rejected: keeping the empty techs
  researchable (research for nothing), unhiding them.

## 2026-11-20: 2.6.1 power city spots and the second lake (mod 0.6.0)
- Three more coal power cities: East (450, 110), West (-460, -120), South (-280, 280). The
  first keeps the label "Power city". Each sits on a different route: the West one has the
  new lake (-330, 90) about 140 tiles away, the East one is far from both lakes and near
  the east iron patch, the South one sits between the two lakes.
- Blocked layout spots are now keyed by surface, name and position (several cities share a
  name); keys from before 0.6.0 are dropped and re-recorded. A lake on an extended map goes
  in only when no player entity stands in its area; otherwise it is reported once and
  retried, like a blocked city.
- No second coal patch: four T3 power cities burn ~19 coal/s and the patch holds ~1.3M,
  over 18 hours. Revisit with procedural maps.
- Test map rule added: cities at least 40 tiles apart and 16 from the map edge.

## 2026-11-20: 2.5.9 playtest, silo pips, power budget (mod 0.5.1)
- The rocket silo city has one tier, so it gets no tier pips (cities need at least 2 tiers
  for pips). Mod 0.5.1 so the every-version migration removes the pip older saves drew.
  The framework test had asserted the single pip; it now asserts none.
- Power budget, measured from city_defs (full output, electric cities only): all 17
  electric cities at T1 need ~13.3 MW (smelting is coal-fired at T1), one T1 power city
  gives 5.4 MW. At T2: ~44 MW against 10.8 MW. At T3: ~88 MW (34.6 MW of it the two
  electric smelting cities) against 21.6 MW. Plus the silo (250 kW crafting, ~4 MW while
  launching) and the player's miners, pumps and inserters. Not decided yet; left to the
  user (more power cities on the map, nuclear, or retuning).
- User decision: both more coal power cities (3 more, 4 in all) and a nuclear option,
  giving the player a choice of challenges. Nuclear is a separate city at 20 / 40 / 80
  MW (half a vanilla reactor at T1, user's choice over 40 / 80 / 160: with no spent
  cells or reprocessing, nuclear is simpler, so it shouldn't also be far stronger). No
  depleted cell output. Natural gating via Uranium mining research. Phase 2.6, ahead of
  elevated rails. Rejected: raising coal power city output (removes the shipping
  problem); lowering city demand (breaks "same power as the vanilla buildings").
- User note: demand has a ceiling (every city at T3), so power is eventually solved as
  long as it stays supplied. Accepted for now; procedural maps with more cities could
  raise it.

## 2026-11-19: 2.5.7-2.5.8 win condition and map (mod 0.5.0)
- The first on_rocket_launched from a silo city wins (victory screen, can continue). The
  goal box leaves the map layout; older saves keep theirs, still counting plates, with a
  description saying it no longer decides the win. The goal panel shows rocket parts.
- Test order: the silo tests run last, since a launch now finishes the game.
- Test map spots: steel (0, 280), plastic (-300, -280), sulfur (40, -280), sulfuric acid
  (140, -280), advanced circuits (280, -120), processing units (300, 100), low density
  structure (-320, -50), blue science (-140, -60), rocket silo (60, 60). All at least 100
  tiles from every patch and the lake. The old goal box spot (272, 0) stays free for older
  saves. Checked on the 2.4.6 playtest save: 22 cities, nothing blocked.

## 2026-11-19: 2.5.6 rocket silo city
- The silo city is a copy of the vanilla rocket silo (it is 9x9 like every city),
  protected, with launches to space platforms off. When a rocket is ready the script calls
  LuaEntity.launch_rocket() (exists in 2.1); on_rocket_launched fires and is counted.
- 2.1 surprise: Space Age changes the rocket part to 1 processing unit + 1 low density
  structure + 1 rocket fuel (50 of each per rocket). User decision: the silo city has its
  own rocket part recipe at the base-game amounts, 10 + 10 + 10 per part, 500 of each per
  rocket. The vanilla recipe stays untouched. Rejected: Space Age's 50 each; a middle
  amount.
- Space Age edits the vanilla silo in data-updates, after our data stage, so the copy sets
  every field that matters itself (parts required, recipe, no platforms, no heating).
- One tier: an upgrade replaces the entity and would lose the rocket parts already built.

## 2026-11-19: 2.5.5 research triggers met by cities
- Space Age's "craft-item" research triggers count crafting by machines: 50 steel from a
  steel city completes Steel axe (test). Oil processing ("mine crude oil") completes from
  a pumpjack (test, 2.4.5). Both former blockers are now met in game, and nothing else
  blocks the red/green/blue part of the tree.
- Test note: an assembling machine only accepts a few crafts' worth of input at once, so
  long-running city tests must top up inputs and drain outputs as they go.

## 2026-11-19: Phase 2.5 scope (user)
- Decision: the first rocket launch wins; the plates goal box leaves new maps (older saves
  keep it, but it no longer decides the win). Fine city split, one product per city
  (steel, plastic, sulfur, sulfuric acid, advanced circuits, processing units, low density
  structure, blue science, rocket silo). Blue science is added and the research complex
  takes it. The rocket silo city works from the start.
- Why: SPEC's thesis names the rocket launch as the win; one product per city makes every
  link a shipping route (SPEC: split at shipping boundaries, 15-25 city types); blue
  science opens more of the tech tree for the player's logistics; gating cities would
  break the 2.2 rule that every city works from the start.
- Rejected: keeping the plates goal as a milestone; a coarse split (chemical and
  electronics super-cities); no blue science; a custom research to switch the silo on.

## 2026-11-19: playtest 2.4.6 follow-ups (mod 0.4.1)
- The first depot is now named "Coal fuel depot" (entity name unchanged, so saves load),
  in line with the solid and rocket fuel depots (user). Existing map tags are renamed on
  load. The user expects to drop the "city" naming later; not scheduled.
- Pipe connections are described by position on the building (bottom left, top right,
  left side middle...), not by tile offsets from the middle (user).
- A city window shows how much of each input the city holds, and when power is the
  problem it also names missing inputs, so a fluid city tells you what it lacks before
  it is powered (user: the refinery window said nothing until powered).

## 2026-11-19: 2.4.1-2.4.5 fuel progression build notes (mod 0.4.0)
- Solid fuel and rocket fuel keep the chemical fuel category and gain tt-locomotive, so
  burner entities still take them. 2.1 surprise: at runtime
  LuaItemPrototype.fuel_categories is an array of names, not a set.
- The refinery city has its pipes fixed: crude oil and water in on the south side, light
  oil and petroleum gas out on the north side, 2 tiles either side of the middle. The fuel
  depots take light oil at the middle of the south side. The city window lists every
  connection.
- Looks (placeholders): refinery city = oil refinery, so the power city moved to the
  centrifuge; solid fuel depot = chemical plant; rocket fuel depot = cryogenic plant.
- Test map: oil field of 6 wells at (-400, -230), 150% yield each (90 crude oil/s with 6
  pumpjacks); refinery city (-160, -250), solid fuel depot (280, -250), rocket fuel depot
  (-400, 220). Older saves get them on load (checked on the 2.3.5 playtest save: 13
  cities, 3 depots with service ports, nothing blocked).
- Oil processing's research trigger (mine crude oil) fires from a pumpjack (test).

## 2026-11-19: Phase 2.4 scope (user)
- Decision: solid fuel and rocket fuel are made by two new depot-type cities (solid fuel
  depot, rocket fuel depot), each with a service port. A refinery city makes light oil and
  petroleum gas from crude oil + water, cracking heavy oil inside. Fuels keep their vanilla
  stats. Oil is gated by the vanilla Oil gathering research (pumpjack).
- Why: keeps the rule that locomotive fuel comes only from depots, and adds service points
  along the fuel chain. Two refinery outputs keep the station work manageable while gas is
  ready for plastics later. Vanilla stats match player expectations.
- Rejected: upgrading the coal depot into solid/rocket fuel (coal fuel would disappear);
  plain fuel cities (would relax the depot rule); vanilla three-output refinery (more
  station work for no gain yet); light-oil-only refinery (gas needed later anyway); bigger
  fuel bonuses.

## 2026-11-19: playtest 2.3.5 follow-ups
- Limp mode (fuel-empty and breakdown) is faster: top speed 25% of normal (was 10%),
  acceleration 60% (was 25%). Why: with wagons attached, a limping train barely moved
  (user). Tuning values.
- Servicing also counts a standing train with a locomotive within 10 tiles of a train stop
  in range, not only trains the engine reports as stopped at it. Why: a manually driven
  train is never "stopped at" a stop, so stopping by hand never serviced it (user).
- Breakdown rate stays for testing; the user wants it slower for real play later.

## 2026-11-19: 2.3.1-2.3.4 reliability build notes (mod 0.3.0)
- Wear and breakdowns run in the existing limp-mode poll (each locomotive about once a
  second); no new on_tick work. A breakdown puts every locomotive of the train on the limp
  fuel, so the train crawls however many locomotives it has (no reliance on how the engine
  combines locomotives' speed multipliers). Broken state is kept by unit number in
  storage.tt_reliability, so refuelling or a limp rescan does not cure it.
- The service port is adopted by the next depot tier instead of being destroyed and
  recreated, so packs and the "trains serviced" count survive upgrades.
- Repair pack recipe corrected to the vanilla 2 circuits + 2 gears (4 iron) per pack; the
  proposal said 1 circuit + 2 iron. 30 packs/min = 1 circuit/s + 2 iron/s, 150 kW.
- Repair pack city uses the foundry's graphics (a look not used by another city yet).
- Checked on the 2.2.8 playtest save: 10 cities, nothing blocked, the depot got its service
  port, no errors.

## 2026-11-19: Phase 2.3 scope (user)
- Decision: reliability = locomotive health; it drains with driving, the vanilla health bar
  shows it and the vanilla repair-pack tool is the manual repair. Servicing = a locomotive
  stopped at any train stop near a depot city, using repair packs from a fixed service port
  beside the depot. Starting decay: ~10 minutes of driving until breakdowns get frequent.
  One locomotive type; per-prototype decay rate for later tiers.
- Why: health reuses engine behaviour (bar, repair tool, no extra GUI). A separate port is
  needed because inserters only insert a crafting machine's recipe ingredients, so the depot
  itself can't take repair packs (user asked; explained). Fuel and servicing stay
  independent.
- Rejected: a separate scripted reliability % (custom GUI and repair action); a dedicated
  service-stop entity (extra placement rule); repair packs in the fuel recipe (fuel stops
  without packs, packs used without servicing); a tier 2 locomotive now.

## 2026-11-19: playtest 2.2.8 follow-ups: map stays small, no inserter changes (user)
- Decision: keep the 960 x 600 test map while the main mechanics are built. A map sized for
  a real train network comes when the user tests the mod as a whole. City throughput,
  footprint and inserter access stay as they are for now.
- Why: short distances keep playtests quick; the inserter bottleneck matches vanilla and
  needs a full run before judging it.
- Rejected for now: a ~3x map before Phase 2.3; longer city edges or slower cities.

## 2026-11-18: 2.2.6 bigger map (960 x 600, mod 0.2.0)
- Decision: the map grows from 640 x 400 to 960 x 600. The MVP cities and patches keep
  their positions (saves). New: circuit city (400, -200), red science city (400, 200),
  green science city (-400, 0), research complex (-160, 230), second iron patch (420, 0).
  Every patch and the lake stay at least 100 tiles from every city (test).
- Existing saves: on configuration change, `map.extend` widens the surface's map gen
  settings, turns out-of-map tiles inside the new bounds into grass, adds missing patches
  and cities and tags them. A city spot taken by player buildings is never cleared: the
  player gets one message with a map link and the spot is retried every second. Verified on
  the latest playtest save: 5 -> 9 cities, nothing blocked, no errors.
- Why: room for real routes between the new cities; no new game needed for a playtest save.
- Rejected: a new surface for existing saves (loses the player's network).

## 2026-11-18: 2.2.5 tier 3 costs use circuits
- Decision: tier 3 costs now include circuits. Smelting T3: 3000 of the other plate + 1000
  circuits (was 6000 plates). Depot and power T3: 2000 iron + 2000 copper + 1000 circuits
  (was 3000 + 3000). Tier 2 costs are unchanged, so the first upgrades need no circuit
  city. Every configuration change refreshes pending upgrades from the definitions, keeping
  deliveries of items still in the cost (so a 2.1 save's T2 city with 4000 of 6000 copper
  is 3000/3000 copper and 0/1000 circuits afterwards; anything over the new amount is lost).
- Why: makes the circuit city part of the upgrade path, not just of science.
- Rejected: refunding overpaid plates (they are already consumed; small and rare).

## 2026-11-18: 2.2.4 research gating
- Found (2.1.24 + Space Age, probed in game): with `automation-science-pack` researched at
  start, the red/green zone is 27 technologies, all reachable with the research complex.
  Useful unlocks: long-handed and fast inserters, fast belts, circuit network, steel chest,
  lamp, toolbelt. Many others unlock things the player can't build or craft (engine units,
  steel plate, turrets, ammo, armour, radar, repair packs, walls, landfill); they stay as
  prerequisites, per the plan. Everything past them needs blue (or other) packs, which
  the complex doesn't take: visible and locked.
- Two trigger technologies inside the zone wait for later content and stay vanilla: `steel-axe`
  (craft 50 steel plates; needs a steel city) and `oil-processing` (mine crude oil; the map
  has no oil yet). Tests list them, so a new blocker shows up as a failure.
- Why: vanilla tree, no prototype changes needed beyond the start technology.
- Rejected: rewriting trigger techs into pack costs (not needed in this scope); hiding the
  military branch (enemies are off, but it is vanilla and harmless; can revisit).

## 2026-11-18: 2.2.3 research complex
- Decision: the research complex is a `lab` prototype built from the city definition
  (`kind = "lab"`), protected like every city, taking red and green packs. Tiers: research
  speed 20/40/80 (= labs), 1.2/2.4/4.8 MW (60 kW per lab). T2 costs 1000 iron + 1000
  copper + 500 circuits, T3 3000 + 3000 + 2000 circuits. Its window shows the status (no
  research selected, waiting for packs, can't research a tech that needs packs it doesn't
  take), the current research, the packs inside and the speed. Upgrades keep the packs.
- Found: in Space Age the whole tree hangs off the `automation-science-pack` technology,
  whose research trigger is crafting a lab. The player can never craft one here, so no
  research was possible. It is now a start technology (the complex replaces the lab), and
  start technologies are re-applied on every configuration change so existing saves get it.
  Other trigger technologies are handled in 2.2.4.
- Why: vanilla lab behaviour (research speed bonuses, pack drain, queue) with no script.
- Rejected: scripted research (user decision).

## 2026-11-18: 2.2.2 circuit, red science and green science cities
- Decision: three electric cities. Tier 1 rates and power equal the vanilla assembling
  machine 2s (speed 0.75, 150 kW) that would make the same output, including the gears and
  cables made inside:
  - circuits: 300/min from 5 iron/s + 7.5 copper/s, 1.25 MW (batch 2 iron + 3 copper -> 2)
  - red science: 60/min from 2 iron/s + 1 copper/s, 1.1 MW
  - green science: 60/min from 4.5 iron/s + 1 circuit/s, 1.5 MW (the plan table said 5.5
    iron; one belt craft makes two belts, so it is 4.5)
  - tiers x1/x2/x4; T2 costs 1000 iron + 1000 copper; T3 costs 3000 + 3000 for circuits and
    2000 + 2000 + 1000 circuits for both science cities (never the city's own product)
  - placeholder sprites: electromagnetic plant, assembling machine 1 and 2
- Why: SPEC power rule; small batches keep the buffer inside a city small.
- Rejected: 10-circuit batches (25 plates per craft; a slow start for a fresh station).

## 2026-11-18: 2.2.1 city framework
- Decision: city behaviour comes only from `shared/city_defs.lua`. Removed the two
  per-city checks: "uses coal" now reads `def.fuel` (an ingredient burnt as fuel), and the
  power-idle status uses `city_defs.is_power` (any tier with a generator). The second was a
  real bug: an idle tier 2/3 power city said "output full". A framework test walks every
  tier of every definition (window, pips, port, costs), and a locale test translates the
  name of every `tt-` prototype through `request_translation` (proved to catch a removed
  key).
- Why: the new cities in 2.2.2-2.2.3 should need data and locale only.
- Rejected: a static locale check in check.ps1 (prototype names are generated in the data
  stage, so a static scan can't list them).

## 2026-11-18: Phase 2.2 scope (user decisions)
- Decision: Phase 2.2 covers red and green science: circuit, red science and green science
  cities plus a research complex. The complex is a fixed lab prototype, so the engine runs
  research. Research gates player items and bonuses only; every city works from the start.
  The plates goal stays the win condition.
- Why: smallest slice that makes research a real shipping chain; vanilla lab behaviour needs
  almost no script.
- Rejected: blue science and oil now (doubles the phase; belongs with the rocket chain);
  scripted research; research-gated city tiers or dormant cities; a research win condition.

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
