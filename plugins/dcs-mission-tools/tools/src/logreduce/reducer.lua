local catalogue = require("logreduce.catalogue")

local M = {}
local Reducer = {}
Reducer.__index = Reducer

local RANK = { critical = 1, error = 2, warning = 3, info = 4, noise = 5 }

local function groupKey(record, class)
  if record.luaerror then
    return table.concat({ class.category, record.luaerror.file, record.luaerror.line }, "|")
  end
  local normalized = (record.message or record.raw):gsub("%d+", "#")
  return table.concat({ class.category, record.subsystem or "", normalized }, "|")
end

function M.new(opts)
  opts = opts or {}
  return setmetatable({
    threshold = RANK[opts.threshold or "warning"],
    groups = {}, order = {}, noise = {}, noiseOrder = {},
    counts = { critical = 0, error = 0, warning = 0, info = 0, noise = 0 },
    session = {}, veaf = { modules_loaded = {}, versions = {} },
  }, Reducer)
end

function Reducer:add(record)
  if record.kind == "stack" then
    if self.lastEvent then
      self.lastEvent.stack = self.lastEvent.stack or {}
      self.lastEvent.stack[#self.lastEvent.stack + 1] = record.raw
    end
    return nil
  end
  if record.kind == "session" then
    self.session[record.event] = true
    return nil
  end
  if record.kind ~= "log" then return nil end
  if record.subsystem == "APP" and record.message:find("Command line:") then
    self.session.role = record.message:find("%-%-server") and "server" or "client"
  end
  if record.subsystem == "APP" then
    local version = record.message:match("^DCS/(%S+)")
    if version then self.session.dcs_version = version end
  end
  if record.subsystem == "SCRIPTING" then
    local mist = record.message:match("^Mist version (%S+) loaded")
    if mist then self.veaf.mist = mist end
    if record.veaf then
      local module = record.veaf.message:match("^init %- (%S+)")
      if module then self.veaf.modules_loaded[#self.veaf.modules_loaded + 1] = module end
    end
  end
  local class = catalogue.classify(record)
  self.counts[class.severity] = self.counts[class.severity] + 1

  if class.noise then
    local group = self.noise[class.id]
    if not group then
      group = { pattern = class.id, count = 0 }
      self.noise[class.id] = group
      self.noiseOrder[#self.noiseOrder + 1] = group
    end
    group.count = group.count + 1
    return nil
  end

  local key = groupKey(record, class)
  local group = self.groups[key]
  local isNew = group == nil
  if isNew then
    group = {
      severity = class.severity, category = class.category, id = class.id,
      count = 0, first_ts = record.ts, last_ts = record.ts,
      message = record.luaerror and record.luaerror.message or record.message,
      source_file = record.luaerror and record.luaerror.file or nil,
      line = record.luaerror and record.luaerror.line or nil,
    }
    self.groups[key] = group
    self.order[#self.order + 1] = group
    self.lastEvent = group
  end
  group.count = group.count + 1
  group.last_ts = record.ts

  if isNew and RANK[class.severity] <= self.threshold then return group end
  return nil
end

function Reducer:digest()
  if not self.session.role then self.session.role = "unknown" end
  local events = {}
  for _, group in ipairs(self.order) do events[#events + 1] = group end
  table.sort(events, function(a, b)
    if a.severity ~= b.severity then return RANK[a.severity] < RANK[b.severity] end
    return a.count > b.count
  end)
  return {
    session = self.session, veaf = self.veaf, events = events,
    noise_summary = self.noiseOrder, counts = self.counts,
  }
end

return M
