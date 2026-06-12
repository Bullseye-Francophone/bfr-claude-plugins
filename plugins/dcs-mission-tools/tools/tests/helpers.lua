local M = { passed = 0, failed = 0, errors = {} }

local function dump(v, depth)
  depth = depth or 0
  if depth > 4 then return "..." end
  if type(v) == "table" then
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts + 1] = tostring(k) .. "=" .. dump(val, depth + 1)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

function M.check(label, ok, extra)
  if ok then
    M.passed = M.passed + 1
  else
    M.failed = M.failed + 1
    M.errors[#M.errors + 1] = label .. (extra and (" — " .. extra) or "")
    io.write("FAIL: ", label, extra and ("\n      " .. extra) or "", "\n")
  end
end

function M.eq(label, actual, expected)
  M.check(label, deepEqual(actual, expected),
    "expected " .. dump(expected) .. " got " .. dump(actual))
end

function M.contains(label, haystack, needle)
  M.check(label, type(haystack) == "string" and haystack:find(needle, 1, true) ~= nil,
    "expected to contain " .. tostring(needle) .. " in " .. tostring(haystack))
end

function M.hasFinding(label, findings, code)
  for _, f in ipairs(findings) do
    if f.code == code then M.check(label, true) return f end
  end
  M.check(label, false, "no finding with code " .. code .. " in " .. dump(findings))
end

function M.hasNoFinding(label, findings, code)
  for _, f in ipairs(findings) do
    if f.code == code then
      M.check(label, false, "unexpected finding " .. code .. ": " .. tostring(f.message))
      return
    end
  end
  M.check(label, true)
end

return M
