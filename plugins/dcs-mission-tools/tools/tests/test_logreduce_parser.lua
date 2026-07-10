local t = require("helpers")
local parser = require("logreduce.parser")

local opened = parser.parseLine("=== Log opened UTC 2026-06-30 18:01:10")
t.eq("parser: detects log opened", { opened.kind, opened.event }, { "session", "opened" })

local closed = parser.parseLine("=== Log closed.")
t.eq("parser: detects log closed", { closed.kind, closed.event }, { "session", "closed" })

local rec = parser.parseLine("2026-06-30 18:01:09.542 INFO    APP (Main): DCS/2.9.27.25340 (x86_64; MT)")
t.eq("parser: envelope fields",
  { rec.kind, rec.level, rec.subsystem, rec.thread },
  { "log", "INFO", "APP", "Main" })
t.eq("parser: envelope timestamp", rec.ts, "2026-06-30 18:01:09.542")
t.eq("parser: envelope message", rec.message, "DCS/2.9.27.25340 (x86_64; MT)")

local colonSubsys = parser.parseLine("2026-06-30 21:04:58.720 ERROR   Lua::Config (Main): Call error")
t.eq("parser: subsystem with colons", colonSubsys.subsystem, "Lua::Config")

local threaded = parser.parseLine("2026-06-30 18:01:10.539 INFO    ASYNCNET (10484): Login success.")
t.eq("parser: numeric thread id", threaded.thread, "10484")

local junk = parser.parseLine("some unstructured line")
t.eq("parser: unmatched is other", junk.kind, "other")

local plain = parser.parseLine("2026-06-30 18:01:59.280 INFO    SCRIPTING (Main): VEAF|I|3837: Loading version 1.56.2")
t.eq("parser: veaf without function",
  { plain.veaf.module, plain.veaf.level, plain.veaf.fn, plain.veaf.id, plain.veaf.message },
  { "VEAF", "I", nil, "3837", "Loading version 1.56.2" })

local withFn = parser.parseLine("2026-06-30 18:01:59.286 WARNING SCRIPTING (Main): RADIO|W|initialize|25660: Error while loading SRS")
t.eq("parser: veaf with function",
  { withFn.veaf.module, withFn.veaf.level, withFn.veaf.fn, withFn.veaf.id, withFn.veaf.message },
  { "RADIO", "W", "initialize", "25660", "Error while loading SRS" })

local spaced = parser.parseLine("2026-06-30 18:01:59.289 INFO    SCRIPTING (Main): NAMED POINTS|I|addCities|42994: Init cities")
t.eq("parser: veaf module with space", spaced.veaf.module, "NAMED POINTS")

local notVeaf = parser.parseLine("2026-06-30 18:01:59.236 INFO    SCRIPTING (Main): Mist version 4.5.128 loaded.")
t.eq("parser: non-veaf scripting has no veaf field", notVeaf.veaf, nil)
