-- Deliberately failing tests. They run only with run-tests.ps1 -SelfTest and must all be
-- reported as FAILED, while the passing one must still pass.
local assert_ = require("__train-tycoon-tests__/assert")

return {
  {
    name = "selftest: passing test still passes",
    fn = function() assert_.equals("a", "a") end,
  },
  {
    name = "selftest: failing assertion is reported",
    fn = function() assert_.equals(1 + 1, 3, "deliberate failure") end,
  },
  {
    name = "selftest: runtime error is reported",
    fn = function()
      local t = nil
      ---@diagnostic disable-next-line: need-check-nil, undefined-field
      return t.field
    end,
  },
  {
    name = "selftest: failure inside wait is reported",
    fn = function(ctx)
      ctx:wait(5, function() error("deliberate error after wait") end)
    end,
  },
  {
    name = "selftest: wait_until timeout is reported",
    fn = function(ctx)
      ctx:wait_until(function() return false end, 30, function() end)
    end,
  },
}
