-- 1.2: black box framework (placement, protection, hands-off, engine behaviour).
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local CITY = "tt-city-test" -- 5x5, iron-ore + coal -> iron-plate, 0.5 s, speed 1
local N = defines.direction.north

--- Build: input chest -> inserter -> city -> inserter -> output chest (if with_output).
--- A 5x5 city at {x+0.5, 0.5} spans x-2..x+3 and y -2..3.
local function rig(x, with_output, contents)
  h.clear_area({ { x - 6, -8 }, { x + 7, 9 } })
  local city = h.place_city(CITY, { x + 0.5, 0.5 })
  local cin = h.feeder({ x + 0.5, -3.5 }, { x + 0.5, -2.5 }, N, contents or {
    { name = "iron-ore", count = 100 }, { name = "coal", count = 100 } })
  local cout
  if with_output then
    cout = h.feeder({ x + 0.5, 4.5 }, { x + 0.5, 3.5 }, N, {})
  end
  return city, cin, cout
end

return {
  {
    name = "cities: prototype has no item, is not minable, has its fixed recipe",
    fn = function()
      local p = prototypes.entity[CITY]
      assert_.truthy(p, "prototype missing")
      assert_.equals(#(p.items_to_place_this or {}), 0, "items_to_place_this")
      assert_.falsy(p.mineable_properties.minable, "minable")
      assert_.equals(p.fixed_recipe and p.fixed_recipe.name, CITY)
    end,
  },
  {
    name = "cities: script placement protects and tracks the city",
    fn = function()
      h.clear_area({ { -10, -10 }, { 10, 10 } })
      local city = h.place_city(CITY, { 0.5, 0.5 })
      assert_.falsy(city.operable, "operable")
      assert_.falsy(city.destructible, "destructible")
      assert_.falsy(city.minable_flag, "minable_flag")
      assert_.falsy(city.rotatable, "rotatable")
      local listed = remote.call("tt-city", "list", CITY)
      local found = false
      for _, u in ipairs(listed) do if u == city.unit_number then found = true end end
      assert_.truthy(found, "not in tt-city.list")
      local dump = helpers.json_to_table(remote.call("tt-debug", "dump"))
      ---@cast dump table
      assert_.truthy(dump.storage.tt_cities[tostring(city.unit_number)], "not in storage dump")
    end,
  },
  {
    name = "cities: the player cannot open, mine or damage a city",
    fn = function()
      h.clear_area({ { -10, -10 }, { 10, 10 } })
      local city = h.place_city(CITY, { 0.5, 0.5 })
      local p = assert(game.players[1])
      p.opened = city
      assert_.falsy(p.opened, "player.opened is set")
      assert_.falsy(p.mine_entity(city, true), "mine_entity succeeded")
      assert_.equals(city.damage(100000, "enemy"), 0, "damage dealt")
      assert_.truthy(city.valid, "city gone")
    end,
  },
  {
    name = "cities: destroyed cities are dropped from storage",
    fn = function(ctx)
      h.clear_area({ { -10, -10 }, { 10, 10 } })
      local city = h.place_city(CITY, { 0.5, 0.5 })
      local unit = city.unit_number
      city.destroy()
      ctx:wait(2, function()
        for _, u in ipairs(remote.call("tt-city", "list", CITY)) do
          assert_.truthy(u ~= unit, "destroyed city still listed")
        end
      end)
    end,
  },
  {
    name = "cities: starved when there is no input",
    fn = function(ctx)
      h.clear_area({ { -10, -10 }, { 10, 10 } })
      local city = h.place_city(CITY, { 0.5, 0.5 })
      ctx:wait(10, function()
        local s = h.status_name(city)
        assert_.truthy(s == "item_ingredient_shortage" or s == "no_ingredients", "status " .. s)
      end)
    end,
  },
  {
    name = "cities: inserters feed and drain a city",
    fn = function(ctx)
      local city, _, cout = rig(30, true)
      ctx:wait_until(function() return cout.get_item_count("iron-plate") >= 5 end, 60 * 30, function()
        assert_.truthy(city.products_finished >= 5, "products_finished " .. city.products_finished)
      end)
    end,
  },
  {
    name = "cities: runs at the rate of the slowest input",
    fn = function(ctx)
      -- Coal only arrives once (2 pieces); ore is plentiful. Output must stop at 2.
      local city = rig(60, false, { { name = "iron-ore", count = 100 } })
      city.insert({ name = "coal", count = 2 })
      ctx:wait(60 * 10, function()
        assert_.equals(city.products_finished, 2, "products_finished")
        local s = h.status_name(city)
        assert_.truthy(s == "item_ingredient_shortage" or s == "no_ingredients", "status " .. s)
      end)
    end,
  },
  {
    name = "cities: a full output stalls the city (backpressure)",
    fn = function(ctx)
      local city = rig(90, false)
      ctx:wait_until(function() return h.status_name(city) == "full_output" end, 60 * 120, function()
        local made = city.products_finished
        ctx:wait(60 * 5, function()
          assert_.equals(city.products_finished, made, "kept crafting while full")
        end)
      end)
    end,
  },
}
