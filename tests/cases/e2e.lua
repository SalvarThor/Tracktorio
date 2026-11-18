-- 1.9: end to end. A train hauls ore and coal to the iron smelting city, carries the plates
-- to the goal box, and the goal box counts them and reports a rate.
--
-- Geometry (verified by a calibration run, 2.1.24): straight rails on odd coordinates, rail
-- centre y = Y + 1. Train = loco(E) + cargo wagon + loco(W). An eastbound stop sits 2 tiles
-- south of the rail centre and the wagon stops 10 tiles behind it; a westbound stop sits
-- 2 tiles north and the wagon stops 10 tiles past it. The wagon spans x +-3 and y Y..Y+2.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local E, W, N, S = defines.direction.east, defines.direction.west, defines.direction.north, defines.direction.south
local Y = 200
local IRON = "tt-city-iron-smelting"

--- Test-only power: an electric-energy-interface producing power, under a substation.
local function power(sub_pos, eei_pos)
  local eei = h.create("electric-energy-interface", eei_pos)
  eei.power_production = 1e6 / 60
  eei.power_usage = 0
  eei.electric_buffer_size = 1e6
  h.create("substation", sub_pos)
end

local function inserter(x, y, dir, filter)
  local ins = h.create("fast-inserter", { x, y }, { direction = dir })
  if filter then
    ins.use_filters = true
    ins.set_filter(1, { name = filter })
  end
  return ins
end

local function stop(name, x, dir, dy)
  local st = h.create("train-stop", { x, Y + dy }, { direction = dir })
  st.backer_name = name
  return st
end

local function wait_cond(c) return { c } end

return {
  {
    name = "e2e: train hauls ore and coal to a smelting city and plates to the goal box",
    fn = function(ctx)
      h.clear_area({ { 1990, Y - 14 }, { 2310, Y + 16 } })
      for x = 2000, 2300, 2 do h.create("straight-rail", { x, Y }, { direction = E }) end

      -- A (westbound, x 2021): load 100 ore and 10 coal. Wagon at x 2031 (2028..2034).
      stop("tt-e2e-A", 2020, W, -2)
      power({ 2026, Y - 4 }, { 2022, Y - 4 })
      local ore1 = h.create("iron-chest", { 2029.5, Y - 1.5 }); ore1.insert({ name = "iron-ore", count = 50 })
      local ore2 = h.create("iron-chest", { 2030.5, Y - 1.5 }); ore2.insert({ name = "iron-ore", count = 50 })
      local coal = h.create("iron-chest", { 2031.5, Y - 1.5 }); coal.insert({ name = "coal", count = 10 })
      for _, x in ipairs({ 2029.5, 2030.5, 2031.5 }) do inserter(x, Y - 0.5, N) end

      -- B (eastbound, x 2151): city south of the wagon (x 2141). Feed in, plates out.
      stop("tt-e2e-B", 2150, E, 2)
      local city = h.place_city(IRON, { 2141.5, Y + 7.5 })
      power({ 2134, Y + 6 }, { 2130, Y + 9 })
      for _, x in ipairs({ 2138.5, 2139.5, 2140.5 }) do inserter(x, Y + 2.5, N) end
      for _, x in ipairs({ 2141.5, 2142.5 }) do inserter(x, Y + 2.5, S) end

      -- C (eastbound, x 2281): goal box south of the wagon (x 2271); unload plates only.
      stop("tt-e2e-C", 2280, E, 2)
      h.place_city("tt-city-goal", { 2271.5, Y + 7.5 })
      power({ 2264, Y + 6 }, { 2260, Y + 9 })
      for _, x in ipairs({ 2268.5, 2269.5, 2270.5, 2271.5, 2272.5 }) do inserter(x, Y + 2.5, N, "iron-plate") end

      -- The train, hand-fuelled with coal fuel.
      local l1 = h.create("locomotive", { 2100, Y }, { direction = E, raise_built = true })
      h.create("cargo-wagon", { 2093, Y }, { direction = E })
      local l2 = h.create("locomotive", { 2086, Y }, { direction = W, raise_built = true })
      for _, l in ipairs({ l1, l2 }) do assert(l.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 10 }) end

      local train = assert(l1.train)
      local schedule = train.get_schedule()
      schedule.add_record({ station = "tt-e2e-A", wait_conditions = wait_cond(
        { type = "inactivity", compare_type = "and", ticks = 180 }) })
      schedule.add_record({ station = "tt-e2e-B", wait_conditions = wait_cond(
        { type = "item_count", compare_type = "and",
          condition = { first_signal = { type = "item", name = "iron-plate" }, comparator = ">=", constant = 100 } }) })
      schedule.add_record({ station = "tt-e2e-C", wait_conditions = wait_cond(
        { type = "inactivity", compare_type = "and", ticks = 180 }) })
      schedule.go_to_station(1)

      local before = remote.call("tt-goal", "status").delivered.iron
      local wagon = train.cargo_wagons[1]
      ctx:wait_until(function()
        if game.tick % 600 == 0 then
          local st = train.state
          for k, v in pairs(defines.train_state) do if v == st then st = k end end
          log(string.format("tt-e2e trace t=%d state=%s station=%s wagon=%s city=%s cargo=%s",
            game.tick, tostring(st), train.station and train.station.backer_name or "-",
            serpent.line(wagon.position), h.status_name(city),
            serpent.line(assert(wagon.get_inventory(defines.inventory.cargo_wagon)).get_contents())))
        end
        return remote.call("tt-goal", "status").delivered.iron >= before + 100
      end, 60 * 300, function()
        local s = remote.call("tt-goal", "status")
        assert_.truthy(s.rates.iron > 0, "goal rate not registered")
        assert_.truthy(city.products_finished >= 10, "city crafts " .. city.products_finished)
        assert_.equals(ore1.get_item_count() + ore2.get_item_count() + coal.get_item_count(), 0, "station A not emptied")
        assert_.falsy(remote.call("tt-limp", "is_limping", l1), "train ran out of fuel")
        log(string.format("tt-e2e: delivered %d iron at tick %d, rate %.1f/min",
          s.delivered.iron - before, game.tick, s.rates.iron))
      end)
    end,
  },
}
