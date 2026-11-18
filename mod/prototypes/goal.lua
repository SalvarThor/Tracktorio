-- Goal box: a fixed container that receives iron and copper plates (SPEC MVP win condition).
-- Script sets its slot filters (half iron, half copper) and counts and removes deliveries.
local config = require("shared.config")

local size = 9
local half = size / 2
local source = data.raw.container["steel-chest"]
local picture = table.deepcopy(source.picture)

local function scale_sprites(t, factor)
  if type(t) ~= "table" then return end
  if t.filename or t.filenames then
    t.scale = (t.scale or 1) * factor
    if t.shift then t.shift = { t.shift[1] * factor, t.shift[2] * factor } end
  end
  for _, v in pairs(t) do if type(v) == "table" then scale_sprites(v, factor) end end
end
scale_sprites(picture, size)

data:extend({
  {
    -- Slot filter for a goal metal that has reached its target: nothing can match it, so
    -- inserters stop delivering that metal (playtest 1.10).
    type = "item",
    name = config.GOAL_CLOSED_ITEM,
    icon = "__core__/graphics/icons/mip/slot-item-in-hand.png",
    hidden = true,
    hidden_in_factoriopedia = true,
    stack_size = 1,
    auto_recycle = false,
  },
  {
    type = "container",
    name = config.CITY.goal,
    icon = source.icon,
    flags = {
      "placeable-neutral", "not-rotatable", "not-blueprintable", "not-deconstructable",
      "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable", "not-in-kill-statistics",
    },
    minable = nil,
    max_health = 10000,
    collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } },
    selection_box = { { -half, -half }, { half, half } },
    map_color = { r = 0.2, g = 0.8, b = 0.3 },
    inventory_size = config.GOAL_SLOTS,
    inventory_type = "with_filters_and_bar",
    picture = picture,
    impact_category = "metal",
  },
})
