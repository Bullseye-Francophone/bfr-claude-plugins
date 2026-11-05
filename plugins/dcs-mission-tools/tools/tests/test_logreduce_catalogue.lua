local t = require("helpers")
local parser = require("logreduce.parser")
local catalogue = require("logreduce.catalogue")

local function classifyLine(line) return catalogue.classify(parser.parseLine(line)) end

local noise = classifyLine("2026-06-30 18:20:00.000 ERROR   EDCORE (Main): Severe precision loss! Half-float has 11-bit mantissa.")
t.eq("catalogue: edcore precision loss is noise", noise.noise, true)
t.eq("catalogue: edcore precision loss layer", noise.layer, "engine-noise")

local runtime = classifyLine('2026-06-30 19:27:29.589 ERROR   SCRIPTING (Main): MIST|doScheduledFunctions|1528: Error in scheduled function: [string "l10n/DEFAULT/veaf-scripts.lua"]:32390: attempt to index local \'dcsUnit\' (a nil value)')
t.eq("catalogue: mission runtime error severity", runtime.severity, "error")
t.eq("catalogue: mission runtime error category", runtime.category, "mission-script-runtime")

local regmap = classifyLine("2026-06-30 20:00:00.000 ERROR   DCS (Main): RegMapStorage has no more IDs")
t.eq("catalogue: regmapstorage is critical", regmap.severity, "critical")

local ok = classifyLine("2026-06-30 18:01:59.280 INFO    SCRIPTING (Main): VEAF|I|3837: Loading version 1.56.2")
t.eq("catalogue: veaf info default severity", ok.severity, "info")
t.eq("catalogue: veaf info not noise", ok.noise, false)
