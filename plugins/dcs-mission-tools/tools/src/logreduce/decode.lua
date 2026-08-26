local M = {}

local function hasNonNull(bytes)
  return bytes:find("[^%z]") ~= nil
end

local function fromUtf16(bytes, littleEndian)
  local out = {}
  for i = 1, #bytes - 1, 2 do
    local lo, hi = bytes:byte(i), bytes:byte(i + 1)
    local code = littleEndian and lo or hi
    local high = littleEndian and hi or lo
    if high == 0 then out[#out + 1] = string.char(code) end
  end
  return table.concat(out)
end

function M.toText(bytes)
  if not hasNonNull(bytes) then
    return nil, "empty or corrupt (all-null content)"
  end
  if bytes:sub(1, 3) == "\239\187\191" then
    return bytes:sub(4)
  end
  if bytes:sub(1, 2) == "\255\254" then
    return fromUtf16(bytes:sub(3), true)
  end
  if bytes:sub(1, 2) == "\254\255" then
    return fromUtf16(bytes:sub(3), false)
  end
  return bytes
end

function M.splitLines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    if line ~= "" then lines[#lines + 1] = line end
  end
  return lines
end

return M
