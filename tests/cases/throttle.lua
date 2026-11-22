-- 2.12: the throttle. A hidden beacon in a city with modules that take 5% off speed and
-- power each, set by script so a steady input gives a steady city.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local X = 48000
local city_defs = require("__tracktorio__/shared/city_defs")

--- Drive a city by script for `seconds`: every 6 ticks `step(city)` runs, and over the last
--- `sample_s` seconds the city's status is sampled. `done(samples)` gets
--- { working = n, other = n, statuses = { [name] = n } }.
---@param ctx table
---@param city LuaEntity
---@param seconds number
---@param sample_s number
---@param step function
---@param done function
local function drive(ctx, city, seconds, sample_s, step, done)
  local ticks, left = 0, seconds * 60
  local samples = { working = 0, other = 0, statuses = {} }
  local function go()
    ctx:wait(6, function()
      step(city)
      ticks = ticks + 6
      if ticks > left - sample_s * 60 then
        local name = h.status_name(city)
        samples.statuses[name] = (samples.statuses[name] or 0) + 1
        -- low power flickers for a moment when the module count changes; it still runs
        if city.status == defines.entity_status.working or city.status == defines.entity_status.low_power then
          samples.working = samples.working + 1
        else samples.other = samples.other + 1 end
      end
      if ticks < left then go() else done(samples) end
    end)
  end
  go()
end

--- Full-speed rate of a crafting city's first ingredient, items per tick, and its name.
---@param city LuaEntity
local function full_rate(city)
  local recipe = prototypes.recipe[assert(city.get_recipe()).name]
  local ing = recipe.ingredients[1]
  return city.prototype.get_crafting_speed() / recipe.energy * ing.amount / 60, ing.name
end

--- A powered depot at x with an empty output (its output port's loader removed, so script
--- controls draining). Returns the city.
---@param x number
local function depot(x)
  h.clear_area({ { x - 14, -14 }, { x + 14, 14 } })
  local city = h.place_city("tt-city-depot", { x + 0.5, 0.5 })
  h.test_power({ x + 12, 0 }, 20e6)
  return city
end

---@param city LuaEntity
---@param steps integer
local function beacon_in(city, steps)
  local b = h.create("tt-throttle-beacon", city.position)
  if steps > 0 then
    assert(b.get_inventory(defines.inventory.beacon_modules)).insert({ name = "tt-throttle-module", count = steps })
  end
  return b
end

return {
  {
    -- 2.12.1 spike
    name = "throttle spike: a beacon's modules slow its city's speed and power together, 5% each, floor 20%",
    fn = function(ctx)
      local x = X
      h.clear_area({ { x - 12, -12 }, { x + 12, 12 } })
      local city = h.place_city("tt-city-depot", { x + 0.5, 0.5 })
      local base = city.crafting_speed
      local beacon = beacon_in(city, 10)
      ctx:wait(2, function()
        local e = city.effects or {}
        assert_.truthy(math.abs((e.speed or 0) + 0.5) < 1e-6, "speed effect " .. serpent.line(e))
        assert_.truthy(math.abs((e.consumption or 0) + 0.5) < 1e-6, "consumption effect " .. serpent.line(e))
        assert_.truthy(math.abs(city.crafting_speed - base * 0.5) < 1e-6, "crafting speed " .. city.crafting_speed .. " of " .. base)
        local inv = assert(beacon.get_inventory(defines.inventory.beacon_modules))
        inv.clear()
        inv.insert({ name = "tt-throttle-module", count = 16 })
        ctx:wait(2, function()
          assert_.truthy(math.abs(city.crafting_speed - base * 0.2) < 1e-6, "crafting speed at 16 steps " .. city.crafting_speed)
        end)
      end)
    end,
  },
  {
    name = "throttle spike: the beacon reaches nothing outside its city (a drill at the wall keeps full speed)",
    fn = function(ctx)
      local x = X + 100
      h.clear_area({ { x - 12, -12 }, { x + 12, 12 } })
      local city = h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 })
      local e = h.edges(city)
      local drill = h.create("electric-mining-drill", { e.right + 1, 0.5 })
      local inserter = h.create("assembling-machine-1", { x + 0.5, e.bottom + 1.5 })
      beacon_in(city, 16)
      ctx:wait(2, function()
        local function none(entity)
          local fx = entity.effects
          return fx == nil or ((fx.speed or 0) == 0 and (fx.consumption or 0) == 0)
        end
        assert_.falsy(none(city), "the city is not slowed")
        assert_.truthy(none(drill), "the drill is slowed: " .. serpent.line(drill.effects))
        assert_.truthy(none(inserter), "the machine below the wall is slowed: " .. serpent.line(inserter.effects))
      end)
    end,
  },
  {
    name = "throttle: every crafting city and the research complex has one; power and water cities and the silo don't",
    fn = function()
      for i, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        local x = X + 300 + i * 24
        h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
        local city = h.place_city(name, { x + 0.5, 0.5 })
        local t = remote.call("tt-city", "throttle", city)
        local recipe = def.recipe
        local expect = def.kind == "lab" or (city.type == "assembling-machine" and not city_defs.is_power(name)
          and recipe and #recipe.ingredients > 0)
        if expect then
          assert(t and t.beacon and t.beacon.valid, name .. " has no throttle")
          -- playtest 2.12: the player opened a beacon and took its modules
          assert_.falsy(t.beacon.prototype.selectable_in_game, "the beacon can be selected")
          assert_.falsy(t.beacon.operable, name .. " beacon is operable")
          assert_.falsy(t.beacon.minable_flag, name .. " beacon is minable")
          assert_.equals(t.percent, 100, name .. " starts below full speed")
        else
          assert_.falsy(t, name .. " has a throttle")
        end
        city.destroy()
      end
    end,
  },
  {
    name = "throttle: a steady feed at half the full rate runs the depot steadily at about 50%",
    fn = function(ctx)
      local city = depot(X + 3000)
      local per_tick, item = full_rate(city)
      local owed = 0
      drive(ctx, city, 40, 10, function(c)
        owed = owed + per_tick * 6 * 0.5
        local n = math.floor(owed)
        if n > 0 then owed = owed - c.get_inventory(defines.inventory.crafter_input).insert({ name = item, count = n }) end
        c.get_inventory(defines.inventory.crafter_output).clear()
        remote.call("tt-city", "throttle_tick") -- every 6 ticks is fine: it measures per call
      end, function(samples)
        local t = assert(remote.call("tt-city", "throttle", city))
        assert_.truthy(t.percent >= 40 and t.percent <= 60, "speed " .. t.percent .. "%")
        assert_.equals(samples.other, 0, "not working all the time: " .. serpent.line(samples.statuses))
      end)
    end,
  },
  {
    name = "throttle: given more than it can use, the depot runs at 100%; with nothing, it starves",
    fn = function(ctx)
      local city = depot(X + 3100)
      local per_tick, item = full_rate(city)
      drive(ctx, city, 15, 1, function(c)
        local inv = c.get_inventory(defines.inventory.crafter_input)
        if inv.get_item_count(item) < per_tick * 120 then inv.insert({ name = item, count = math.ceil(per_tick * 60) }) end
        c.get_inventory(defines.inventory.crafter_output).clear()
        remote.call("tt-city", "throttle_tick")
      end, function()
        assert_.equals(assert(remote.call("tt-city", "throttle", city)).percent, 100, "speed with plenty of input")
        drive(ctx, city, 15, 2, function(c)
          c.get_inventory(defines.inventory.crafter_output).clear()
          remote.call("tt-city", "throttle_tick")
        end, function(samples)
          assert_.truthy((samples.statuses["no_ingredients"] or 0) + (samples.statuses["item_ingredient_shortage"] or 0) > 0,
            "not starved: " .. serpent.line(samples.statuses))
        end)
      end)
    end,
  },
  {
    name = "throttle: with its output taken away at half the full rate, the depot runs steadily at about 50%",
    fn = function(ctx)
      local city = depot(X + 3200)
      local per_tick, item = full_rate(city)
      local recipe = prototypes.recipe[assert(city.get_recipe()).name]
      local product = recipe.products[1]
      local out_per_tick = per_tick / recipe.ingredients[1].amount * product.amount
      local owed = 0
      drive(ctx, city, 40, 10, function(c)
        local inv = c.get_inventory(defines.inventory.crafter_input)
        if inv.get_item_count(item) < per_tick * 120 then inv.insert({ name = item, count = math.ceil(per_tick * 60) }) end
        owed = owed + out_per_tick * 6 * 0.5
        local n = math.floor(owed)
        if n > 0 then owed = owed - c.get_inventory(defines.inventory.crafter_output).remove({ name = product.name, count = n }) end
        remote.call("tt-city", "throttle_tick")
      end, function(samples)
        local t = assert(remote.call("tt-city", "throttle", city))
        assert_.truthy(t.percent >= 40 and t.percent <= 60, "speed " .. t.percent .. "%")
        assert_.truthy(samples.other <= 2, "not working all the time: " .. serpent.line(samples.statuses))
      end)
    end,
  },
  {
    name = "throttle: an electric smelting city fed 3.75 ore/s (a quarter of its 15/s) runs steadily at about 25%, unaided",
    fn = function(ctx)
      local x = X + 3300
      h.clear_area({ { x - 16, -16 }, { x + 18, 16 } })
      local city = h.place_city("tt-city-electric-iron-smelting", { x + 0.5, 0.5 })
      h.test_power({ x + 14, 0 }, 20e6)
      h.slow_feed_to_port(city, "iron-ore")
      h.belt_to_port(city, "iron-plate", "output", "fast-transport-belt", 3)
      -- the shown speed over the last 15 s, every 6 ticks (playtest 2.12: it jumped about).
      -- 2.15.7: a craft takes 2.7 s at 50% here, so it settles slower than a fast city: it
      -- swings 40-60% for about 50 s after an empty start, then holds 50%. Playtest 2.15.10:
      -- on some start ticks it keeps stepping one 5% step either side of 50% (45-55%), so it
      -- gets 120 s and may change up to 5 times in the last 15 s, within 10%. Since smelting
      -- went back to 15/s (playtest 2.15.10) the same feed is a quarter: about 25%.
      local seen, changes, last = {}, 0, nil
      local ticks = 0
      drive(ctx, city, 135, 15, function(c)
        ticks = ticks + 6
        if ticks > 120 * 60 then
          local pct = assert(remote.call("tt-city", "throttle", c)).percent
          seen[#seen + 1] = pct
          if last and pct ~= last then changes = changes + 1 end
          last = pct
        end
      end, function(samples)
        local t = assert(remote.call("tt-city", "throttle", city))
        assert_.truthy(t.percent >= 20 and t.percent <= 35, "speed " .. t.percent .. "%")
        assert_.truthy(samples.other <= 2, "not working all the time: " .. serpent.line(samples.statuses))
        local lo, hi = math.huge, -math.huge
        for _, v in ipairs(seen) do lo, hi = math.min(lo, v), math.max(hi, v) end
        assert_.truthy(changes <= 5 and hi - lo <= 10,
          string.format("speed not calm over 15 s: %d changes, %d-%d%%", changes, lo, hi))
      end)
    end,
  },
  {
    name = "throttle: the research complex slows a step a second while short of packs, and speeds up with plenty",
    fn = function()
      local force = game.forces["player"]
      local tech
      for name, t in pairs(force.technologies) do
        local ings = t.research_unit_ingredients
        if t.enabled and not t.researched and #ings == 1 and ings[1].name == "automation-science-pack" then
          local ready = true
          for _, pre in pairs(t.prerequisites) do if not pre.researched then ready = false end end
          if ready then tech = name break end
        end
      end
      assert(tech, "no red-only technology to research")
      local x = X + 3400
      h.clear_area({ { x - 12, -12 }, { x + 14, 12 } })
      local city = h.place_city("tt-city-research", { x + 0.5, 0.5 })
      force.cancel_current_research()
      force.add_research(tech)
      for _ = 1, 5 do remote.call("tt-city", "throttle_tick") end
      assert_.equals(assert(remote.call("tt-city", "throttle", city)).steps, 5, "steps while short of packs")
      city.insert({ name = "automation-science-pack", count = 50 })
      for _ = 1, 5 do remote.call("tt-city", "throttle_tick") end
      assert_.equals(assert(remote.call("tt-city", "throttle", city)).steps, 0, "steps with plenty of packs")
      force.cancel_current_research()
    end,
  },
  {
    name = "throttle: the window says Running at 60% and the stock point sends city speed 60",
    fn = function(ctx)
      local x = X + 3500
      local city = depot(x)
      local per_tick, item = full_rate(city)
      city.get_inventory(defines.inventory.crafter_input).insert({ name = item, count = math.ceil(per_tick * 600) })
      remote.call("tt-city", "throttle_set", city, 8)
      local pole = h.create("medium-electric-pole", { x + 0.5, 11.5 })
      local point = remote.call("tt-city", "signal_points", city).stock
      point.get_wire_connector(defines.wire_connector_id.circuit_red, true)
        .connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
      ctx:wait(30, function()
        local p = assert(game.players[1])
        remote.call("tt-city", "open_gui", p.index, city)
        local status = assert(p.gui.screen["tt_city_frame"])["body"]["status"]
        assert_.equals(status.caption[1], "tt-gui.city-status-running-at")
        assert_.equals(status.caption[2], "60")
        -- the window's max is the full rate, not the throttled one (playtest 2.12)
        local per_tick = full_rate(city)
        local info = remote.call("tt-city", "info", city)
        assert_.truthy(math.abs(info.recipe.ingredients[1].per_min_max - per_tick * 3600) < 1e-6,
          "max per minute " .. info.recipe.ingredients[1].per_min_max .. ", full rate " .. per_tick * 3600)
        p.opened = nil
        remote.call("tt-city", "signals_tick")
        ctx:wait(1, function()
          local net = assert(pole.get_circuit_network(defines.wire_connector_id.circuit_red))
          assert_.equals(net.get_signal({ type = "virtual", name = "tt-city-speed", quality = "normal" }), 60, "speed signal")
          assert_.equals(net.get_signal({ type = "virtual", name = "tt-city-running", quality = "normal" }), 1, "running signal")
        end)
      end)
    end,
  },
}
