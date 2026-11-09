local M = {}

local MAX_IPV4_OCTET = 255
local VERSION_PREFIX_WINDOW = 8

local function isVersionContext(source, matchStart)
  local prefix = source:sub(math.max(1, matchStart - VERSION_PREFIX_WINDOW), matchStart - 1)
  return prefix:find("%a/$") ~= nil or prefix:find("[vV]$") ~= nil or prefix:lower():find("version%s*$") ~= nil
end

local function scrubIpv4(source)
  return (source:gsub("()(%d+)%.(%d+)%.(%d+)%.(%d+)", function(matchStart, first, second, third, fourth)
    for _, octet in ipairs({ first, second, third, fourth }) do
      if tonumber(octet) > MAX_IPV4_OCTET then return nil end
    end
    if isVersionContext(source, matchStart) then return nil end
    return "0.0.0.0"
  end))
end

function M.scrub(text)
  text = text:gsub('(%a:[\\/]Users[\\/])[^\\/"\r\n]+', "%1PLAYER")
  text = text:gsub('(Saved Games[\\/])[^\\/"\r\n]+', "%1INSTANCE")
  text = scrubIpv4(text)
  text = text:gsub("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x", string.rep("0", 32))
  return text
end

if arg and arg[0] and arg[0]:find("anonymize%.lua$") then
  io.write(M.scrub(io.read("*a")))
end

return M
