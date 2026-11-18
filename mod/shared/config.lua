-- Game rules shared by the data and control stages. Plain data only.
local M = {}

-- Recipe category of the free logistics recipes; the only category the character can craft.
M.FREE_CATEGORY = "tt-free"
-- Craft time of free recipes. The engine requires > 0.001 s; this crafts ~1 item per tick.
M.FREE_CRAFT_TIME = 0.002

-- The only fuel category locomotives burn. tt-coal-fuel (depot cities) is in it.
M.LOCOMOTIVE_FUEL_CATEGORY = "tt-locomotive"

-- Limp mode: hidden reserve fuel burned by fuel-empty locomotives (DECISIONS.md A3, 1.7).
M.LIMP_FUEL = "tt-limp-fuel"
M.LIMP_FUEL_VALUE = "100GJ"         -- effectively never runs out; re-applied if it does
M.LIMP_FUEL_JOULES = 100e9
M.LIMP_TOP_SPEED = 0.10             -- x locomotive max speed (1.2 -> 0.12 tiles/tick, ~26 km/h)
M.LIMP_ACCELERATION = 0.25
-- Every LIMP_INTERVAL ticks a slice of locomotives is checked so each one is seen about
-- once per LIMP_PASS_TICKS.
M.LIMP_INTERVAL = 10
M.LIMP_PASS_TICKS = 60

-- City entity names (prototypes/cities.lua).
M.CITY = {
  iron = "tt-city-iron-smelting",
  copper = "tt-city-copper-smelting",
  depot = "tt-city-depot",
  power = "tt-city-power",
  goal = "tt-city-goal",
}

-- Goal box: slots 1..GOAL_SLOTS/2 take iron plates, the rest copper plates.
M.GOAL_SLOTS = 40
M.GOAL_ITEMS = { iron = "iron-plate", copper = "copper-plate" }
-- Filter used for a metal whose target is met: the goal box stops accepting it.
M.GOAL_CLOSED_ITEM = "tt-goal-closed"
-- How often the goal box is emptied and counted, and the rate window (for the UI).
M.GOAL_TICK_INTERVAL = 60
M.RATE_WINDOW_TICKS = 60 * 60

-- Hidden companion entities placed with a city and joined by a linked fluidbox connection.
-- city name -> { entity, city_link_id, companion_link_id }
M.CITY_COMPANIONS = {
  ["tt-city-power"] = { entity = "tt-power-generator", city_link_id = 1, companion_link_id = 1 },
}

-- Free items (SPEC: train infrastructure, station logistics, extraction). Their recipes get
-- no ingredients and stay gated by their vanilla technology.
M.FREE_ITEMS = {
  -- rails and trains
  "rail", "rail-signal", "rail-chain-signal", "train-stop",
  "locomotive", "cargo-wagon", "fluid-wagon",
  "rail-ramp", "rail-support",
  -- inserters
  "burner-inserter", "inserter", "long-handed-inserter", "fast-inserter", "bulk-inserter", "stack-inserter",
  -- belts
  "transport-belt", "underground-belt", "splitter",
  "fast-transport-belt", "fast-underground-belt", "fast-splitter",
  "express-transport-belt", "express-underground-belt", "express-splitter",
  "turbo-transport-belt", "turbo-underground-belt", "turbo-splitter",
  -- chests (not logistic)
  "wooden-chest", "iron-chest", "steel-chest",
  -- fluids
  "pipe", "pipe-to-ground", "pump", "storage-tank", "offshore-pump",
  -- power distribution
  "small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation",
  -- circuit entities
  "arithmetic-combinator", "decider-combinator", "constant-combinator", "selector-combinator",
  "power-switch", "programmable-speaker", "display-panel", "small-lamp",
  -- extraction
  "burner-mining-drill", "electric-mining-drill", "big-mining-drill", "pumpjack",
}

-- Items the player must never get (SPEC: transformation happens in cities; transport is
-- trains only; no robots; no planets/platforms). Their recipes are hidden and disabled, and
-- technologies stop unlocking them.
M.BANNED_ITEMS = {
  -- transformation
  "stone-furnace", "steel-furnace", "electric-furnace",
  "assembling-machine-1", "assembling-machine-2", "assembling-machine-3",
  "oil-refinery", "chemical-plant", "centrifuge",
  "foundry", "electromagnetic-plant", "biochamber", "cryogenic-plant", "recycler", "crusher",
  "agricultural-tower", "captive-biter-spawner", "lab", "biolab", "rocket-silo", "beacon",
  -- power generation
  "boiler", "steam-engine", "steam-turbine", "solar-panel", "nuclear-reactor",
  "heat-exchanger", "heat-pipe", "heating-tower", "fusion-reactor", "fusion-generator",
  "lightning-collector", "lightning-rod",
  -- vehicles
  "car", "tank", "spidertron",
  -- robots
  "construction-robot", "logistic-robot", "roboport",
  "personal-roboport-equipment", "personal-roboport-mk2-equipment",
  "active-provider-chest", "passive-provider-chest", "storage-chest", "buffer-chest", "requester-chest",
  -- space
  "asteroid-collector", "thruster", "cargo-bay", "cargo-landing-pad", "space-platform-starter-pack",
}

-- Technologies hidden outright (planets and platforms are off).
M.HIDDEN_TECH_PATTERNS = { "^planet%-discovery%-", "^space%-platform", "^rocket%-silo$" }

-- Researched for the player force at game start (SPEC MVP starting research).
M.START_TECHNOLOGIES = {
  "railway",                        -- rail, locomotive, cargo wagon
  "automated-rail-transportation",  -- train stop, rail and chain signals
  "fluid-wagon",
  "electronics",                    -- inserter, small electric pole
  "logistics",                      -- underground belt, splitter
  "electric-mining-drill",
  "steam-power",                    -- pipe, pipe-to-ground, offshore pump (boiler/engine stripped)
  "fluid-handling",                 -- pump, storage tank
  "electric-energy-distribution-1", -- medium and big electric pole
}

local function set(list) local s = {} for _, v in ipairs(list) do s[v] = true end return s end
M.FREE_SET = set(M.FREE_ITEMS)
M.BANNED_SET = set(M.BANNED_ITEMS)

return M
