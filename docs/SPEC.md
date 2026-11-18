# Train Tycoon: Design Spec

## Thesis

Factorio with the factory turned into black boxes. Cities are fixed-location factories that convert inputs to outputs automatically at the rate they're supplied. The player mines raw resources, builds the train network and designs the stations that feed and drain the cities. The win condition is a rocket launch. The challenge is shipping, not production design.

Cities chain across the map the same way a factory does, and the train network is the belts.

## Rules

- **Transformation belongs to cities only.** Furnaces, assemblers, refineries, chemical plants, boilers and steam engines are removed from the player.
- **Transportation means trains, and only trains.** Cars, tanks, spidertrons and logistic and construction robots are removed. Belts, pipes and inserters are station-local logistics for loading, unloading and feeding cities, not the intended way to move cargo between locations.
  - Decided: no rule against long belt or pipe runs between locations. A player who wants miles of belts can build them; trains are simply the better tool.
- **Train infrastructure, station logistics and extraction are free**, gated by research. That covers rails, signals, stops, trains, inserters, belts, chests (not logistic chests), pipes, pumps, tanks, poles, circuit entities, miners, pumpjacks and offshore pumps. Default: extraction counts as free, since sourcing and mining ores is the player's job.
- **Everything else stays vanilla.** Trains, fuel, signals, schedules, interrupts, loading and unloading, circuits, ore patches.
- Space Age is required for elevated rails, which come as late research. Quality, planets and platforms are off.

## Black boxes

All black boxes are the same entity concept with different recipe profiles.

- **Production cities** at middle-ground granularity: smelting, intermediates, science and rocket parts. Cities split at natural shipping boundaries, roughly 15-25 city types for a full rocket tree.
- **Power city:** water + coal in, electricity out to the player's pole network. Upgrades to nuclear later.
- **Depot city:** coal in, coal fuel (`tt-coal-fuel`) out. The only source of locomotive fuel. Fixed location like every other box.
- **Research complex:** science packs in, research progress out. Upgradable throughput.
- **Repair pack city:** feeds depot servicing.

Shared behaviour:

- Conversion runs at the rate of the slowest input, capped by tier.
- A full output stalls the box and an empty input starves it, so backpressure works like a backed-up belt.
- Tier upgrades happen by delivering construction materials to the box.
- Placement is fixed by the world, never by the player, so every link in the chain is a real route.
- Black boxes accept and give items only through inserters and pumps, never by hand. The player cannot hand-feed a city or take its output by hand.

## Reliability and depots

- Each locomotive has a reliability % that decays with use. Newer tiers decay more slowly.
- Low reliability means a higher chance of random breakdowns.
- A broken-down train goes into limp mode: it keeps running at reduced speed and slows everything behind it. It stays that way until cured. (Limp mode itself ships in MVP for fuel-empty trains; see MVP.)
- The only cures are a depot visit (service bay) or a manual repair by the engineer on site using repair packs.
- A service bay at a depot restores reliability and consumes repair packs, so depots need a repair pack supply line as well as fuel.

## Black box visuals: Factorissimo

Factorissimo buildings fit visually, with two caveats:

- The license for the Factorissimo 2 (notnotmelon fork) graphics is unconfirmed. Before copying any of its sprites, check the license on its GitHub or mod portal page.
- Declaring it as a dependency instead loads the whole mod: enterable factories, extra surfaces, recipes and tech. All of those would have to be hidden.

Decided: no other mod is involved yet. The MVP uses a scaled vanilla sprite as a placeholder. Factorissimo art is evaluated once the license is confirmed.

## Free buildings: implementation

Default: override logistics recipes to have no ingredients and craft instantly, unlocked by vanilla tech. That uses the normal research gating with almost no custom code.

- Open question: empty ingredient lists in 2.1 recipe prototypes are likely allowed but unverified. Check this first.
- Fallback: a free-item GUI that hands out researched logistics items.

## UI (MVP)

Clicking or hovering a black box shows:

- Its recipe: inputs, outputs and ratios.
- Current output rate per minute.
- Status: running, starved (naming the missing input) or output full.

## MVP

The MVP wins when the player delivers a cumulative total of X iron plates and Y copper plates shipped by train from both smelting cities to a single goal box. A total can't be faked by buffering in chests; a faster network simply wins sooner. Placeholder: 20,000 each, exposed as a scenario setting for tuning during playtesting.

- Small handcrafted scenario map. Space Age is enabled, but planets, quality and elevated rails are not used yet.
- Iron and copper ore patches, a coal patch and water, each placed far from the cities.
- One iron smelting city (iron ore + coal in, iron plates out) and one copper smelting city.
- One power city (water + coal in, electricity out). Miners and inserters run off its power through the player's pole network.
- Trains run on coal fuel, which only the depot city makes, from coal the player mines. Vanilla coal is not a locomotive fuel, so a train can't be fed straight from a coal patch.
- Depots are fixed depot cities; the scenario guarantees one near the start. No fueling rule is enforced: only depot cities make fuel, so all fuel comes from a depot. Hand-fueling is allowed; it can't scale to a large network but helps at the start. Players may haul coal fuel by train to refuel stops they build anywhere: the depot city is the fuel source, not the only fueling point.
- Limp mode in MVP applies to fuel-empty trains: a train with no fuel crawls instead of stopping dead. Getting it crawling to a depot is the player's job.
- Fallback if limp mode proves complex: vanilla behaviour. An empty train stops dead until someone hand-fuels it.
- Starting research unlocks basic rails, signals, stops, locomotive, cargo and fluid wagons, inserters, belts, miners, poles, pumps and offshore pumps.
- Out of MVP scope: research complex, reliability, tiers and city upgrades.

## Post-MVP order

Default order, open to change:

1. City tier upgrades.
2. Intermediate cities and the research complex, with research gating.
3. Reliability, depots and the repair pack city.
4. Fuel progression cities (solid fuel, rocket fuel).
5. Full chain to a rocket silo box.
6. Elevated rails.
7. Nuclear power city.
8. Procedural map generation.
9. Water city: water comes only from water cities and must be shipped (by fluid wagon) to
   where it is used, such as the power city. Offshore pumps are removed from the player.
   (User request, playtest 1.10.)
