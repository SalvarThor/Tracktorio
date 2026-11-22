-- 2.7: elevated rails (Space Age), unlocked by red/green/blue research.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local X = 12000
local E, W, N = defines.direction.east, defines.direction.west, defines.direction.north
local LIMP_MAX = 1.2 * require("__tracktorio__/shared/config").LIMP_TOP_SPEED

--- A line that climbs over a crossing ground line, at x0 (rails created at y = 0, centre
--- y = 1; geometry from a calibration probe, 2.1.24):
---   ground rails x0..x0+60 -> ramp up (centre x0+70; ground end +62, elevated end +78)
---   -> elevated rails +78..+122 over a north-south ground line at x0+100
---   -> ramp down (centre x0+130; elevated end +122, ground end +138) -> ground rails to
---   x0+200, with an eastbound stop at x0+190. Supports stand clear of the crossing.
--- Returns the stop and a locomotive near the start (no fuel).
local function overpass(x0, stop_name)
  h.clear_area({ { x0 - 4, -24 }, { x0 + 204, 24 } })
  for x = x0, x0 + 60, 2 do h.create("straight-rail", { x, 0 }, { direction = E }) end
  h.create("rail-ramp", { x0 + 70, 0 }, { direction = E })
  for x = x0 + 78, x0 + 120, 2 do h.create("elevated-straight-rail", { x, 0 }, { direction = E }) end
  h.create("rail-ramp", { x0 + 130, 0 }, { direction = W })
  for x = x0 + 138, x0 + 200, 2 do h.create("straight-rail", { x, 0 }, { direction = E }) end
  for x = x0 + 86, x0 + 116, 8 do
    if math.abs(x - (x0 + 101)) > 4 then h.create("rail-support", { x, 0 }, { direction = E }) end
  end
  for y = -20, 20, 2 do h.create("straight-rail", { x0 + 100, y }, { direction = N }) end
  local stop = h.create("train-stop", { x0 + 190, 2 }, { direction = E })
  stop.backer_name = stop_name
  local loco = h.create("locomotive", { x0 + 10, 0 }, { direction = E, raise_built = true })
  return stop, loco
end

--- Is the train's front on elevated track? (LuaEntity.rail_layer is for signals only; 2.1
--- elevated rails and ramps-at-height have their own types, "elevated-...".)
local function on_elevated(train)
  local rail = train and train.front_end and train.front_end.rail
  return rail ~= nil and string.find(rail.type, "^elevated%-") ~= nil
end

--- Send the train to the stop and watch it: calls back with (arrived, went_elevated, max
--- speed seen while elevated).
local function drive(ctx, loco, stop_name, max_ticks, done)
  local train = assert(loco.train)
  local schedule = train.get_schedule()
  schedule.add_record({ station = stop_name, wait_conditions = { { type = "time", compare_type = "and", ticks = 600 } } })
  schedule.go_to_station(1)
  train.manual_mode = false
  local elevated, top = false, 0
  ctx:wait_until(function()
    local t = loco.train
    if not t then return false end
    if on_elevated(t) then
      elevated = true
      top = math.max(top, math.abs(t.speed))
    end
    return t.state == defines.train_state.wait_station
  end, max_ticks, function()
    done(loco.train.state == defines.train_state.wait_station, elevated, top)
  end)
end

--- Run fn with Elevated rail researched, then put it back.
local function with_research(fn)
  local tech = game.forces["player"].technologies["elevated-rail"]
  local was = tech.researched
  tech.researched = true
  local ok, err = pcall(fn)
  tech.researched = was
  if not ok then error(err, 0) end
end

return {
  {
    name = "elevated: ramps and supports are locked before Elevated rail, then free and hand-craftable",
    fn = function()
      local force = game.forces["player"]
      assert_.falsy(force.technologies["elevated-rail"].researched, "researched at the start")
      for _, name in ipairs({ "rail-ramp", "rail-support" }) do
        assert_.falsy(force.recipes[name].enabled, name .. " unlocked at the start")
      end
      assert_.falsy(force.rail_planner_allow_elevated_rails, "elevated building allowed at the start")
      with_research(function()
        assert_.truthy(force.rail_planner_allow_elevated_rails, "elevated building not allowed")
        local p = assert(game.players[1])
        p.get_main_inventory().clear()
        for _, name in ipairs({ "rail-ramp", "rail-support" }) do
          local r = force.recipes[name]
          assert_.truthy(r.enabled, name .. " not unlocked")
          assert_.equals(#r.ingredients, 0, name .. " ingredients")
          assert_.equals(r.prototype.categories[1], "tt-free", name .. " category")
          assert_.truthy(p.get_craftable_count(name) > 0, name .. " not hand-craftable")
        end
      end)
    end,
  },
  {
    name = "elevated: the elevated rails and signals use the free rail and signal items",
    fn = function()
      for entity, item in pairs({
        ["elevated-straight-rail"] = "rail",
        ["elevated-curved-rail-a"] = "rail",
        ["elevated-half-diagonal-rail"] = "rail",
        ["rail-signal"] = "rail-signal",
        ["rail-chain-signal"] = "rail-signal",
      }) do
        local p = assert(prototypes.entity[entity], entity)
        local items = p.items_to_place_this or {}
        local found = false
        for _, i in ipairs(items) do if i.name == item or (item == "rail-signal" and i.name == entity) then found = true end end
        assert_.truthy(found, entity .. " placed by " .. serpent.line(items))
      end
      for _, item in ipairs({ "rail", "rail-signal", "rail-chain-signal" }) do
        local r = prototypes.recipe[item]
        assert_.equals(#r.ingredients, 0, item .. " ingredients")
      end
    end,
  },
  {
    -- 2.7.2: supports stand on water (not deep oil ocean, which isn't on this map), so
    -- elevated track can cross the lakes.
    name = "elevated: rail supports can stand in water and deep water (ground rail cannot)",
    fn = function()
      local s = h.surface()
      h.clear_area({ { X - 10, -10 }, { X + 10, 10 } })
      local tiles = {}
      for x = X - 8, X + 7 do
        for y = -8, 7 do tiles[#tiles + 1] = { name = x < X and "water" or "deepwater", position = { x, y } } end
      end
      s.set_tiles(tiles)
      for _, spot in ipairs({ { X - 4, 0, "water" }, { X + 4, 0, "deepwater" } }) do
        assert_.equals(s.get_tile(spot[1], spot[2]).name, spot[3])
        assert_.truthy(s.can_place_entity({ name = "rail-support", position = { spot[1], spot[2] }, force = "player" }),
          "rail support refused on " .. spot[3])
      end
      assert_.falsy(s.can_place_entity({ name = "straight-rail", position = { X + 4, 0 }, force = "player" }),
        "ground rail allowed on deep water")
      local fill = {}
      for x = X - 8, X + 7 do for y = -8, 7 do fill[#fill + 1] = { name = "grass-1", position = { x, y } } end end
      s.set_tiles(fill)
    end,
  },
  {
    -- 2.7.3
    name = "elevated: a train drives up a ramp, over a ground line and down to a stop",
    fn = function(ctx)
      local stop, loco = overpass(X + 100, "tt-elevated-A")
      assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 10 })
      local crossing = h.surface().find_entities_filtered({ name = "straight-rail", position = { X + 201, 1 }, radius = 1.5 })
      assert_.truthy(#crossing >= 1, "no ground line under the overpass")
      drive(ctx, loco, "tt-elevated-A", 60 * 60, function(arrived, elevated)
        assert_.truthy(elevated, "the train never ran on elevated track")
        assert_.truthy(arrived, "the train did not reach the stop")
        assert_.truthy(math.abs(loco.position.x - stop.position.x) < 12, "stopped at x " .. loco.position.x)
      end)
    end,
  },
  {
    -- 2.7.4
    name = "elevated: a fuel-empty train limps over the overpass, slowly, and still arrives",
    fn = function(ctx)
      local _, loco = overpass(X + 400, "tt-elevated-B")
      remote.call("tt-limp", "check_all")
      assert_.truthy(remote.call("tt-limp", "is_limping", loco), "not limping")
      drive(ctx, loco, "tt-elevated-B", 60 * 60 * 3, function(arrived, elevated, top)
        assert_.truthy(elevated, "never on elevated track")
        assert_.truthy(top <= LIMP_MAX + 0.0001, "too fast on elevated track: " .. top)
        assert_.truthy(arrived, "the limping train did not arrive")
      end)
    end,
  },
}
