-- 2.2.4: research gating. The red/green part of the tech tree can be completed with the
-- research complex; trigger technologies the player can't meet yet are known and listed.
local assert_ = require("__train-tycoon-tests__/assert")

local RED_GREEN = { ["automation-science-pack"] = true, ["logistic-science-pack"] = true }
-- Trigger techs inside the red/green zone that wait for later content (DECISIONS 2.2.4).
local WAITING = { ["steel-axe"] = "a steel city", ["oil-processing"] = "crude oil on the map" }

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
          if t.prototype.research_trigger then
            triggers[n] = true
          else
            local ok = #t.research_unit_ingredients > 0
            for _, i in ipairs(t.research_unit_ingredients) do ok = ok and RED_GREEN[i.name] end
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
    name = "gating: the red/green tree is reachable and unlocks the free logistics upgrades",
    fn = function()
      local force = game.forces["player"]
      local reach = reachable(force)
      for _, tech in ipairs({ "automation", "fast-inserter", "logistics-2", "circuit-network",
        "steel-processing", "logistic-science-pack", "toolbelt", "lamp" }) do
        assert_.truthy(reach[tech], tech .. " is not reachable")
      end
    end,
  },
  {
    name = "gating: only the known trigger technologies block the red/green zone",
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
