-- Locomotive tiers (PLAN 2.11.5). The vanilla locomotive is tier 1; tiers 2 and 3 are
-- copies with more power, a higher top speed, better fuel use and (scripts/reliability.lua,
-- config.RELIABILITY_DECAY_PER_MINUTE) slower wear. Free like every train entity
-- (restrictions.lua makes their recipes free, config.FREE_ITEMS), unlocked by research.
-- Look: the vanilla locomotive in another default colour, its icon with the tier number.
local config = require("shared.config")
local util = require("util")

local function icons(tier)
  return {
    { icon = "__base__/graphics/icons/locomotive.png" },
    { icon = "__base__/graphics/icons/signal/signal_" .. tier .. ".png", scale = 0.25, shift = { 9, -9 }, floating = true },
  }
end

for tier, t in pairs(config.LOCOMOTIVE_TIERS) do
  local name = config.LOCOMOTIVE_TIER_NAME[tier]
  local entity = table.deepcopy(data.raw.locomotive["locomotive"])
  entity.name = name
  entity.icon, entity.icons = nil, icons(tier)
  entity.minable = { mining_time = 0.5, result = name }
  entity.max_speed = t.max_speed
  entity.max_power = t.max_power
  entity.energy_source.effectivity = t.effectivity
  entity.color = t.color
  entity.placeable_by = nil
  entity.factoriopedia_simulation = nil

  local item = table.deepcopy(data.raw["item-with-entity-data"]["locomotive"])
  item.name = name
  item.icon, item.icons = nil, icons(tier)
  item.place_result = name
  item.order = (item.order or "a") .. "-" .. tier

  local recipe = table.deepcopy(data.raw.recipe["locomotive"])
  recipe.name = name
  recipe.results = { { type = "item", name = name, amount = 1 } }
  recipe.main_product = nil
  recipe.enabled = false

  data:extend({ entity, item, recipe, {
    type = "technology",
    name = name,
    -- a name ending in -2 reads as level 2 of "tt-locomotive": name the locale keys outright
    localised_name = { "technology-name." .. name },
    localised_description = { "technology-description." .. name },
    -- vanilla's speed mark, as on upgrade technologies (playtest 2.15.10: the big signal
    -- tile with the tier number looked out of place); the name says Mk2 or Mk3
    icons = util.technology_icon_constant_speed("__base__/graphics/technology/railway.png"),
    prerequisites = t.prerequisites,
    effects = { { type = "unlock-recipe", recipe = name } },
    unit = { count = t.research_count, ingredients = t.research, time = 30 },
  } })
end
