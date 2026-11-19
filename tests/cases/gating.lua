-- 2.2.4 / 2.5.5: research gating. The part of the tech tree that needs only the packs the
-- research complex takes (red, green, blue) can be completed; trigger technologies the
-- player can't meet yet are known and listed.
local assert_ = require("__train-tycoon-tests__/assert")

--- Packs the research complex takes (read from its prototype).
local function complex_packs()
  local out = {}
  for _, p in ipairs(prototypes.entity["tt-city-research"].lab_inputs) do out[p] = true end
  return out
end
local ZONE = complex_packs()
-- Trigger techs the player can now meet in game (each proven by its own test):
local MET = {
  ["oil-processing"] = "a pumpjack on the oil field (oil test)",
  ["steel-axe"] = "50 steel from a steel city (chain test)",
}
-- Trigger techs inside the zone that still wait for later content.
local WAITING = {}

--- Closure of technologies the research complex can reach from the current state.
---@param force LuaForce
local function reachable(force)
  local reach, triggers, packs = {}, {}, {}
  for n, t in pairs(force.technologies) do if t.researched then reach[n] = true end end
  local changed = true
  while changed do
    changed = false
    for n, t in pairs(force.technologies) do
      if not reach[n] and t.enabled and not t.prototype.hidden then
        local pre = true
        for p in pairs(t.prerequisites) do pre = pre and reach[p] end
        if pre then
          if t.prototype.research_trigger and MET[n] then
            reach[n] = true; changed = true
          elseif t.prototype.research_trigger then
            triggers[n] = true
          else
            local ok = #t.research_unit_ingredients > 0
            for _, i in ipairs(t.research_unit_ingredients) do ok = ok and ZONE[i.name] end
            if ok then reach[n] = true; changed = true else packs[n] = true end
          end
        end
      end
    end
  end
  return reach, triggers, packs
end

return {
  {
    name = "gating: the red/green/blue tree is reachable and unlocks the free logistics upgrades",
    fn = function()
      local force = game.forces["player"]
      local reach = reachable(force)
      for _, tech in ipairs({ "automation", "fast-inserter", "logistics-2", "circuit-network",
        "steel-processing", "logistic-science-pack", "toolbelt", "lamp",
        -- blue (2.5.5)
        "chemical-science-pack", "bulk-inserter", "electric-energy-distribution-2" }) do
        assert_.truthy(reach[tech], tech .. " is not reachable")
      end
    end,
  },
  {
    name = "gating: only the known trigger technologies block the red/green/blue zone",
    fn = function()
      local _, triggers = reachable(game.forces["player"])
      for n in pairs(triggers) do
        assert_.truthy(WAITING[n], "unexpected trigger blocker: " .. n)
      end
      assert_.falsy(game.forces["player"].technologies["automation-science-pack"].prototype.hidden)
      assert_.truthy(game.forces["player"].technologies["automation-science-pack"].researched,
        "the lab-crafting trigger tech must start researched")
    end,
  },
  {
    name = "gating: technologies needing other packs stay visible and locked",
    fn = function()
      local force = game.forces["player"]
      local _, _, packs = reachable(force)
      assert_.truthy(next(packs), "expected techs needing packs the complex doesn't take")
      for n in pairs(packs) do
        local t = force.technologies[n]
        assert_.falsy(t.researched, n .. " researched")
        assert_.falsy(t.prototype.hidden, n .. " hidden")
      end
    end,
  },
  {
    name = "gating: the complex says it can't research a tech needing other packs",
    fn = function(ctx)
      local force = game.forces["player"]
      local _, _, packs = reachable(force)
      local tech = assert(next(packs))
      local city = remote.call("tt-city", "place", "tt-city-research", 1, { 5200.5, 0.5 })
      force.cancel_current_research()
      -- Its prerequisites are reachable but not done on a fresh map: mark them done for the
      -- check and undo that afterwards.
      local changed = {}
      for name, pre in pairs(force.technologies[tech].prerequisites) do
        if not pre.researched then pre.researched = true; changed[#changed + 1] = name end
      end
      force.add_research(tech)
      ctx:wait(2, function()
        local cur = force.current_research
        assert_.truthy(cur, "no current research after add_research(" .. tech .. ")")
        local i = remote.call("tt-city", "info", city)
        assert_.truthy(i.unsupported and #i.unsupported > 0, "no unsupported packs for " .. cur.name)
        force.cancel_current_research()
        for _, name in ipairs(changed) do force.technologies[name].researched = false end
        city.destroy()
      end)
    end,
  },
}
