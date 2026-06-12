local t = require("helpers")
local model = require("lib.missionModel")
local loading = require("checks.loading")

local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures"

t.eq("loading: clean fixture has no findings",
  loading.run(model.loadProject(FIX .. "/clean")), {})

local findings = loading.run(model.loadProject(FIX .. "/broken-loading"))
local parity = t.hasFinding("loading: static/dynamic parity", findings, "LOAD-PARITY")
if parity then t.contains("loading: parity names the script", parity.message, "CTLD.lua") end
t.hasFinding("loading: mist must load first", findings, "LOAD-MIST-FIRST")
t.hasFinding("loading: committed predicate flipped", findings, "LOAD-COMMITTED-STATE")
t.hasFinding("loading: miz at project root", findings, "LOAD-MIZ-AT-ROOT")
t.hasFinding("loading: requiredModules not empty", findings, "LOAD-REQUIRED-MODULES")
