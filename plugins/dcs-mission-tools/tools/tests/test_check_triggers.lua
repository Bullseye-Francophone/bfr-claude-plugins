local t = require("helpers")
local model = require("lib.missionModel")
local triggers = require("checks.triggers")

local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures"

t.eq("triggers: clean fixture has no findings",
  triggers.run(model.loadProject(FIX .. "/clean")), {})

local findings = triggers.run(model.loadProject(FIX .. "/broken-triggers"))
t.hasFinding("triggers: cardinality mismatch", findings, "TRG-CARDINALITY")
t.hasFinding("triggers: startup coverage hole", findings, "TRG-STARTUP-COVERAGE")
local recompile = t.hasFinding("triggers: recompile mismatch", findings, "TRG-RECOMPILE")
if recompile then
  t.contains("triggers: recompile names the index", recompile.message, "[4]")
end
