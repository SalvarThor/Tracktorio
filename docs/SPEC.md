# Tracktorio: Design Spec

## Thesis

Factorio with the factory turned into black boxes. Cities are factories that convert inputs to outputs automatically at the rate they're supplied. The player builds them, for free once researched, but only on plots the map provides. Each city runs at half the rate of its vanilla equivalent; iron and copper smelting (15 plates/s) and power cities (20 MW coal, 100 MW nuclear) are the exceptions. The player mines raw resources, builds the cities, the train network and the stations that feed and drain them. The win condition is a rocket launch. The challenge is shipping, not production design.

Cities chain across the map the same way a factory does, and the train network is the belts. When a supply runs short, the answer is another city on another plot, and more rail.

## Rules

- **Transformation belongs to cities only.** Furnaces, assemblers, refineries, chemical plants, boilers and steam engines are removed from the player.
- **Transportation means trains, and only trains.** Cars, tanks, spidertrons, roboports and logistic robots are removed. Personal construction robots are allowed: building is free, so building fast is fine, and they never move cargo between places. Every player starts with power armor holding a fission reactor, two personal roboports and two batteries, and 20 construction robots; more robots are a free hand-craft. (User decision 2026-11-21.) Belts, pipes and inserters are station-local logistics for loading, unloading and feeding cities (through their belt ports), not the intended way to move cargo between locations.
  - Decided: no rule against long belt or pipe runs between locations. A player who wants miles of belts can build them; trains are simply the better tool.
- **Cities are free**, gated by research, and can only be built on plots (see Plots).
- **Train infrastructure, station logistics and extraction are free**, gated by research. That covers rails, signals, stops, trains, inserters, belts, chests (not logistic chests), pipes, pumps, tanks, poles, circuit entities, miners, pumpjacks and radars (user decision 2026-11-22; every city also has a built-in radar that keeps its surroundings live on the map). Items of these kinds from other mods are free too (user decision 2026-11-22). Default: extraction counts as free, since sourcing and mining ores is the player's job. Offshore pumps are removed: water comes only from water cities (post-MVP item 9).
- **Everything else stays vanilla.** Trains, fuel, signals, schedules, interrupts, loading and unloading, circuits, ore patches.
- Space Age is required for elevated rails, which come as late research. Quality, planets and platforms are off.

## Black boxes

All black boxes are the same entity concept with different recipe profiles.

- **Production cities** at middle-ground granularity: smelting, intermediates, science and rocket parts. Cities split at natural shipping boundaries, roughly 15-25 city types for a full rocket tree.
- **Power city:** water + coal in, electricity out to the player's pole network. Several
  can be built. Later: a separate nuclear power city (fuel cells + water in), fed by a
  uranium city (uranium ore + iron in, fuel cells out). (User decision, 2026-11-20.)
- **Depot city:** coal in, coal fuel (`tt-coal-fuel`) out. The only source of locomotive fuel.
- **Research complex:** science packs in, research progress out. More complexes, more research speed.

Shared behaviour:

- Conversion runs at the rate of the slowest input, capped by the city's rate. Rates are modest (half the vanilla equivalent): the way to more output is more cities. (User decision 2026-11-21, phase 2.15.) Iron and copper smelting are not halved: 15 plates/s, one yellow belt. (User decision 2026-11-22, playtest 2.15.10.) Power cities are not halved: a coal power city makes 20 MW on one water city's water, a nuclear power city 100 MW. (User decision 2026-11-22, playtest 2.15.10.)
- A city fed (or drained) below its full rate runs steadily at that rate rather than in bursts: its speed and power draw drop together, down to 20%. (User decision 2026-11-21, phase 2.12.)
- Decided: a city draws electricity from the player's pole network when its vanilla
  equivalent uses electric buildings. It draws what those buildings would need for the same
  output, runs slower on low power and stops without it. Cities whose equivalent burns fuel
  (the coal-fired smelting cities) take that fuel as an ingredient instead. Electric
  smelting is a separate, later-researched city kind that runs on electricity instead
  of coal; the upgrade planner swaps one for the other in place (phase 2.15). MVP: the depot counts as
  chemical plants (840 kW at full output); smelting cities and the goal box need no power.
  (User decision, playtest 1.10.)
- A full output stalls the box and an empty input starves it, so backpressure works like a backed-up belt.
- Black boxes accept and give items only through belt ports in their walls, and fluids only through pipes: a belt runs straight into a port, as in Factorissimo. Inserters can't reach a city, and the player cannot hand-feed a city or take its output by hand. Each port is clearly marked with its item and direction. (User decision 2026-11-20, phase 2.10; before that, inserters and pumps.)
- Every city is a 12x12 building (the rocket silo keeps the vanilla 9x9), one port per item, all facing the same way: cities can't be rotated. (User decisions 2026-11-21, phase 2.15; before that cities grew 8x8 / 12x12 / 16x16 with tier upgrades delivered as construction materials.)
- A city can be removed; everything inside it is lost (it can't go into the player's inventory: cities are hands-off).
- Every city has a signal point in its door for the circuit network: it sends what the city holds, its status and speed. It only sends; train limits, interrupts and combinators are the player's. (User decision 2026-11-21, phase 2.11; the second point, for tier upgrade needs, went with the upgrades in 2.15.)

## Plots

(User decisions 2026-11-21, phase 2.15.)

- Map generation paints plots: 12x12 building spots with a marked border, visible on the map. A city can only be built on a plot, and any city fits any plot. Plots can't be mined or covered with other tiles.
- One plot per site, at least 300 tiles between sites, so belting between cities is clearly worse than rail. About 75 plots on a map: using them all takes a vast train network, and that is the challenge. A starter site of 2 plots stands near spawn. (User decision 2026-11-21, playtest 2.15.10; before that, sites of 1-3 and a starter of 4, which let neighbouring cities trade by short belts.)
- Each site has a map tag.
- Rejected: buildings already on the map, unassigned, that the player gives a role once (no blueprints, and a wrong pick can't be undone).

## Locomotives

- Locomotive tiers: the vanilla locomotive, Mk2 and Mk3, free and unlocked by research. Each tier has more power, a higher top speed and better fuel use. (User decision 2026-11-21, phase 2.11.)
- No reliability or breakdowns. (User decision 2026-11-22, playtest 2.15.10: built in phase 2.3, then removed with the depot service bay and the repair pack city. A breakdown was an event the train schedule could not see, and placing a new locomotive by hand was an easier cure than a repair pack supply line. Could come back later as a schedulable mechanic.)
- Limp mode stays for fuel-empty trains (see MVP).

## Black box visuals: Factorissimo

Decided (user, 2026-11-20, phase 2.10): cities use the Factorissimo 3 building art, copied into the mod under its MIT license (checked in the 3.11.19 package; no separate license for the art) with the license notice beside it. No mod dependency and no Factorissimo code: a dependency would load the whole mod (enterable factories, extra surfaces, recipes and tech). The rocket silo keeps the vanilla silo.

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
- Starting research unlocks basic rails, signals, stops, locomotive, cargo and fluid wagons, inserters, belts, miners, poles, pumps and offshore pumps. (Offshore pumps were removed later by the water city, post-MVP item 9.)
- Out of MVP scope: research complex, reliability, tiers and city upgrades.

## Post-MVP order

Default order, open to change:

1. City tier upgrades.
2. Intermediate cities and the research complex, with research gating.
3. Reliability, depots and the repair pack city. (Built, then removed in playtest 2.15.10.)
4. Fuel progression cities (solid fuel, rocket fuel).
5. Full chain to a rocket silo box.
6. More power cities and the nuclear power city (moved ahead of elevated rails, user
   decision 2026-11-20).
7. Elevated rails.
8. Procedural map generation. Played as its own game: New Game -> Mod scenarios ->
   Tracktorio, on Nauvis terrain with cities far apart. (User decisions 2026-11-20; detail
   in DECISIONS.md.)
9. Water city: water comes only from water cities and must be shipped (by fluid wagon) to
   where it is used, such as the power city. Offshore pumps are removed from the player.
   (User request, playtest 1.10.)
10. Factorissimo buildings and belt ports: the art, cities growing with tier, belt ports
    instead of inserters. (User decisions 2026-11-20.)
11. City signals and locomotive tiers. (User decisions 2026-11-21.)
12. Steady production and the coal fuel icon. (User decisions 2026-11-21.)
13. Player-built cities on plots; tier growth removed. (User decisions 2026-11-21.)
14. A recorded full run to the rocket, for tuning.
