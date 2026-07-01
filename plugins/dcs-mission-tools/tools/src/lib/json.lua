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

-- Decode (JSON -> Lua) per doc/developer/export-json-contract.md (schemaVersion 2):
--   * array JSON -> Lua sequence (keys 1..n)
--   * object JSON without a sole `__luaTable__` key -> table with verbatim string
--     keys (no numeric coercion -- this keeps DCS `failures = {["10"]=...}` correct)
--   * object JSON whose ONLY key is `__luaTable__`, holding a list of [key, value]
--     pairs -> table built from the pairs; a JSON number pair-key is an integer Lua
--     key, a JSON string pair-key is a string Lua key (lossless, no guessing)
--   * [] and {} both decode to an empty Lua table
-- The decoded tables reproduce the old `load()` output table-for-table (array-ness
-- and key types), so the checks yield identical findings.

local SENTINEL = "__luaTable__"

local function decodeError(pos, message)
  error(string.format("json.decode: %s at position %d", message, pos))
end

local function skipWs(str, pos)
  local _, last = str:find("^[ \t\r\n]*", pos)
  return last + 1
end

-- The single key of `tbl` if it has exactly one, else nil.
local function soleKey(tbl)
  local k = next(tbl)
  if k == nil or next(tbl, k) ~= nil then return nil end
  return k
end

-- Build a Lua table from a `__luaTable__` pair list, preserving each pair-key's
-- JSON type (number -> integer/number key, string -> string key). Returns nil if
-- the value is not the strict pair-list shape, so the caller keeps it verbatim.
local function tableFromPairs(pairs)
  if type(pairs) ~= "table" then return nil end
  local out = {}
  for _, pair in ipairs(pairs) do
    if type(pair) ~= "table" then return nil end
    local key = pair[1]
    local keyType = type(key)
    if keyType ~= "number" and keyType ~= "string" then return nil end
    out[key] = pair[2]
  end
  return out
end

local unescapes = {
  ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
  b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
}

local decodeValue -- forward declaration

local function decodeString(str, pos)
  local buffer, i = {}, pos + 1
  while i <= #str do
    local c = str:sub(i, i)
    if c == '"' then
      return table.concat(buffer), i + 1
    elseif c == "\\" then
      local e = str:sub(i + 1, i + 1)
      if unescapes[e] then
        buffer[#buffer + 1] = unescapes[e]
        i = i + 2
      elseif e == "u" then
        local hex = str:sub(i + 2, i + 5)
        if not hex:match("^%x%x%x%x$") then decodeError(i, "invalid \\u escape") end
        local cp = tonumber(hex, 16)
        i = i + 6
        if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i, i + 1) == "\\u" then
          local low = tonumber(str:sub(i + 2, i + 5), 16)
          if low and low >= 0xDC00 and low <= 0xDFFF then
            cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
            i = i + 6
          end
        end
        buffer[#buffer + 1] = utf8.char(cp)
      else
        decodeError(i, "invalid escape '\\" .. e .. "'")
      end
    else
      buffer[#buffer + 1] = c
      i = i + 1
    end
  end
  decodeError(pos, "unterminated string")
end

local function decodeNumber(str, pos)
  local token = str:match("^%-?%d+%.?%d*[eE][%+%-]?%d+", pos)
    or str:match("^%-?%d+%.%d+", pos)
    or str:match("^%-?%d+", pos)
  if not token then decodeError(pos, "invalid number") end
  return tonumber(token), pos + #token
end

local function decodeArray(str, pos)
  local result, count = {}, 0
  pos = skipWs(str, pos + 1)
  if str:sub(pos, pos) == "]" then return result, pos + 1 end
  while true do
    local value
    value, pos = decodeValue(str, pos)
    count = count + 1
    result[count] = value
    pos = skipWs(str, pos)
    local c = str:sub(pos, pos)
    if c == "]" then return result, pos + 1 end
    if c ~= "," then decodeError(pos, "expected ',' or ']'") end
    pos = skipWs(str, pos + 1)
  end
end

local function decodeObject(str, pos)
  local result = {}
  pos = skipWs(str, pos + 1)
  if str:sub(pos, pos) == "}" then return result, pos + 1 end
  while true do
    if str:sub(pos, pos) ~= '"' then decodeError(pos, "expected string key") end
    local key
    key, pos = decodeString(str, pos)
    pos = skipWs(str, pos)
    if str:sub(pos, pos) ~= ":" then decodeError(pos, "expected ':'") end
    local value
    value, pos = decodeValue(str, skipWs(str, pos + 1))
    result[key] = value
    pos = skipWs(str, pos)
    local c = str:sub(pos, pos)
    if c == "}" then break end
    if c ~= "," then decodeError(pos, "expected ',' or '}'") end
    pos = skipWs(str, pos + 1)
  end
  pos = pos + 1
  -- A sole `__luaTable__` key holding a strict pair list is the envelope (§2);
  -- anything else (including a verbatim object that merely contains the key) stays as-is.
  if soleKey(result) == SENTINEL then
    local built = tableFromPairs(result[SENTINEL])
    if built then return built, pos end
  end
  return result, pos
end

function decodeValue(str, pos)
  pos = skipWs(str, pos)
  local c = str:sub(pos, pos)
  if c == "{" then return decodeObject(str, pos) end
  if c == "[" then return decodeArray(str, pos) end
  if c == '"' then return decodeString(str, pos) end
  if c == "t" then
    if str:sub(pos, pos + 3) == "true" then return true, pos + 4 end
  elseif c == "f" then
    if str:sub(pos, pos + 4) == "false" then return false, pos + 5 end
  elseif c == "n" then
    if str:sub(pos, pos + 3) == "null" then return nil, pos + 4 end
  elseif c:match("[%-%d]") then
    return decodeNumber(str, pos)
  end
  decodeError(pos, "unexpected character '" .. c .. "'")
end

-- Decode a JSON document into a Lua value. Raises on malformed input.
function M.decode(str)
  local value, pos = decodeValue(str, 1)
  pos = skipWs(str, pos)
  if pos <= #str then decodeError(pos, "trailing data") end
  return value
end

return M
