-- In-game test runner for --test-scenario (Factorio 2.1.24+).
--
-- --test-arg is "key=value;key=value":
--   run=<id>        echoed into the results file so the caller can reject stale results
--   filter=<text>   only run tests whose name contains <text> (plain match)
--   selftest=1      also run the deliberately failing selftest cases
--
-- Results go to script-output/tt-test-results.json; then script.finish_test(all_passed).
-- This file runs in the scenario's Lua state, which is never saved or loaded in test mode,
-- so plain locals are fine here. Do not copy this pattern into the mod.

local index = require("__train-tycoon-tests__/cases/index")

local RESULTS_FILE = "tt-test-results.json"

-- require() only works at load time, so load every test file now and filter later.
local files = {}
for _, group in ipairs({ "normal", "selftest" }) do
  for _, path in ipairs(index[group] or {}) do
    files[#files + 1] = { group = group, path = path, tests = require(path) }
  end
end

local function parse_args(s)
  local args = {}
  for pair in string.gmatch(s or "", "[^;]+") do
    local k, v = string.match(pair, "^%s*([^=]+)=(.*)$")
    if k then args[k] = v end
  end
  return args
end

local function traceback(e)
  return debug.traceback(tostring(e), 2)
end

local runner = {
  args = {},
  queue = {},   -- { name, file, fn }
  results = {},
  current = nil, -- { test, ctx, started_tick }
  started = false,
  finished = false,
}

---------------------------------------------------------------------------------------------
-- Test context: lets a test continue on a later tick.

local Ctx = {}
Ctx.__index = Ctx

--- Run fn after `ticks` ticks.
function Ctx:wait(ticks, fn)
  if self.pending then error("ctx: only one wait at a time", 2) end
  self.pending = { kind = "wait", at = game.tick + math.max(1, ticks), fn = fn }
end

--- Run fn on the first tick where pred() is true; fail if that takes over `max_ticks`.
function Ctx:wait_until(pred, max_ticks, fn)
  if self.pending then error("ctx: only one wait at a time", 2) end
  self.pending = { kind = "until", pred = pred, deadline = game.tick + max_ticks, fn = fn, max = max_ticks }
end

---------------------------------------------------------------------------------------------

local function record(status, message)
  local cur = assert(runner.current)
  local r = {
    name = cur.test.name,
    file = cur.test.file,
    status = status,
    message = message,
    ticks = game.tick - cur.started_tick,
  }
  runner.results[#runner.results + 1] = r
  log(string.format("TT-TEST %s %s%s", string.upper(status), r.name, message and ("\n" .. message) or ""))
  runner.current = nil
end

-- Run one step (the test body or a continuation). Returns true while the test is still going.
local function step(fn)
  local ctx = runner.current.ctx
  ctx.pending = nil
  local ok, err = xpcall(fn, traceback, ctx)
  if not ok then record("fail", err); return false end
  if ctx.pending then return true end
  record("pass", nil)
  return false
end

local function finish()
  runner.finished = true
  local passed, failed = 0, 0
  for _, r in ipairs(runner.results) do
    if r.status == "pass" then passed = passed + 1 else failed = failed + 1 end
  end
  local summary = {
    run = runner.args.run or "",
    factorio_tick = game.tick,
    passed = passed,
    failed = failed,
    results = runner.results,
  }
  helpers.write_file(RESULTS_FILE, helpers.table_to_json(summary), false)
  log(string.format("TT-TEST SUMMARY passed=%d failed=%d", passed, failed))
  script.finish_test(failed == 0 and passed > 0)
end

local function start()
  runner.started = true
  runner.args = parse_args(script.test_arg)
  local filter = runner.args.filter
  local selftest = runner.args.selftest == "1"
  for _, f in ipairs(files) do
    if f.group ~= "selftest" or selftest then
      for _, t in ipairs(f.tests) do
        if not filter or filter == "" or string.find(t.name, filter, 1, true) then
          runner.queue[#runner.queue + 1] = { name = t.name, file = f.path, fn = t.fn }
        end
      end
    end
  end
  log(string.format("TT-TEST START run=%s tests=%d", tostring(runner.args.run), #runner.queue))
end

local function on_tick()
  if runner.finished then return end
  if not runner.started then start() end

  -- Continue the current test if it is waiting.
  local cur = runner.current
  if cur then
    local p = cur.ctx.pending
    if p.kind == "wait" then
      if game.tick < p.at then return end
      if step(p.fn) then return end
    else
      local ok, ready = xpcall(p.pred, traceback)
      if not ok then record("fail", ready)
      elseif ready then
        if step(p.fn) then return end
      elseif game.tick >= p.deadline then
        record("fail", string.format("wait_until timed out after %d ticks", p.max))
      else
        return
      end
    end
  end

  -- Start tests until one needs to wait.
  while #runner.queue > 0 do
    local test = table.remove(runner.queue, 1)
    runner.current = { test = test, ctx = setmetatable({}, Ctx), started_tick = game.tick }
    if step(test.fn) then return end
  end

  finish()
end

script.on_event(defines.events.on_tick, on_tick)
