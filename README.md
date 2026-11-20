# Tracktorio

A Factorio 2.1 mod (with Space Age) where **trains are the whole game**.

All production happens in fixed-location "black box" cities that turn inputs into outputs
on their own. You don't build furnaces or assemblers. You mine raw resources, lay the rail
network, and design the stations that feed and drain the cities. Cities chain across the
map the way a factory does, and the train network is the belts. The challenge is
shipping, not production design. You win by launching a rocket.

> Status: in development. Post-MVP phases 2.1 to 2.8 (procedural maps) are built and
> playtested. Next: the water city. Not on the mod portal yet.

## How to play

Enable the mod, then New Game -> Mod scenarios -> **Tracktorio**. You get the usual map
settings (seed, preview, resources). The cities are laid out across a new Nauvis map
each game, far apart, and all of them are marked on the map from the start. Biters are
always off. The "City spacing" startup setting (Settings -> Mod settings -> Startup)
scales the distance between cities.

Starting Freeplay with the mod on gives the same game, with a note saying so.

## The rules

- **Only cities transform.** The player gets no furnaces, assemblers, refineries,
  chemical plants, labs, boilers, steam engines or solar.
- **Only trains transport.** No cars, tanks, spidertrons or robots. Belts, pipes and
  inserters are for station logistics.
- **Logistics are free.** Rails, signals, stops, trains, inserters, belts, chests, pipes,
  pumps, poles, circuit entities, miners and pumpjacks cost nothing to craft. Research
  still unlocks them.
- **Cities are hands-off.** Items go in and out only through inserters and pumps. The
  player places nothing by hand.
- **Locomotive fuel comes only from depots.** Vanilla coal doesn't fuel a locomotive.
- **Everything else is vanilla:** signals, schedules, interrupts, circuits, ore patches,
  the tech tree.

The full design is in [docs/SPEC.md](docs/SPEC.md).

## What's in the game now

**24 city types**, each at a fixed place on the map (26 cities: four coal power cities):

| Group | Cities |
|---|---|
| Smelting | iron, copper, steel |
| Power | four coal power cities (coal + water in, electricity out to your poles); a nuclear power city (uranium fuel cells + water in, 20/40/80 MW, burns flat out like a real reactor); a uranium city (uranium ore + iron in, fuel cells out) |
| Fuel depots | coal fuel, solid fuel, rocket fuel |
| Oil and chemistry | refinery (crude oil + water in, light oil + petroleum gas out), plastic, sulfur, sulfuric acid |
| Intermediates | electronic circuits, advanced circuits, processing units, low density structure, repair packs |
| Science | red, green and blue science cities, and a research complex that works like a block of labs |
| Endgame | rocket silo |

**Cities**
- Each city runs at the rate of its slowest input and stops when its output is full.
- Electric cities draw what the equivalent vanilla buildings would. They slow down on low
  power and stop without it.
- **Tiers:** most cities have 3 tiers (x1, x2, x4). Upgrade a city by delivering
  materials to its **construction port**. You get a heads-up message at 90%, then the
  city upgrades in place. Pips on the city show its tier.
- **Windows:** click a city to see its recipe and rates, what it holds and what it's
  missing, where its pipes connect, and what the next tier costs.

**Trains**
- **Limp mode:** a locomotive that runs out of fuel crawls instead of stopping dead.
- **Reliability:** a locomotive's health is its reliability. It wears down as the train
  drives, and the lower it gets, the more likely the train breaks down.
- **Breakdowns:** a broken-down train crawls until it's back at full health.
- **Repair:** repair a locomotive by hand with repair packs, or stop it at any train
  stop within 30 tiles of a depot. Depots repair it using packs delivered to their
  **service port**.
- **Better fuels:** solid fuel and rocket fuel give trains more acceleration and top speed
  (vanilla values).

**Research**
- Feed the research complex red, green and blue packs. The red/green/blue part of the
  tech tree can be researched in full.
- Research unlocks only the player's logistics items and bonuses. Every city works from
  the start.

**Winning**
- Feed the rocket silo city 500 processing units, 500 low density structures and 500
  rocket fuel. It builds 50 rocket parts and launches on its own.
- The first launch wins.

**Map:** a hand-made 960x600 test map with all cities, ore and coal patches, a lake and an
oil field. Older saves are upgraded in place when the mod updates.

## How it was built

The mod is built item by item from [docs/PLAN.md](docs/PLAN.md). Every item has automated
in-game tests (168 at the moment). Every phase ends with a playtest round, and its
findings go back into the plan. Decisions, and the reasons behind them, are logged in
[docs/DECISIONS.md](docs/DECISIONS.md).

| Phase | What it added |
|---|---|
| 0 | Toolchain: separate dev instance, LuaLS static check, in-game test runner (Factorio 2.1's native test mode) |
| 1 (MVP) | Black box cities, free logistics, restrictions, power and depot cities, limp mode, map, city UI. The MVP win was delivering plates to a goal box. |
| 2.1 | City tiers, construction ports, upgrade messages, tier pips |
| 2.2 | Circuit and science cities, research complex, research gating, bigger map |
| 2.3 | Reliability, breakdowns, depot servicing, repair pack city |
| 2.4 | Oil: refinery, solid and rocket fuel depots, fluid cities, oil field |
| 2.5 | Full chain to the rocket: steel, plastic, sulfur, acid, advanced circuits, processing units, low density structure, blue science, rocket silo; the launch wins |
| 2.6 | Power expansion: three more coal power cities, a second lake, uranium mining with acid, a uranium city, a nuclear power city; a power budget test |

## Next steps

1. **Water city:** water would come only from water cities and be shipped by fluid wagon.
   Offshore pumps would be removed.

Open ideas that aren't scheduled yet:
- Tune breakdowns to be rarer for real play.
- Revisit inserter throughput, which is often the bottleneck at stations.
- Real art instead of the scaled vanilla stand-ins (Factorissimo, once its license is
  confirmed).
- Maybe drop the "city" naming.
- Nuclear fuel control: the nuclear power city puts out a circuit signal (its steam level)
  so players can wire the fuel inserter to save fuel, as in vanilla nuclear setups.

## Development

Windows, PowerShell, Factorio 2.1 with Space Age. Machine paths are in
[docs/ENV.md](docs/ENV.md). Every script uses its own dev instance in `.factorio\` or
`.factorio-play\`, never your real Factorio folder.

```powershell
./tools/check.ps1        # static check (LuaLS with Factorio 2.1 types)
./tools/run-tests.ps1    # in-game tests; -Filter <text> for a subset
./tools/playtest.ps1     # launch the game with the scenario (-Menu: at the main menu)
```

Debug commands for playtests:
- `/tt-dump`: snapshot of the mod's state to `script-output`.
- `/tt-port-fill <percent>`: fill a city's upgrade progress.
- `/tt-reliability [percent]`: show or set a locomotive's reliability.
- `/tt-silo-fill <parts>`: set the rocket parts in a silo.
- `/tt-goal`: show the goal status.

Layout:

```
mod/        the mod (prototypes, scripts, locale, scenario)
tests/      test mod tracktorio-tests: runner and test cases
tools/      PowerShell scripts (dev instance, check, tests, playtest)
docs/       SPEC, PLAN, DECISIONS, ENV
```
