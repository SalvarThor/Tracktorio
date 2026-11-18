-- 1.3: iron/copper smelting cities, depot city, coal fuel as the only locomotive fuel.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local function converts(city_name, x, inputs, output_item)
  return function(ctx)
    local city, _, cout = h.city_rig(city_name, x, inputs, true)
    ctx:wait_until(function() return cout.get_item_count(output_item) > 0 end, 60 * 30, function()
      assert_.truthy(city.products_finished > 0, "products_finished")
    end)
  end
end

return {
  {
    name = "mvp cities: iron smelting city turns ore and coal into plates",
    fn = converts("tt-city-iron-smelting", 200,
      { { name = "iron-ore", count = 100 }, { name = "coal", count = 20 } }, "iron-plate"),
  },
  {
    name = "mvp cities: copper smelting city turns ore and coal into plates",
    fn = converts("tt-city-copper-smelting", 240,
      { { name = "copper-ore", count = 100 }, { name = "coal", count = 20 } }, "copper-plate"),
  },
  {
    name = "mvp cities: depot city turns coal into coal fuel",
    fn = converts("tt-city-depot", 280, { { name = "coal", count = 50 } }, "tt-coal-fuel"),
  },
  {
    name = "mvp cities: smelting needs coal (starves on ore alone)",
    fn = function(ctx)
      local city = h.city_rig("tt-city-iron-smelting", 320, { { name = "iron-ore", count = 100 } }, false)
      ctx:wait(60 * 10, function()
        assert_.equals(city.products_finished, 0, "crafted without coal")
      end)
    end,
  },
  {
    name = "mvp cities: locomotives accept only coal fuel; burner entities still take coal",
    fn = function()
      h.clear_area({ { 350, -20 }, { 400, 20 } })
      for x = 352, 380, 2 do
        h.create("straight-rail", { x, -10 }, { direction = defines.direction.east })
      end
      local loco = h.create("locomotive", { 366, -10 }, { direction = defines.direction.east })
      local fuel = assert(loco.get_fuel_inventory())
      assert_.truthy(fuel.can_insert({ name = "tt-coal-fuel", count = 1 }), "coal fuel rejected")
      for _, banned in ipairs({ "coal", "wood", "solid-fuel", "rocket-fuel" }) do
        assert_.falsy(fuel.can_insert({ name = banned, count = 1 }), banned .. " accepted")
      end
      local drill = h.create("burner-mining-drill", { 360, 10 })
      assert_.truthy(assert(drill.get_fuel_inventory()).can_insert({ name = "coal", count = 1 }), "drill rejects coal")
      local ins = h.create("burner-inserter", { 370, 10 })
      assert_.truthy(assert(ins.get_fuel_inventory()).can_insert({ name = "coal", count = 1 }), "inserter rejects coal")
    end,
  },
  {
    name = "mvp cities: only depot cities make coal fuel",
    fn = function()
      local makers = {}
      for name, recipe in pairs(prototypes.recipe) do
        for _, p in ipairs(recipe.products) do
          if p.name == "tt-coal-fuel" then makers[#makers + 1] = name end
        end
      end
      assert_.equals(#makers, 1, "recipes making coal fuel: " .. serpent.line(makers))
      assert_.equals(makers[1], "tt-city-depot")
    end,
  },
}
