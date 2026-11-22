-- City items (PLAN 2.15.3): the player builds cities. Every city kind gets an item that
-- places it and a free hand-craft recipe ("tt-build-<entity>"), unlocked by research
-- (2.15.5). A city can only stand on plot tiles: its tile_buildability_rules require the
-- plot layer under the whole footprint, so the engine shows the placement red elsewhere
-- and refuses it. Script placement (tests, the fixed test map) checks nothing and still
-- works. Cities can be blueprinted, mined (their contents are lost: scripts/cities.lua) and,
-- where a later kind exists, swapped by the upgrade planner (next_upgrade).
local config = require("shared.config")
local defs = require("shared.city_defs")
local layout = require("shared.port_layout")

data:extend({
  { type = "item-subgroup", name = config.CITY_SUBGROUP, group = "production", order = "0[tracktorio]" },
})

local function entity_of(name)
  return data.raw["assembling-machine"][name] or data.raw["lab"][name] or data.raw["rocket-silo"][name]
end

--- Icon of what the city makes (roof icon, else its first product), for the item's badge.
---@param def table
local function product_icon(def)
  local sprite = def.roof_icon
  if not sprite and def.recipe and def.recipe.results and def.recipe.results[1] then
    local r = def.recipe.results[1]
    sprite = (r.type == "fluid" and "fluid/" or "item/") .. r.name
  end
  if not sprite then return nil end
  local kind, name = string.match(sprite, "^(%a+)/(.+)$")
  if kind == "fluid" then return data.raw.fluid[name] and data.raw.fluid[name].icon end
  -- any item type: repair packs are "repair-tool", science packs "tool" (playtest 2.15.10:
  -- looking only in data.raw.item left those cities with the bare building icon)
  for type in pairs(defines.prototypes.item) do
    local proto = data.raw[type] and data.raw[type][name]
    if proto then return proto.icon or (proto.icons and proto.icons[1].icon) end
  end
  return nil
end

---@type table<string, boolean>
local FLAGS_KEEP = { ["placeable-neutral"] = true, ["not-rotatable"] = true, ["not-flammable"] = true,
  ["not-repairable"] = true, ["not-in-kill-statistics"] = true, ["not-in-made-in"] = true, ["player-creation"] = true }

---@type table<string, boolean> city kinds that have a later kind (coal smelting)
local upgraded = {}
for _, def in ipairs(defs.list) do
  if def.upgrade_from then upgraded[def.upgrade_from] = true end
end

for i, def in ipairs(defs.list) do
  local name = defs.entity_name(def.name)
  local entity = assert(entity_of(name), "tt: no city entity " .. name)
  -- buildable, blueprintable, minable and upgradable by the player
  ---@type string[]
  local flags = { "placeable-player" }
  for _, f in ipairs(entity.flags or {}) do
    local flag = tostring(f)
    if FLAGS_KEEP[flag] then flags[#flags + 1] = flag end
  end
  entity.flags = flags --[[@as EntityPrototypeFlags]]
  entity.minable = { mining_time = 1, result = name }
  entity.placeable_by = { item = name, count = 1 }
  local half = layout.size(def) / 2 - 0.1
  entity.tile_buildability_rules = {
    { area = { { -half, -half }, { half, half } }, required_tiles = { layers = { [config.PLOT_LAYER] = true } },
      colliding_tiles = { layers = {} }, remove_on_collision = true },
  }
  -- the upgrade planner swaps a city for its later kind (electric smelting, 2.15.2)
  entity.fast_replaceable_group = "tt-city-" .. (def.upgrade_from or def.name)

  -- Icon (user, playtest 2.15.10): what the city makes, full size, so cities tell apart in
  -- the quickbar; the city building small in the top left says it is a city. Smelting kinds
  -- with a later kind get a coal mark, the electric kind a lightning mark (bottom right).
  local building = entity.icon or (entity.icons and entity.icons[1].icon)
  local product = product_icon(def)
  local icons = { { icon = product or building, icon_size = 64 } }
  if product then
    icons[#icons + 1] = { icon = building, icon_size = 64, scale = 0.25, shift = { -8, -8 }, floating = true }
  end
  local mark = def.upgrade_from and "__base__/graphics/icons/signal/signal-lightning.png"
    or (upgraded[def.name] and "__base__/graphics/icons/coal.png")
  if mark then icons[#icons + 1] = { icon = mark, icon_size = 64, scale = 0.25, shift = { 8, 8 }, floating = true } end
  entity.icons, entity.icon = icons, nil
  data:extend({
    {
      type = "item",
      name = name,
      localised_name = { "entity-name." .. name },
      localised_description = { "tt-city-description." .. name },
      icons = icons,
      subgroup = config.CITY_SUBGROUP,
      order = string.format("%02d-%02d", defs.depth[def.name] or 0, i),
      place_result = name,
      stack_size = 10,
    },
    {
      type = "recipe",
      name = config.CITY_BUILD_RECIPE_PREFIX .. name,
      localised_name = { "entity-name." .. name },
      categories = { config.FREE_CATEGORY },
      enabled = def.unlock == nil, -- the rest are unlocked by research (city_research.lua)
      ingredients = {},
      energy_required = config.FREE_CRAFT_TIME,
      results = { { type = "item", name = name, amount = 1 } },
      allow_productivity = false,
      auto_recycle = false,
    },
  })
end

for _, def in ipairs(defs.list) do
  if def.upgrade_from then
    local from = entity_of(defs.entity_name(def.upgrade_from))
    from.next_upgrade = defs.entity_name(def.name)
  end
end
