local t = require("helpers")
local parser = require("logreduce.parser")
local reducer = require("logreduce.reducer")

local function feed(r, lines)
  for _, line in ipairs(lines) do r:add(parser.parseLine(line)) end
end

local r = reducer.new()
feed(r, {
  "2026-06-30 18:20:00.000 ERROR   EDCORE (Main): Severe precision loss! Half-float has 11-bit mantissa.",
  "2026-06-30 18:20:01.000 ERROR   EDCORE (Main): Severe precision loss! Half-float has 11-bit mantissa.",
  "2026-06-30 18:20:02.000 WARNING SCRIPTING (Main): RADIO|W|initialize|25660: Error while loading SRS",
})
local digest = r:digest()
t.eq("reducer: noise is collapsed with count", digest.noise_summary[1].count, 2)
t.eq("reducer: noise never enters events", #digest.events, 1)
t.eq("reducer: warning counted", digest.counts.warning, 1)
t.eq("reducer: noise counted", digest.counts.noise, 2)

local r2 = reducer.new()
local first = r2:add(parser.parseLine("2026-06-30 18:20:02.000 WARNING SCRIPTING (Main): RADIO|W|initialize|25660: Error while loading SRS"))
t.eq("reducer: add returns event on first notable", first.severity, "warning")
local dup = r2:add(parser.parseLine("2026-06-30 18:20:03.000 WARNING SCRIPTING (Main): RADIO|W|initialize|25660: Error while loading SRS"))
t.eq("reducer: add returns nil on grouped duplicate", dup, nil)
t.eq("reducer: duplicate bumps count", r2:digest().events[1].count, 2)

local r3 = reducer.new()
feed(r3, {
  "2026-06-30 18:01:09.542 INFO    APP (Main): Command line: \"D:\\DCS\\bin\\DCS_server.exe\" --norender --server -w SRV4",
  "2026-06-30 18:01:09.542 INFO    APP (Main): DCS/2.9.27.25340 (x86_64; MT; Windows NT 10.0.26100)",
  "2026-06-30 18:01:59.236 INFO    SCRIPTING (Main): Mist version 4.5.128-DYNSLOTS-02-VEAF loaded.",
  "2026-06-30 18:01:59.286 INFO    SCRIPTING (Main): VEAF|I|26: init - veafSpawn",
})
local d3 = r3:digest()
t.eq("reducer: role from --server", d3.session.role, "server")
t.eq("reducer: dcs version parsed", d3.session.dcs_version, "2.9.27.25340")
t.eq("reducer: mist version parsed", d3.veaf.mist, "4.5.128-DYNSLOTS-02-VEAF")
t.eq("reducer: veaf module recorded", d3.veaf.modules_loaded[1], "veafSpawn")

local r4 = reducer.new()
feed(r4, {
  '2026-06-30 21:04:58.720 ERROR   Lua::Config (Main): Call error [string "Scripts/mist.lua"]:1546: Object doesn\'t exist',
  '\t[string "Scripts/mist.lua"]:2091: in function \'onEvent\'',
})
t.eq("reducer: stack frame attached to event", #r4:digest().events[1].stack, 1)

local THRESHOLD_LINES = {
  "2026-06-30 18:20:00.000 INFO    APP (Main): just some information",
  "2026-06-30 18:20:01.000 WARNING APP (Main): something looks off",
  "2026-06-30 18:20:02.000 ERROR   APP (Main): something broke",
  '2026-06-30 18:20:03.000 INFO    APP (Main): Failed to load C:\\Hooks\\A.lua: [string "..."]:1: unexpected symbol',
}

local function severitiesAtThreshold(threshold)
  local thresholdReducer = reducer.new({ threshold = threshold })
  feed(thresholdReducer, THRESHOLD_LINES)
  local severities = {}
  for _, event in ipairs(thresholdReducer:digest().events) do severities[#severities + 1] = event.severity end
  return severities, thresholdReducer:digest().counts
end

t.eq("reducer: critical threshold keeps only critical", (severitiesAtThreshold("critical")), { "critical" })
t.eq("reducer: error threshold keeps error and above", (severitiesAtThreshold("error")), { "critical", "error" })
t.eq("reducer: default threshold is warning", (severitiesAtThreshold(nil)), { "critical", "error", "warning" })
t.eq("reducer: info threshold keeps info", (severitiesAtThreshold("info")), { "critical", "error", "warning", "info" })
local _, countsAtCriticalThreshold = severitiesAtThreshold("critical")
t.eq("reducer: counts stay complete under a strict threshold", countsAtCriticalThreshold.info, 1)

local function luaErrorLine(file)
  return '2026-06-30 21:04:58.720 ERROR   Lua::Config (Main): Call error [string "' .. file .. '"]:10: boom'
end

local function frameLine(file)
  return '\t[string "' .. file .. '"]:20: in function \'run\''
end

local stackReducer = reducer.new()
feed(stackReducer, {
  luaErrorLine("a.lua"), frameLine("a.lua"),
  luaErrorLine("b.lua"), frameLine("b.lua"),
  luaErrorLine("a.lua"), frameLine("a.lua"),
})
local stackBySource = {}
for _, event in ipairs(stackReducer:digest().events) do stackBySource[event.source_file] = event.stack end
t.eq("reducer: repeated error keeps the stack of its first occurrence only", stackBySource["a.lua"], { frameLine("a.lua") })
t.eq("reducer: frame of a repeated error stays off the previous event", stackBySource["b.lua"], { frameLine("b.lua") })

local noiseStackReducer = reducer.new()
feed(noiseStackReducer, {
  luaErrorLine("a.lua"),
  "2026-06-30 18:20:00.000 ERROR   EDCORE (Main): Severe precision loss! Half-float has 11-bit mantissa.",
  frameLine("z.lua"),
})
t.eq("reducer: frame after noise is not attached", noiseStackReducer:digest().events[1].stack, nil)

local hookReducer = reducer.new()
local HOOK_ONE = 'Failed to load C:\\Hooks\\Demo1.lua: [string "..."]:1: unexpected symbol'
local HOOK_TWO = 'Failed to load C:\\Hooks\\Demo2.lua: [string "..."]:1: unexpected symbol'
feed(hookReducer, {
  "2026-06-30 18:20:00.000 ERROR   APP (Main): " .. HOOK_ONE,
  "2026-06-30 18:20:01.000 ERROR   APP (Main): " .. HOOK_TWO,
})
local hookEvents = hookReducer:digest().events
t.eq("reducer: two failing hooks stay two events", #hookEvents, 2)
t.eq("reducer: hook failure keeps its full message", hookEvents[1].message, HOOK_ONE)
