-- 1.3: iron/copper smelting cities, depot city, coal fuel as the only locomotive fuel.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local function converts(city_name, x, inputs, output_item, powered)
  return function(ctx)
    local city, _, cout = h.city_rig(city_name, x, inputs, true)
    if powered then h.test_power({ x + 7, 0 }) end
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
    fn = converts("tt-city-depot", 280, { { name = "coal", count = 50 } }, "tt-coal-fuel", true),
  },
  {
    name = "mvp cities: depot needs electricity (420 kW at full output: half of 840, 2.15.7)",
    fn = function(ctx)
      local p = prototypes.entity["tt-city-depot"]
      local watts = p.get_max_energy_usage() * 60
      assert_.truthy(math.abs(watts - 420000) < 1000, "max usage " .. watts .. " W")
      local city = h.city_rig("tt-city-depot", 3000, { { name = "coal", count = 50 } }, false)
      ctx:wait(60 * 10, function()
        assert_.equals(city.products_finished, 0, "crafted without power")
        assert_.equals(remote.call("tt-city", "info", city).status, "no_power")
      end)
    end,
  },
  {
    name = "mvp cities: smelting cities need no electricity",
    fn = function()
      for _, n in ipairs({ "tt-city-iron-smelting", "tt-city-copper-smelting" }) do
        assert_.falsy(prototypes.entity[n].electric_energy_source_prototype, n .. " is electric")
      end
    end,
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
    name = "mvp cities: locomotives accept only depot fuels (coal, solid, rocket); burner entities still take coal",
    fn = function()
      h.clear_area({ { 350, -20 }, { 400, 20 } })
      for x = 352, 380, 2 do
        h.create("straight-rail", { x, -10 }, { direction = defines.direction.east })
      end
      local loco = h.create("locomotive", { 366, -10 }, { direction = defines.direction.east })
      local fuel = assert(loco.get_fuel_inventory())
      for _, ok in ipairs({ "tt-coal-fuel", "solid-fuel", "rocket-fuel" }) do -- 2.4.1
        assert_.truthy(fuel.can_insert({ name = ok, count = 1 }), ok .. " rejected")
      end
      for _, banned in ipairs({ "coal", "wood" }) do
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
      assert_.truthy(#makers > 0, "nothing makes coal fuel")
      for _, m in ipairs(makers) do
        assert_.truthy(string.find(m, "^tt%-city%-depot") ~= nil, "non-depot recipe makes coal fuel: " .. m)
      end
    end,
  },
}
