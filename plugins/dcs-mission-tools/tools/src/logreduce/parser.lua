local M = {}

local ENVELOPE = "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+)%s+(%u+)%s+(%S+)%s+%((.-)%):%s?(.*)$"
local VEAF = "^([%u][%u ]*)|([IWEDT])|(.-):%s(.*)$"

local function parseVeaf(message)
  local module, level, middle, text = message:match(VEAF)
  if not module then return nil end
  local fn, id = middle:match("^(.-)|(.+)$")
  if not fn then fn, id = nil, middle end
  return { module = module, level = level, fn = fn, id = id, message = text }
end

function M.parseLine(line)
  if line:find("^=== Log opened") then
    return { kind = "session", event = "opened", raw = line }
  end
  if line:find("^=== Log closed%.") then
    return { kind = "session", event = "closed", raw = line }
  end
  local ts, level, subsystem, thread, message = line:match(ENVELOPE)
  if ts then
    local record = {
      kind = "log", ts = ts, level = level, subsystem = subsystem,
      thread = thread, message = message, raw = line,
    }
    record.veaf = parseVeaf(message)
    return record
  end
  return { kind = "other", raw = line }
end

return M
