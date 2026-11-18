-- Minimal assertions. Each raises an error with a readable message on failure.
local M = {}

local function fmt(v)
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) == "table" then return serpent.line(v, { comment = false }) end
  return tostring(v)
end

---@param actual any
---@param expected any
---@param msg string?
function M.equals(actual, expected, msg)
  if actual ~= expected then
    error((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
  end
end

---@param value any
---@param msg string?
function M.truthy(value, msg)
  if not value then error(msg or ("expected truthy, got " .. fmt(value)), 2) end
end

---@param value any
---@param msg string?
function M.falsy(value, msg)
  if value then error(msg or ("expected falsy, got " .. fmt(value)), 2) end
end

---@param fn function
---@param msg string?
function M.errors(fn, msg)
  if pcall(fn) then error(msg or "expected an error", 2) end
end

return M
