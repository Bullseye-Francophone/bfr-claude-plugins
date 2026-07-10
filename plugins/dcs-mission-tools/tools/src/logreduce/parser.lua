local M = {}

local ENVELOPE = "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+)%s+(%u+)%s+(%S+)%s+%((.-)%):%s?(.*)$"

function M.parseLine(line)
  if line:find("^=== Log opened") then
    return { kind = "session", event = "opened", raw = line }
  end
  if line:find("^=== Log closed%.") then
    return { kind = "session", event = "closed", raw = line }
  end
  local ts, level, subsystem, thread, message = line:match(ENVELOPE)
  if ts then
    return {
      kind = "log", ts = ts, level = level, subsystem = subsystem,
      thread = thread, message = message, raw = line,
    }
  end
  return { kind = "other", raw = line }
end

return M
