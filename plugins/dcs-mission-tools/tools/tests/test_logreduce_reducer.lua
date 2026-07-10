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
