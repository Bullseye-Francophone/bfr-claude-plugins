local M = {}

local function hasNonNull(bytes)
  return bytes:find("[^%z]") ~= nil
end

M.ALL_NULL_MESSAGE = "empty or corrupt (all-null content)"

function M.isAllNull(bytes)
  return not hasNonNull(bytes)
end

local UTF8_BOM = "\239\187\191"
local UTF16_LITTLE_ENDIAN_BOM = "\255\254"
local UTF16_BIG_ENDIAN_BOM = "\254\255"
local REPLACEMENT_CHARACTER = utf8.char(0xFFFD)

local function isHighSurrogate(codeUnit)
  return codeUnit >= 0xD800 and codeUnit <= 0xDBFF
end

local function isLowSurrogate(codeUnit)
  return codeUnit >= 0xDC00 and codeUnit <= 0xDFFF
end

function M.decodeUtf16(bytes, isLittleEndian)
  local function codeUnitAt(position)
    local firstByte, secondByte = bytes:byte(position, position + 1)
    if isLittleEndian then return firstByte + secondByte * 256 end
    return firstByte * 256 + secondByte
  end

  local decoded = {}
  local position = 1
  while position + 1 <= #bytes do
    local codeUnit = codeUnitAt(position)
    local consumedBytes = 2
    if isHighSurrogate(codeUnit) then
      if position + 3 > #bytes then break end
      local nextCodeUnit = codeUnitAt(position + 2)
      if isLowSurrogate(nextCodeUnit) then
        decoded[#decoded + 1] = utf8.char(0x10000 + (codeUnit - 0xD800) * 0x400 + (nextCodeUnit - 0xDC00))
        consumedBytes = 4
      else
        decoded[#decoded + 1] = REPLACEMENT_CHARACTER
      end
    elseif isLowSurrogate(codeUnit) then
      decoded[#decoded + 1] = REPLACEMENT_CHARACTER
    else
      decoded[#decoded + 1] = utf8.char(codeUnit)
    end
    position = position + consumedBytes
  end
  return table.concat(decoded), bytes:sub(position)
end

function M.detectEncoding(bytes)
  if bytes:sub(1, 3) == UTF8_BOM then return "utf8", 3 end
  if bytes:sub(1, 2) == UTF16_LITTLE_ENDIAN_BOM then return "utf16le", 2 end
  if bytes:sub(1, 2) == UTF16_BIG_ENDIAN_BOM then return "utf16be", 2 end
  return "bytes", 0
end

function M.normalizeLine(line)
  if utf8.len(line) then return line end
  return (line:gsub("[\128-\255]", function(latin1Byte)
    return utf8.char(latin1Byte:byte())
  end))
end

function M.toText(bytes)
  if M.isAllNull(bytes) then
    return nil, M.ALL_NULL_MESSAGE
  end
  local encoding, bomLength = M.detectEncoding(bytes)
  local body = bytes:sub(bomLength + 1)
  if encoding == "utf16le" or encoding == "utf16be" then
    body = M.decodeUtf16(body, encoding == "utf16le")
  end
  return (body:gsub("[^\r\n]+", M.normalizeLine))
end

function M.splitLines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    if line ~= "" then lines[#lines + 1] = line end
  end
  return lines
end

return M
