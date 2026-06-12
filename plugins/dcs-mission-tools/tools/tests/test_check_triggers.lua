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

local bothProject = { mission = {
  trig = {
    actions = { [1] = "a_do_script(\"x\");" },
    conditions = { [1] = "return(true)" },
    flag = { [1] = true },
    funcStartup = { [1] = "if mission.trig.conditions[1]() then mission.trig.actions[1]() end" },
    func = { [1] = "if mission.trig.conditions[1]() then mission.trig.actions[1]() end" },
  },
  trigrules = { [1] = {
    predicate = "triggerStart",
    actions = { [1] = { predicate = "a_do_script", text = "x" } },
    rules = { },
  } },
} }
local bothFindings = triggers.run(bothProject)
t.eq("triggers: index in both tables yields exactly one finding", #bothFindings, 1)
t.eq("triggers: that finding is startup-coverage", bothFindings[1].code, "TRG-STARTUP-COVERAGE")
