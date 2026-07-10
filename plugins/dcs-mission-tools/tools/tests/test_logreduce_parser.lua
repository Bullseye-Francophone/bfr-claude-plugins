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
