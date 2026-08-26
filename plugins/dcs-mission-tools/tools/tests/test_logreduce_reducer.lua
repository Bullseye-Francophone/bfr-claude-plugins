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
