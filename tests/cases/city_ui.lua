-- 1.6: city UI data (recipe, rate, status) and the detail window.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local IRON = "tt-city-iron-smelting"

local function info(city) return remote.call("tt-city", "info", city) end

local function contains(list, value)
  for _, v in ipairs(list or {}) do if v == value then return true end end
  return false
end

return {
  {
    name = "city ui: recipe lists inputs, outputs and max rates",
    fn = function()
      h.clear_area({ { 990, -10 }, { 1010, 10 } })
      local city = h.place_city(IRON, { 1000.5, 0.5 })
      local i = info(city)
      assert_.equals(#i.recipe.ingredients, 2, "ingredient count")
      assert_.equals(i.recipe.products[1].name, "iron-plate")
      assert_.equals(i.recipe.products[1].amount, 10)
      -- 10 plates per 1 s cycle at speed 1.5 -> 900/min max
      assert_.equals(math.floor(i.recipe.products[1].per_min_max + 0.5), 900)
    end,
  },
  {
    name = "city ui: starved status names the missing input",
    fn = function(ctx)
      local city = h.city_rig(IRON, 1040, { { name = "iron-ore", count = 100 } }, false)
      ctx:wait(60 * 5, function()
        local i = info(city)
        assert_.equals(i.status, "starved")
        assert_.truthy(contains(i.missing, "coal"), "missing " .. serpent.line(i.missing))
        assert_.falsy(contains(i.missing, "iron-ore"), "ore reported missing")
      end)
    end,
  },
  {
    name = "city ui: running status and a measured output rate",
    fn = function(ctx)
      local city = h.city_rig(IRON, 1080,
        { { name = "iron-ore", count = 200 }, { name = "coal", count = 50 } }, true)
      ctx:wait_until(function() return city.products_finished >= 2 end, 60 * 60, function()
        ctx:wait(60 * 5, function()
          local i = info(city)
          assert_.truthy(i.status == "running" or i.status == "starved", "status " .. i.status)
          assert_.truthy(i.recipe.products[1].per_min > 0, "rate " .. i.recipe.products[1].per_min)
        end)
      end)
    end,
  },
  {
    name = "city ui: output full status",
    fn = function(ctx)
      local city = h.city_rig(IRON, 1120, {}, false)
      city.insert({ name = "iron-ore", count = 200 })
      city.insert({ name = "coal", count = 20 })
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 60, function()
        -- 2.4.2: the status names what is full
        assert_.truthy(contains(info(city).full, "iron-plate"), "full " .. serpent.line(info(city).full))
      end)
    end,
  },
  {
    name = "city ui: the window says where each fluid connects (power city: water in, top right)",
    fn = function()
      h.clear_area({ { 1310, -12 }, { 1330, 12 } })
      local city = h.place_city("tt-city-power", { 1320.5, 0.5 })
      local c = info(city).connections
      assert_.equals(#c, 1, "connections " .. serpent.line(c))
      assert_.equals(c[1].kind, "input")
      assert_.equals(c[1].fluid, "water")
      assert_.equals(c[1].side, "north") -- 2.10 port layout: coal north-left, water north-right
      assert_.equals(c[1].offset, 2.5)
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, city)
      local line = assert(p.gui.screen["tt_city_frame"])["body"]["pipe-1"]
      assert_.truthy(line, "no pipe line in the window")
      assert_.equals(line.caption[1], "tt-gui.city-pipe-line")
      assert_.equals(line.caption[4][1], "tt-gui.city-pipe-pos-north-b") -- "top right" (playtest 2.4.6)
      p.opened = nil
    end,
  },
  {
    name = "city ui: a city with a fluid input reports it missing and its window opens",
    fn = function(ctx)
      -- regression (playtest round 2): clicking the power city crashed on LuaEntity.fluidbox
      h.clear_area({ { 1190, -10 }, { 1210, 10 } })
      local city = h.place_city("tt-city-power", { 1200.5, 0.5 })
      city.insert({ name = "coal", count = 10 })
      ctx:wait(60, function()
        local i = info(city)
        assert_.equals(i.status, "starved")
        assert_.truthy(contains(i.missing, "water"), "missing " .. serpent.line(i.missing))
        local p = assert(game.players[1])
        remote.call("tt-city", "open_gui", p.index, city)
        assert_.truthy(p.gui.screen["tt_city_frame"], "window not open")
        p.opened = nil
      end)
    end,
  },
  {
    name = "city ui: the window starts with the city's description",
    fn = function()
      h.clear_area({ { 1230, -10 }, { 1250, 10 } })
      local city = h.place_city("tt-city-depot", { 1240.5, 0.5 })
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, city)
      local body = assert(p.gui.screen["tt_city_frame"])["body"]
      local first = body.children[1].caption
      -- the window shows the description without the tooltip's "click it" hint (playtest 2.2.8)
      assert_.equals(type(first) == "table" and first[1], "tt-city-description.tt-city-depot")
      local tooltip = prototypes.entity["tt-city-depot"].localised_description
      assert_.equals(type(tooltip) == "table" and tooltip[1], "tt-gui.click-hint")
      p.opened = nil
    end,
  },
  {
    name = "city ui: an idle power city says no power demand, not output full",
    fn = function(ctx)
      h.clear_area({ { 1270, -12 }, { 1296, 14 } })
      local city = h.place_city("tt-city-power", { 1280.5, 0.5 })
      city.insert({ name = "coal", count = 20 })
      h.pipe_at(city, "water", "input", true)
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 60, function()
        local p = assert(game.players[1])
        remote.call("tt-city", "open_gui", p.index, city)
        local status = assert(p.gui.screen["tt_city_frame"])["body"]["status"]
        assert_.equals(status.caption[1], "tt-gui.city-status-power-idle")
        p.opened = nil
      end)
    end,
  },
  {
    name = "city ui: a depot on too little power reports low power",
    fn = function(ctx)
      local city = h.city_rig("tt-city-depot", 3100, {}, false)
      city.insert({ name = "coal", count = 40 }) -- crafts continuously, so demand is steady
      h.test_power({ 3107, 0 }, 300000, 1) -- hard 300 kW cap against an 840 kW demand
      ctx:wait(60 * 10, function()
        assert_.equals(info(city).status, "low_power")
        assert_.truthy(city.products_finished > 0, "made nothing on low power")
      end)
    end,
  },
  {
    name = "city ui: the goal box has a window with progress per metal",
    fn = function()
      h.clear_area({ { 1310, -10 }, { 1330, 10 } })
      local box = h.place_city("tt-city-goal", { 1320.5, 0.5 })
      assert_.truthy(remote.call("tt-city", "has_window", box), "goal box has no window")
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, box)
      local body = assert(p.gui.screen["tt_city_frame"])["body"]
      assert_.truthy(body["status"], "no status line")
      assert_.truthy(#body.children >= 5, "rows " .. #body.children) -- description, line, status, 2 metals
      p.opened = nil
    end,
  },
  {
    name = "city ui: detail window opens, refreshes and closes",
    fn = function(ctx)
      h.clear_area({ { 1150, -10 }, { 1170, 10 } })
      local city = h.place_city(IRON, { 1160.5, 0.5 })
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, city)
      local frame = p.gui.screen["tt_city_frame"]
      assert_.truthy(frame, "window not open")
      ---@cast frame LuaGuiElement
      assert_.truthy(frame["body"]["status"], "no status line")
      ctx:wait(61, function()
        assert_.truthy(frame.valid, "window closed by refresh")
        p.opened = nil -- closing raises on_gui_closed
        ctx:wait(1, function()
          assert_.falsy(p.gui.screen["tt_city_frame"], "window still open")
        end)
      end)
    end,
  },
}
