-- 2.6: uranium and the nuclear power city.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local X = 11000

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
}
