local t = require("helpers")
local model = require("lib.missionModel")
local names = require("checks.names")

local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures"

t.eq("names: clean fixture has no findings",
  names.run(model.loadProject(FIX .. "/clean")), {})

local findings = names.run(model.loadProject(FIX .. "/broken-names"))
local zone = t.hasFinding("names: missing zone", findings, "NAME-ZONE-MISSING")
if zone then
  t.contains("names: zone finding names the zone", zone.message, "combatZone_Missing")
  t.eq("names: missing zone is an error", zone.severity, "error")
end
local group = t.hasFinding("names: missing group", findings, "NAME-GROUP-MISSING")
if group then
  t.eq("names: missing group is a warning", group.severity, "warning")
end
