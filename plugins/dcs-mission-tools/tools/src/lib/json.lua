local M = {}

local escapes = {
  ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
  ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function escapeString(s)
  return (s:gsub('[%z\1-\31"\\]', function(c)
    return escapes[c] or string.format("\\u%04x", c:byte())
  end))
end

local function isArray(tbl)
  local count = 0
  for k in pairs(tbl) do
    if type(k) ~= "number" then return false end
    count = count + 1
  end
  for i = 1, count do
    if tbl[i] == nil then return false end
  end
  return true
end

function M.encode(value)
  local valueType = type(value)
  if value == nil then return "null" end
  if valueType == "boolean" then return tostring(value) end
  if valueType == "number" then
    if value % 1 == 0 then return string.format("%d", value) end
    return tostring(value)
  end
  if valueType == "string" then return '"' .. escapeString(value) .. '"' end
  if valueType == "table" then
    if isArray(value) then
      local parts = {}
      for _, item in ipairs(value) do parts[#parts + 1] = M.encode(item) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = { name = tostring(k), key = k } end
    table.sort(keys, function(a, b) return a.name < b.name end)
    local parts = {}
    for _, entry in ipairs(keys) do
      parts[#parts + 1] = '"' .. escapeString(entry.name) .. '":' .. M.encode(value[entry.key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("json.encode: unsupported type " .. valueType)
end

return M
