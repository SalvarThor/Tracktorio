-- 2.6: uranium and the nuclear power city.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local X = 11000
local NUCLEAR = "tt-city-nuclear-power"

--- Nuclear power city at {x+0.5, 0.5} with water piped in at the bottom middle, a pole east
--- of it and an optional consumer drawing `demand_w`. `cells` fuel cells go in its burner.
local function nuclear_rig(x, demand_w, cells, name)
  h.clear_area({ { x - 10, -12 }, { x + 16, 14 } })
  local city = h.place_city(name or NUCLEAR, { x + 0.5, 0.5 })
  local pipe = h.create("infinity-pipe", { x + 0.5, 5.5 })
  pipe.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "exactly", temperature = 15 })
  h.create("small-electric-pole", { x + 5.5, 0.5 })
  if cells and cells > 0 then city.get_fuel_inventory().insert({ name = "uranium-fuel-cell", count = cells }) end
  local eei
  if demand_w then
    eei = h.create("electric-energy-interface", { x + 7, 1 })
    eei.power_production = 0
    eei.power_usage = demand_w / 60
    eei.electric_buffer_size = demand_w
    eei.energy = 0
  end
  return city, eei
end

--- Fuel energy left in a burner city: the cell burning now plus those waiting (J).
---@param city LuaEntity
local function fuel_left(city)
  local cell = prototypes.item["uranium-fuel-cell"].fuel_value
  return (city.burner.remaining_burning_fuel or 0) + city.get_fuel_inventory().get_item_count("uranium-fuel-cell") * cell
end

local function packs_of(tech)
  local packs = {}
  for _, i in ipairs(tech.research_unit_ingredients) do packs[#packs + 1] = i.name end
  table.sort(packs)
  return table.concat(packs, ",")
end

return {
  {
    name = "nuclear: Uranium mining is red + green + blue research and enables mining with fluid",
    fn = function()
      local force = game.forces["player"]
      local mining = force.technologies["uranium-mining"]
      assert_.truthy(mining.enabled and not mining.prototype.hidden, "uranium mining disabled or hidden")
      assert_.equals(packs_of(mining), "automation-science-pack,chemical-science-pack,logistic-science-pack")
      local fluid = false
      for _, e in ipairs(mining.prototype.effects) do
        if e.type == "mining-with-fluid" then fluid = true end
      end
      assert_.truthy(fluid, "uranium mining no longer enables mining with fluid")
      assert_.falsy(force.mining_with_fluid, "mining with fluid already on at the start")
    end,
  },
  {
    name = "nuclear: a drill on uranium mines only with sulfuric acid, and that completes Uranium processing's trigger",
    fn = function(ctx)
      local force = game.forces["player"]
      local mining, processing = force.technologies["uranium-mining"], force.technologies["uranium-processing"]
      local was = mining.researched
      mining.researched = true
      assert_.truthy(force.mining_with_fluid, "mining with fluid not enabled")
      assert_.falsy(processing.researched, "uranium processing already researched")
      local x = X
      h.clear_area({ { x - 10, -10 }, { x + 14, 14 } })
      for dx = -1, 1 do
        for dy = -1, 1 do
          h.surface().create_entity({ name = "uranium-ore", position = { x + dx + 0.5, dy + 0.5 }, amount = 10000 })
        end
      end
      local drill = h.create("electric-mining-drill", { x + 0.5, 0.5 })
      h.test_power({ x + 6.5, 0.5 }, 1e6)
      local mined_without_acid = false
      ctx:wait(120, function()
        mined_without_acid = processing.researched
        assert_.falsy(mined_without_acid, "mined uranium without acid")
        drill.insert_fluid({ name = "sulfuric-acid", amount = 100 })
        ctx:wait_until(function() return processing.researched end, 60 * 15, function()
          processing.researched = false
          mining.researched = was
        end)
      end)
    end,
  },
  {
    name = "nuclear: the generated map has a uranium patch far from every city",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-uranium")
      local l = remote.call("tt-map", "layout")
      local patch
      for _, p in ipairs(l.patches) do if p.name == "uranium-ore" then patch = p end end
      assert(patch, "no uranium patch in the layout")
      local total = 0
      for _, e in pairs(surface.find_entities_filtered({ name = "uranium-ore", position = { patch.x, patch.y }, radius = patch.radius + 1 })) do
        total = total + e.amount
      end
      assert_.truthy(total > 200000, "uranium total " .. total)
      for _, c in ipairs(l.cities) do
        local d = math.sqrt((patch.x - c.x) ^ 2 + (patch.y - c.y) ^ 2)
        assert_.truthy(d >= 100, "uranium too close to " .. c.label .. ": " .. d)
      end
    end,
  },
  {
    name = "nuclear: uranium city tier 1 takes 1.43 ore + 0.01 iron/s, makes 0.01 fuel cells/s at 0.6 MW",
    fn = function()
      local p = prototypes.entity["tt-city-uranium"]
      local r = p.fixed_recipe
      local per_s = p.get_crafting_speed() / r.energy
      local got = {}
      for _, i in ipairs(r.ingredients) do got[i.name] = i.amount * per_s end
      for _, o in ipairs(r.products) do got[o.name] = o.amount * per_s end
      assert_.truthy(math.abs(got["uranium-ore"] - 1.43) < 1e-6, "ore " .. tostring(got["uranium-ore"]))
      assert_.truthy(math.abs(got["iron-plate"] - 0.01) < 1e-6, "iron " .. tostring(got["iron-plate"]))
      assert_.truthy(math.abs(got["uranium-fuel-cell"] - 0.01) < 1e-6, "cells " .. tostring(got["uranium-fuel-cell"]))
      assert_.equals(table_size(got), 3)
      local w = p.get_max_energy_usage() * 60
      assert_.truthy(math.abs(w - 600e3) < 1000, "draws " .. w)
      for tier = 2, 3 do assert_.truthy(prototypes.entity["tt-city-uranium-t" .. tier], "tier " .. tier) end
    end,
  },
  {
    name = "nuclear: a powered uranium city (tier 3) turns ore and iron into a fuel cell",
    fn = function(ctx)
      local x = X + 60
      h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
      local city = h.place_city("tt-city-uranium-t3", { x + 0.5, 0.5 })
      h.test_power({ x + 8.5, 0.5 }, 3e6)
      city.insert({ name = "uranium-ore", count = 143 })
      city.insert({ name = "iron-plate", count = 1 })
      ctx:wait_until(function()
        return city.get_output_inventory().get_item_count("uranium-fuel-cell") >= 1
      end, 60 * 40, function()
        assert_.equals(city.get_inventory(defines.inventory.crafter_input).get_item_count("uranium-ore"), 0, "ore left")
      end)
    end,
  },
  {
    name = "nuclear: the generated map has the uranium city",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-uranium")
      assert_.equals(surface.count_entities_filtered({ name = "tt-city-uranium" }), 1)
    end,
  },
  {
    name = "nuclear: nuclear power city makes 20 / 40 / 80 MW from 206 water/s per 20 MW; a cell lasts 400 s; no depleted cells",
    fn = function()
      local cell = prototypes.item["uranium-fuel-cell"]
      assert_.equals(cell.fuel_value, 8e9)
      assert_.equals(cell.burnt_result, nil, "fuel cell still leaves a depleted cell")
      for tier, mw in ipairs({ 20, 40, 80 }) do
        local name = tier == 1 and NUCLEAR or (NUCLEAR .. "-t" .. tier)
        local p = assert(prototypes.entity[name], name)
        assert_.truthy(p.burner_prototype, name .. " has no burner")
        assert_.truthy(p.burner_prototype.fuel_categories["nuclear"], name .. " burns no nuclear fuel")
        local burn = p.get_max_energy_usage() * 60
        assert_.truthy(math.abs(burn - mw * 1e6) < 1e3, name .. " burns " .. burn)
        local r = p.fixed_recipe
        local steam = r.products[1].amount * p.get_crafting_speed() / r.energy
        assert_.truthy(math.abs(steam - mw * 1e6 / 97e3) < 0.01, name .. " steam/s " .. steam)
        assert_.equals(r.products[1].temperature, 500)
        local gen = assert(prototypes.entity[tier == 1 and "tt-nuclear-generator" or ("tt-nuclear-generator-t" .. tier)])
        local out = gen.get_max_energy_production() * 60
        assert_.truthy(math.abs(out - mw * 1e6) < 1e3, name .. " generator " .. out)
        assert_.equals(gen.maximum_temperature, 500)
        assert_.truthy(math.abs(cell.fuel_value / burn - 400 / (mw / 20)) < 0.01, name .. " cell lasts " .. cell.fuel_value / burn)
      end
    end,
  },
  {
    name = "nuclear: a fuelled nuclear city delivers 18 MW to the pole network and burns fuel",
    fn = function(ctx)
      local city, eei = nuclear_rig(X + 120, 18e6, 2)
      ---@cast eei LuaEntity
      local gens = h.surface().find_entities_filtered({ name = "tt-nuclear-generator", position = city.position, radius = 1 })
      assert_.equals(#gens, 1, "generator count")
      local start = fuel_left(city)
      ctx:wait(60 * 10, function()
        -- the consumer drains its own buffer, so measure what the generator puts out
        local sum, n = 0, 0
        ctx:wait_until(function()
          sum, n = sum + gens[1].energy_generated_last_tick, n + 1
          return n >= 60
        end, 120, function()
          local watts = sum / n * 60
          assert_.truthy(watts > 0.95 * 18e6 and watts < 20.1e6, "generator put out " .. watts .. " W for an 18 MW demand")
          assert_.truthy(eei.energy > 0, "consumer got nothing")
          local used = start - fuel_left(city)
          -- ~11 s at 18-20 MW
          assert_.truthy(used > 150e6 and used < 260e6, "fuel used " .. used)
        end)
      end)
    end,
  },
  {
    name = "nuclear: without fuel cells it is starved, and the window names them",
    fn = function(ctx)
      local city = nuclear_rig(X + 160, 5e6, 0)
      ctx:wait(120, function()
        local i = remote.call("tt-city", "info", city)
        assert_.equals(i.status, "starved")
        assert_.truthy(i.missing and i.missing[1] == "uranium-fuel-cell", "missing " .. serpent.line(i.missing))
        local fuel
        for _, ing in ipairs(i.recipe.ingredients) do if ing.name == "uranium-fuel-cell" then fuel = ing end end
        assert(fuel, "fuel not listed as an input")
        assert_.truthy(fuel.fuel and math.abs(fuel.per_min_max - 0.15) < 1e-6, "fuel per min " .. tostring(fuel.per_min_max))
        local conns = remote.call("tt-city", "info", city).connections
        assert_.equals(#conns, 1)
        assert_.equals(conns[1].fluid, "water")
        assert_.equals(conns[1].side, "south")
      end)
    end,
  },
  {
    name = "nuclear: with no power demand it waits and its fuel lasts",
    fn = function(ctx)
      local city = nuclear_rig(X + 200, nil, 1)
      ctx:wait(60 * 10, function()
        local left = fuel_left(city)
        ctx:wait(60 * 20, function()
          assert_.truthy(left - fuel_left(city) < 1e6, "burned " .. (left - fuel_left(city)) .. " J with no demand")
          local i = remote.call("tt-city", "info", city)
          assert_.equals(i.status, "output_full")
        end)
      end)
    end,
  },
  {
    name = "nuclear: upgrading keeps the fuel cells and the one burning",
    fn = function(ctx)
      local city = nuclear_rig(X + 240, 30e6, 5)
      ctx:wait(120, function()
        local before = fuel_left(city)
        local t2 = assert(remote.call("tt-city", "upgrade_now", city))
        assert_.equals(t2.name, NUCLEAR .. "-t2")
        assert_.truthy(math.abs(fuel_left(t2) - before) < 1e6, "fuel " .. before .. " -> " .. fuel_left(t2))
        assert_.equals(#h.surface().find_entities_filtered({ name = "tt-nuclear-generator-t2", position = t2.position, radius = 1 }), 1)
        assert_.equals(#h.surface().find_entities_filtered({ name = "tt-nuclear-generator", position = t2.position, radius = 1 }), 0)
      end)
    end,
  },
  {
    name = "nuclear: an inserter feeds fuel cells into the nuclear city's burner",
    fn = function(ctx)
      local x = X + 280
      local city = nuclear_rig(x, nil, 0)
      h.feeder({ x + 0.5, -5.5 }, { x + 0.5, -4.5 }, defines.direction.north,
        { { name = "uranium-fuel-cell", count = 3 } })
      ctx:wait_until(function()
        return fuel_left(city) > 0
      end, 60 * 10, function()
        assert_.truthy(city.get_fuel_inventory().get_item_count("uranium-fuel-cell") >= 1
          or (city.burner.remaining_burning_fuel or 0) > 0, "no fuel arrived")
      end)
    end,
  },
  {
    name = "nuclear: the generated map has the nuclear power city",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-uranium")
      assert_.equals(surface.count_entities_filtered({ name = NUCLEAR }), 1)
    end,
  },
}
