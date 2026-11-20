-- 2.4.3: refinery city (several fluid inputs and outputs, 2.4.2).
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local REFINERY = "tt-city-refinery"
local X = 8600

local function info(city) return remote.call("tt-city", "info", city) end

local function contains(list, v)
  for _, x in ipairs(list or {}) do if x == v then return true end end
  return false
end

--- A powered refinery city centred at (x + 0.5, 0.5) with crude oil and water supplied.
local function rig(x)
  h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
  local city = h.place_city(REFINERY, { x + 0.5, 0.5 })
  h.pipe_at(city, "crude-oil", "input", true)
  h.pipe_at(city, "water", "input", true)
  h.test_power({ x + 8.5, 0.5 }, 4e6)
  return city
end

return {
  {
    name = "oil: refinery city tier 1 takes 40 crude + 28 water/s, makes 26 light oil + 22 gas/s at 0.95 MW",
    fn = function()
      local p = prototypes.entity[REFINERY]
      local r = p.fixed_recipe
      local per_s = p.get_crafting_speed() / r.energy
      local amounts = {}
      for _, i in ipairs(r.ingredients) do amounts[i.name] = i.amount * per_s end
      for _, o in ipairs(r.products) do amounts[o.name] = o.amount * per_s end
      assert_.equals(amounts["crude-oil"], 40)
      assert_.equals(amounts["water"], 28)
      assert_.equals(amounts["light-oil"], 26)
      assert_.equals(amounts["petroleum-gas"], 22)
      assert_.truthy(math.abs(p.get_max_energy_usage() * 60 - 0.95e6) < 1000, "power")
      for tier = 2, 3 do assert_.truthy(prototypes.entity[REFINERY .. "-t" .. tier], "tier " .. tier) end
    end,
  },
  {
    name = "oil: the window lists four pipe connections (crude and water in north, light and gas out south)",
    fn = function()
      h.clear_area({ { X - 12, -40 }, { X + 12, -20 } })
      local city = h.place_city(REFINERY, { X + 0.5, -29.5 })
      local c = info(city).connections
      assert_.equals(#c, 4, serpent.line(c))
      local by = {}
      for _, x in ipairs(c) do by[x.fluid] = x end
      -- 2.10 port layout: inputs on the north wall, outputs on the south, 2.5 either side
      assert_.equals(by["crude-oil"].side, "north"); assert_.equals(by["crude-oil"].offset, -2.5)
      assert_.equals(by["water"].side, "north"); assert_.equals(by["water"].offset, 2.5)
      assert_.equals(by["light-oil"].kind, "output"); assert_.equals(by["light-oil"].side, "south")
      assert_.equals(by["petroleum-gas"].kind, "output"); assert_.equals(by["petroleum-gas"].offset, 2.5)
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, city)
      assert_.truthy(assert(p.gui.screen["tt_city_frame"])["body"]["pipe-4"], "fourth pipe line missing")
      p.opened = nil
    end,
  },
  {
    name = "oil: refinery city runs on crude oil + water with both outputs drained",
    fn = function(ctx)
      local city = rig(X)
      h.pipe_at(city, "light-oil", "output", false)
      h.pipe_at(city, "petroleum-gas", "output", false)
      ctx:wait_until(function() return city.products_finished >= 3 end, 60 * 20, function()
        assert_.equals(info(city).status, "running")
      end)
    end,
  },
  {
    name = "oil: with no water it is starved and names water",
    fn = function(ctx)
      h.clear_area({ { X + 28, -12 }, { X + 54, 14 } })
      local x = X + 40
      local city = h.place_city(REFINERY, { x + 0.5, 0.5 })
      h.pipe_at(city, "crude-oil", "input", true)
      h.test_power({ x + 8.5, 0.5 }, 4e6)
      ctx:wait(120, function()
        local i = info(city)
        assert_.equals(i.status, "starved")
        assert_.truthy(contains(i.missing, "water"), serpent.line(i.missing))
      end)
    end,
  },
  {
    name = "oil: fuel depots: 2 solid fuel/s from 20 light oil (0.42 MW); 0.2 rocket fuel/s from 2 solid + 2 light (0.6 MW)",
    fn = function()
      local function rates(name)
        local p = prototypes.entity[name]
        local r = p.fixed_recipe
        local per_s = p.get_crafting_speed() / r.energy
        local out = {}
        for _, i in ipairs(r.ingredients) do out[i.name] = i.amount * per_s end
        for _, o in ipairs(r.products) do out[o.name] = o.amount * per_s end
        return out, p.get_max_energy_usage() * 60
      end
      local s, sw = rates("tt-city-solid-fuel-depot")
      assert_.equals(s["light-oil"], 20); assert_.equals(s["solid-fuel"], 2)
      assert_.truthy(math.abs(sw - 420e3) < 1000, "solid power " .. sw)
      local r, rw = rates("tt-city-rocket-fuel-depot")
      assert_.truthy(math.abs(r["rocket-fuel"] - 0.2) < 1e-9, "rocket " .. r["rocket-fuel"])
      assert_.truthy(math.abs(r["solid-fuel"] - 2) < 1e-9 and math.abs(r["light-oil"] - 2) < 1e-9, serpent.line(r))
      assert_.truthy(math.abs(rw - 600e3) < 1000, "rocket power " .. rw)
    end,
  },
  {
    name = "oil: a solid fuel depot makes solid fuel from piped light oil and has a service port",
    fn = function(ctx)
      local x = X + 120
      h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
      local city = h.place_city("tt-city-solid-fuel-depot", { x + 0.5, 0.5 })
      assert_.truthy(assert(remote.call("tt-city", "service_status", city)).port, "no service port")
      h.pipe_at(city, "light-oil", "input", true)
      h.test_power({ x + 8.5, 0.5 }, 2e6)
      -- (the output port takes the fuel out of the city, so count crafts)
      ctx:wait_until(function() return city.products_finished >= 5 end, 60 * 20, function()
        assert_.equals(remote.call("tt-city", "info", city).recipe.products[1].name, "solid-fuel")
      end)
    end,
  },
  {
    name = "oil: a rocket fuel depot makes rocket fuel from solid fuel + piped light oil and has a service port",
    fn = function(ctx)
      local x = X + 160
      h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
      local city = h.place_city("tt-city-rocket-fuel-depot", { x + 0.5, 0.5 })
      assert_.truthy(assert(remote.call("tt-city", "service_status", city)).port, "no service port")
      city.insert({ name = "solid-fuel", count = 50 })
      h.pipe_at(city, "light-oil", "input", true)
      h.test_power({ x + 8.5, 0.5 }, 2e6)
      ctx:wait_until(function() return city.products_finished >= 1 end, 60 * 15, function()
        assert_.equals(assert(city.get_inventory(defines.inventory.crafter_output)).get_item_count("rocket-fuel"), 1)
      end)
    end,
  },
  {
    name = "oil: Oil gathering is red + green research; a pumpjack mining crude oil completes Oil processing's trigger",
    fn = function(ctx)
      local force = game.forces["player"]
      local gathering, processing = force.technologies["oil-gathering"], force.technologies["oil-processing"]
      local packs = {}
      for _, i in ipairs(gathering.research_unit_ingredients) do packs[#packs + 1] = i.name end
      table.sort(packs)
      assert_.equals(table.concat(packs, ","), "automation-science-pack,logistic-science-pack")
      assert_.truthy(gathering.enabled and processing.enabled, "oil techs disabled")
      local was = gathering.researched
      gathering.researched = true -- unlocks the (free) pumpjack
      assert_.truthy(force.recipes["pumpjack"].enabled, "pumpjack not unlocked")
      assert_.falsy(processing.researched, "oil processing already researched")
      local x = X + 200
      h.clear_area({ { x - 10, -10 }, { x + 14, 14 } })
      h.surface().create_entity({ name = "crude-oil", position = { x + 0.5, 0.5 }, amount = 300000 })
      h.create("pumpjack", { x + 0.5, 0.5 })
      h.test_power({ x + 6.5, 0.5 }, 1e6)
      ctx:wait_until(function() return processing.researched end, 60 * 10, function()
        processing.researched = false
        gathering.researched = was
      end)
    end,
  },
  {
    name = "oil: the generated map has an oil field of 6 wells and the refinery and fuel depots",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-oil")
      assert_.equals(surface.count_entities_filtered({ name = "crude-oil" }), 6)
      for _, name in ipairs({ REFINERY, "tt-city-solid-fuel-depot", "tt-city-rocket-fuel-depot" }) do
        assert_.equals(surface.count_entities_filtered({ name = name }), 1, name)
      end
    end,
  },
  {
    -- playtest 2.4.6: an unpowered refinery's window said nothing about its inputs
    name = "oil: without power the window still shows what is inside and what is missing",
    fn = function(ctx)
      local x = X + 240
      h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
      local city = h.place_city(REFINERY, { x + 0.5, 0.5 })
      h.pipe_at(city, "crude-oil", "input", true) -- crude oil, no water, no power
      ctx:wait(120, function()
        local i = info(city)
        assert_.equals(i.status, "no_power")
        assert_.truthy(contains(i.also_missing, "water"), "also_missing " .. serpent.line(i.also_missing))
        assert_.falsy(contains(i.also_missing, "crude-oil"), "crude oil is there")
        local crude
        for _, ing in ipairs(i.recipe.ingredients) do if ing.name == "crude-oil" then crude = ing end end
        assert_.truthy(crude and crude.have > 0, "crude oil amount not shown")
        local p = assert(game.players[1])
        remote.call("tt-city", "open_gui", p.index, city)
        local line = assert(p.gui.screen["tt_city_frame"])["body"]["also_missing"]
        assert_.truthy(line, "no 'also missing' line")
        assert_.equals(line.caption[1], "tt-gui.city-also-missing")
        p.opened = nil
      end)
    end,
  },
  {
    name = "oil: an undrained gas output stalls it, and the status names petroleum gas",
    fn = function(ctx)
      local city = rig(X + 80)
      h.pipe_at(city, "light-oil", "output", false) -- light oil drained, gas not
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 60, function()
        local full = info(city).full
        assert_.truthy(contains(full, "petroleum-gas"), serpent.line(full))
        assert_.falsy(contains(full, "light-oil"), "light oil is drained: " .. serpent.line(full))
      end)
    end,
  },
}
