-- 2.15.3: plots. Cities are items the player builds, and only on plot tiles.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local city_defs = require("__tracktorio__/shared/city_defs")

local X = 60000
local PLOT, BORDER, LAYER = "tt-plot", "tt-plot-border", "tt_plot"

--- Paint a 12x12 plot whose centre is the tile corner (cx, cy): a border ring around the
--- inside, as map generation does.
---@param cx integer
---@param cy integer
local function paint_plot(cx, cy)
  local tiles = {}
  for x = cx - 6, cx + 5 do
    for y = cy - 6, cy + 5 do
      local edge = x == cx - 6 or x == cx + 5 or y == cy - 6 or y == cy + 5
      tiles[#tiles + 1] = { name = edge and BORDER or PLOT, position = { x, y } }
    end
  end
  h.surface().set_tiles(tiles)
end

---@param name string
---@param x number
---@param y number
local function can_build(name, x, y)
  return h.surface().can_place_entity({ name = name, position = { x, y }, force = "player",
    build_check_type = defines.build_check_type.manual })
end

return {
  {
    name = "plots: both plot tiles carry the plot layer and can't be mined",
    fn = function()
      for _, name in ipairs({ PLOT, BORDER }) do
        local t = assert(prototypes.tile[name], "no tile " .. name)
        assert_.truthy(t.collision_mask.layers[LAYER], name .. " lacks the plot layer")
        assert_.falsy(t.mineable_properties.minable, name .. " is minable")
      end
    end,
  },
  {
    name = "plots: no tile item (concrete, landfill, ...) can be placed on a plot",
    fn = function()
      local n = 0
      for name, item in pairs(prototypes.item) do
        local t = item.place_as_tile_result
        if t then
          n = n + 1
          assert_.truthy(t.condition.layers[LAYER], name .. " can be placed on a plot")
        end
      end
      assert_.truthy(n >= 3, "only " .. n .. " tile items")
    end,
  },
  {
    name = "plots: a city can be built on a plot and nowhere else",
    fn = function()
      h.clear_area({ { X - 30, -20 }, { X + 30, 20 } })
      paint_plot(X, 0)
      for _, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        -- the 9x9 silo centres on a tile, the 12x12 cities on a tile corner
        local cx = def.kind == "silo" and X + 0.5 or X
        local cy = def.kind == "silo" and 0.5 or 0
        assert_.truthy(can_build(name, cx, cy), name .. " can't be built on its plot")
        assert_.falsy(can_build(name, cx + 20, cy), name .. " can be built off the plot")
        if def.kind ~= "silo" then
          assert_.falsy(can_build(name, cx + 1, cy), name .. " can be built half off the plot")
        end
      end
    end,
  },
  {
    name = "plots: every city kind has an item and a free build recipe; coal smelting upgrades to electric",
    fn = function()
      for _, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        local item = assert(prototypes.item[name], name .. " has no item")
        assert_.equals(item.place_result.name, name, name .. " item places")
        local recipe = assert(prototypes.recipe["tt-build-" .. name], name .. " has no build recipe")
        assert_.equals(#recipe.ingredients, 0, name .. " build recipe has ingredients")
        assert_.equals(recipe.products[1].name, name, name .. " build recipe makes")
        local proto = prototypes.entity[name]
        assert_.equals(proto.mineable_properties.products[1].name, name, name .. " mines into its item")
      end
      for _, metal in ipairs({ "iron", "copper" }) do
        local coal = prototypes.entity["tt-city-" .. metal .. "-smelting"]
        assert_.equals(coal.next_upgrade and coal.next_upgrade.name, "tt-city-electric-" .. metal .. "-smelting", metal)
      end
    end,
  },
}
