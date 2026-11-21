-- Plots (PLAN 2.15.3): the only ground a city can be built on. Map generation paints each
-- 12x12 plot: a ring of hazard-striped tiles around refined concrete. Both carry the
-- tt_plot collision layer, which the cities require under all of their footprint
-- (prototypes/city_items.lua) and which no tile item may be placed on (data-final-fixes,
-- prototypes/plot_fixes.lua). Plot tiles can't be mined.
local config = require("shared.config")

data:extend({ { type = "collision-layer", name = config.PLOT_LAYER } })

-- Bright on the map, so plots stand out on a fresh map before anything is built.
local MAP_COLOR = { r = 0.95, g = 0.75, b = 0.15 }

---@param name string
---@param source string vanilla tile to copy the look from
local function plot_tile(name, source)
  local tile = table.deepcopy(data.raw.tile[source])
  tile.name = name
  tile.minable = nil
  tile.placeable_by = nil
  tile.next_direction = nil
  tile.map_color = MAP_COLOR
  tile.transition_merges_with_tile = nil
  tile.collision_mask = table.deepcopy(tile.collision_mask)
  tile.collision_mask.layers[config.PLOT_LAYER] = true
  tile.order = "z[tracktorio]-" .. name
  return tile
end

data:extend({
  plot_tile(config.PLOT_TILE, "refined-concrete"),
  plot_tile(config.PLOT_BORDER_TILE, "refined-hazard-concrete-left"),
})
