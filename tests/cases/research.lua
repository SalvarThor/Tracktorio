-- 2.2.3: the research complex, a lab-type city; the engine runs research.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

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
    name = "research: the complex is a lab taking red, green and blue, 10 labs, 0.6 MW (half of 20, 2.15.7)",
    fn = function()
      local name = "tt-city-research"
      local p = assert(prototypes.entity[name], "missing " .. name)
      assert_.equals(p.type, "lab")
      assert_.equals(p.get_researching_speed(), 10)
      local w = p.get_max_energy_usage() * 60
      assert_.truthy(math.abs(w - 0.6e6) < 1000, name .. " draws " .. w)
      local inputs = {}
      for _, i in ipairs(p.lab_inputs) do inputs[i] = true end
      assert_.truthy(inputs[RED] and inputs[GREEN] and inputs["chemical-science-pack"] and #p.lab_inputs == 3, name .. " inputs")
      assert_.truthy(prototypes.item["tt-city-research"], "the complex has no item (2.15)")
    end,
  },
  {
    name = "research: protected; window says no research selected",
    fn = function(ctx)
      local force = game.forces["player"]
      force.cancel_current_research()
      local city = complex(X)
      assert_.falsy(city.operable)
      assert_.truthy(city.minable_flag) -- 2.15: removable
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
}
