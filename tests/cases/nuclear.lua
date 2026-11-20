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
}
