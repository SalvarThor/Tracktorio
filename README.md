# Tracktorio

A Factorio 2.1 mod (with Space Age) where **trains are the whole game**.

All production happens in fixed-location "black box" cities that turn inputs into outputs
on their own. You don't build furnaces or assemblers. You mine raw resources, lay the rail
network, and design the stations that feed and drain the cities. Cities chain across the
map the way a factory does, and the train network is the belts. The challenge is
shipping, not production design. You win by launching a rocket.

> Status: in development. Post-MVP phases 2.1 to 2.11 (procedural maps, water city, Factorissimo buildings, city signals) are
> built and playtested. Not on the mod portal yet.

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
- **Cities are hands-off.** Items go in and out only through belt ports in their walls,
  and fluids through pipes; inserters can't reach a city. The player places nothing by
  hand.
- **Locomotive fuel comes only from depots.** Vanilla coal doesn't fuel a locomotive.
- **Everything else is vanilla:** signals, schedules, interrupts, circuits, ore patches,
  the tech tree.

The full design is in [docs/SPEC.md](docs/SPEC.md).

## What's in the game now

**25 city types**, each at a fixed place on the map (30 cities: four coal power cities and four water cities):

| Group | Cities |
|---|---|
| Smelting | iron, copper, steel |
| Water | four water cities on lake shores (no inputs, 600/1,200/2,400 water/s); the only water source, since offshore pumps are removed |
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
- **Buildings and ports:** cities are Factorissimo buildings. Run a belt straight into a
  port in the wall; each port shows its item and an in or out arrow. One yellow belt per
  item is enough at tier 1, red at tier 2, blue at tier 3 (tier 3 smelting has two ports
  per item).
- **Tiers:** most cities have 3 tiers (x1, x2, x4). Upgrade a city by belting materials
  into its **construction port** (marked with a steel chest). You get a heads-up message at 90%,
  then the city upgrades in place and grows: 8x8, 12x12, 16x16. The dashed outline shows
  how big it gets; whatever you built inside it comes back to you, and belts into the
  ports still reach them. Pips on the city show its tier.
- **Windows:** click a city or a port to see its recipe and rates, what it holds and
  what it's missing, its ports and the belt each needs, and what the next tier costs.
- **Steady production:** a city fed below its full rate (or whose output is taken away
  slower) runs steadily at that rate, down to 20%, using less power to match. Its window
  says "Running at 60%".
- **Signals:** wire the two combinators in a city's door. The left one sends what the
  city holds, whether it is running, starved, output full or without power, its speed
  in percent and its tier (T); the right one what its next tier still needs. Use them for train limits,
  interrupts or construction trains.

**Trains**
- **Limp mode:** a locomotive that runs out of fuel crawls instead of stopping dead.
- **Reliability:** a locomotive's health is its reliability. It wears down as the train
  drives, and the lower it gets, the more likely the train breaks down.
- **Breakdowns:** a broken-down train crawls until it's back at full health.
- **Repair:** repair a locomotive by hand with repair packs, or stop it at any train
  stop within 30 tiles of a depot. Depots repair it using packs delivered to their
  **service port**.
- **Locomotive Mk2 and Mk3:** researched with green and then blue science. More power,
  a higher top speed and better fuel use, and they wear out slower (5% and 3% per minute
  of driving, against 7.5%).
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

**Map:** a new Nauvis map each game with vanilla terrain and ore. Cities later in the chain
tend to stand further out. A depot, a water city and a power city stand near spawn, close
enough to pipe water from one to the other. The hand-made test map is kept for the tests.

## How it was built

The mod is built item by item from [docs/PLAN.md](docs/PLAN.md). Every item has automated
in-game tests (252 at the moment). Every phase ends with a playtest round, and its
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
| 2.7 | Elevated rails as late research |
| 2.8 | Procedural maps: Tracktorio as its own scenario on Nauvis, cities laid out by chain depth with varied spacing, biters off, cities tagged on the map |
| 2.9 | Water city: water only from water cities on lake shores, offshore pumps removed, a starter pair near spawn; a water budget test |
| 2.10 | Factorissimo buildings that grow with each tier (8x8, 12x12, 16x16), belt ports in their walls instead of inserters (construction and repair packs too), roof icons, even output lanes |
| 2.11 | City signals (stock, status, tier, construction needs) for the circuit network; locomotive Mk2 and Mk3 |

## Next steps

Open ideas:
- Tune breakdowns to be rarer for real play.
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

## Credits

The city buildings are the Factorissimo 3 factory buildings by MagmaMcFry and notnotmelon,
used under the MIT license (see [mod/graphics/factorissimo/](mod/graphics/factorissimo/)).
Only the images are used, not Factorissimo's code.
