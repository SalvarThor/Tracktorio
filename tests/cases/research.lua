-- 2.2.3: the research complex, a lab-type city; the engine runs research.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local X = 5000
local RED, GREEN = "automation-science-pack", "logistic-science-pack"

local function info(city) return remote.call("tt-city", "info", city) end

--- A technology that is not researched, has its prerequisites done, and needs only red.
local function red_only_tech(force)
  for name, tech in pairs(force.technologies) do
    if tech.enabled and not tech.researched and not tech.prototype.hidden and tech.research_unit_count_formula == nil then
      local ok = #tech.research_unit_ingredients == 1 and tech.research_unit_ingredients[1].name == RED
      for _, pre in pairs(tech.prerequisites) do ok = ok and pre.researched end
      if ok and tech.prototype.research_trigger == nil then return name end
    end
  end
end

local function complex(x)
  h.clear_area({ { x - 12, -12 }, { x + 22, 14 } })
  local city = h.place_city("tt-city-research", { x + 0.5, 0.5 })
  return city
end

return {
  {
    name = "research: the complex is a lab taking red and green, 20/40/80 labs, 1.2/2.4/4.8 MW",
    fn = function()
      for tier, f in ipairs({ 1, 2, 4 }) do
        local name = tier == 1 and "tt-city-research" or ("tt-city-research-t" .. tier)
        local p = assert(prototypes.entity[name], "missing " .. name)
        assert_.equals(p.type, "lab")
        assert_.equals(p.get_researching_speed(), 20 * f)
        local w = p.get_max_energy_usage() * 60
        assert_.truthy(math.abs(w - 1.2e6 * f) < 1000, name .. " draws " .. w)
        local inputs = {}
        for _, i in ipairs(p.lab_inputs) do inputs[i] = true end
        assert_.truthy(inputs[RED] and inputs[GREEN] and #p.lab_inputs == 2, name .. " inputs")
      end
      assert_.falsy(prototypes.item["tt-city-research"], "the complex has an item")
    end,
  },
  {
    name = "research: protected; window says no research selected",
    fn = function(ctx)
      local force = game.forces["player"]
      force.cancel_current_research()
      local city = complex(X)
      assert_.falsy(city.operable)
      assert_.falsy(city.minable_flag)
      assert_.falsy(city.destructible)
      h.test_power({ X + 8.5, 0.5 }, 3e6)
      ctx:wait(10, function()
        local p = assert(game.players[1])
        remote.call("tt-city", "open_gui", p.index, city)
        local status = assert(p.gui.screen["tt_city_frame"])["body"]["status"]
        assert_.equals(status.caption[1], "tt-gui.lab-status-no-research")
        p.opened = nil
      end)
    end,
  },
  {
    name = "research: red packs fed to a powered complex research a red-only technology",
    fn = function(ctx)
      local force = game.forces["player"]
      local tech = assert(red_only_tech(force), "no red-only technology available")
      local city = complex(X + 40)
      h.test_power({ X + 48.5, 0.5 }, 3e6)
      force.cancel_current_research()
      force.add_research(tech)
      assert_.equals(force.current_research and force.current_research.name, tech)
      ctx:wait(10, function()
        local i = info(city)
        assert_.equals(i.status, "missing_packs")
        assert_.equals(i.missing[1], RED)
        assert_.equals(i.research, tech)
        city.insert({ name = RED, count = 200 })
        ctx:wait_until(function() return force.technologies[tech].researched end, 60 * 120, function()
          assert_.truthy(force.technologies[tech].researched)
        end)
      end)
    end,
  },
  {
    name = "research: upgrading the complex keeps its packs",
    fn = function()
      local city = complex(X + 80)
      city.insert({ name = RED, count = 50 })
      city.insert({ name = GREEN, count = 30 })
      local t2 = assert(remote.call("tt-city", "upgrade_now", city))
      assert_.equals(t2.name, "tt-city-research-t2")
      local inv = assert(t2.get_inventory(defines.inventory.lab_input))
      assert_.equals(inv.get_item_count(RED), 50)
      assert_.equals(inv.get_item_count(GREEN), 30)
      local i = info(t2)
      assert_.equals(i.lab.speed, 40)
    end,
  },
}
