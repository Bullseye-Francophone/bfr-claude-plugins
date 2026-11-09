local fs = require("lib.fileSystem")
local decode = require("logreduce.decode")
local parser = require("logreduce.parser")
local reducer = require("logreduce.reducer")
local follow = require("logreduce.follow")

local M = {}

local NO_LOG_LINE_MESSAGE = "not a DCS log (no DCS log line found)"

local function isDcsLogLine(record)
  return record.kind == "log" or record.kind == "session"
end

function M.runOnce(path, opts)
  local bytes, readErr = fs.readAll(path)
  if not bytes then return nil, readErr end
  local text, decodeErr = decode.toText(bytes)
  if not text then return nil, path .. ": " .. decodeErr end
  local r = reducer.new(opts)
  local hasDcsLogLine = false
  for _, line in ipairs(decode.splitLines(text)) do
    local record = parser.parseLine(line)
    hasDcsLogLine = hasDcsLogLine or isDcsLogLine(record)
    r:add(record)
  end
  if not hasDcsLogLine then return nil, path .. ": " .. NO_LOG_LINE_MESSAGE end
  return r:digest()
end

function M.newFollowSession(path, opts, emitEvent, emitNotice)
  local follower = follow.new(path)
  local activeReducer = reducer.new(opts)
  local pendingEvent = nil
  local isMissingAnnounced = false
  local hasDcsLogLine = false

  local function flushPendingEvent()
    if pendingEvent then emitEvent(pendingEvent) end
    pendingEvent = nil
  end

  local session = { finish = flushPendingEvent }

  function session.tick()
    local lines, status = follower:poll()
    if status.corrupt then return nil, path .. ": " .. status.corrupt end
    if status.rotated then
      flushPendingEvent()
      activeReducer = reducer.new(opts)
      hasDcsLogLine = false
    end
    if status.missing then
      if not isMissingAnnounced then emitNotice("waiting for " .. path .. " to exist") end
      isMissingAnnounced = true
      flushPendingEvent()
      return true
    end
    isMissingAnnounced = false
    if #lines == 0 then flushPendingEvent() end
    for _, line in ipairs(lines) do
      local record = parser.parseLine(line)
      if isDcsLogLine(record) then
        hasDcsLogLine = true
        flushPendingEvent()
      end
      pendingEvent = activeReducer:add(record) or pendingEvent
    end
    if #lines > 0 and not hasDcsLogLine then return nil, path .. ": " .. NO_LOG_LINE_MESSAGE end
    return true
  end

  return session
end

return M
