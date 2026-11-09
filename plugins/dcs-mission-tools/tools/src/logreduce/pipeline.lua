local fs = require("lib.fileSystem")
local decode = require("logreduce.decode")
local parser = require("logreduce.parser")
local reducer = require("logreduce.reducer")
local follow = require("logreduce.follow")

local M = {}

function M.runOnce(path, opts)
  local bytes, readErr = fs.readAll(path)
  if not bytes then return nil, readErr end
  local text, decodeErr = decode.toText(bytes)
  if not text then return nil, path .. ": " .. decodeErr end
  local r = reducer.new(opts)
  for _, line in ipairs(decode.splitLines(text)) do
    r:add(parser.parseLine(line))
  end
  return r:digest()
end

function M.newFollowSession(path, opts, emitEvent, emitNotice)
  local follower = follow.new(path)
  local activeReducer = reducer.new(opts)
  local pendingEvent = nil
  local isMissingAnnounced = false

  local function flushPendingEvent()
    if pendingEvent then emitEvent(pendingEvent) end
    pendingEvent = nil
  end

  local session = { finish = flushPendingEvent }

  function session.tick()
    local lines, status = follower:poll()
    if status.corrupt then return nil, path .. ": " .. status.corrupt end
    if status.missing then
      if not isMissingAnnounced then emitNotice("waiting for " .. path .. " to exist") end
      isMissingAnnounced = true
      flushPendingEvent()
      return true
    end
    isMissingAnnounced = false
    if status.rotated then
      flushPendingEvent()
      activeReducer = reducer.new(opts)
    end
    if #lines == 0 then flushPendingEvent() end
    for _, line in ipairs(lines) do
      local record = parser.parseLine(line)
      if record.kind == "log" or record.kind == "session" then flushPendingEvent() end
      pendingEvent = activeReducer:add(record) or pendingEvent
    end
    return true
  end

  return session
end

return M
