local t = require("helpers")
local model = require("lib.missionModel")
local flags = require("checks.flags")

local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures"

t.eq("flags: clean fixture has no findings",
  flags.run(model.loadProject(FIX .. "/clean")), {})

local findings = flags.run(model.loadProject(FIX .. "/broken-flags"))
local neverSet = t.hasFinding("flags: read but never set", findings, "FLAG-NEVER-SET")
if neverSet then
  t.contains("flags: names the flag", neverSet.message, "Never-Set-Flag")
  t.eq("flags: never-set is a warning", neverSet.severity, "warning")
end
local neverRead = t.hasFinding("flags: set but never read", findings, "FLAG-NEVER-READ")
if neverRead then
  t.eq("flags: never-read is info", neverRead.severity, "info")
end
