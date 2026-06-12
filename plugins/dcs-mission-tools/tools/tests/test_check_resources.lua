local t = require("helpers")
local model = require("lib.missionModel")
local resources = require("checks.resources")

local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures"

local clean = model.loadProject(FIX .. "/clean")
t.eq("resources: clean fixture has no findings", resources.run(clean), {})

local broken = model.loadProject(FIX .. "/broken-resources")
local findings = resources.run(broken)
t.hasFinding("resources: undeclared key", findings, "RES-UNDECLARED-KEY")
t.hasFinding("resources: missing file", findings, "RES-MISSING-FILE")
t.hasFinding("resources: encoding mismatch", findings, "RES-ENCODING")
t.hasFinding("resources: orphan key", findings, "RES-ORPHAN-KEY")
t.hasFinding("resources: orphan file", findings, "RES-ORPHAN-FILE")

local missingFindings = 0
for _, f in ipairs(findings) do
  if f.code == "RES-MISSING-FILE" then
    missingFindings = missingFindings + 1
    t.contains("resources: missing file names the file", f.message, "beacon.ogg")
  end
end
t.eq("resources: exactly one missing file", missingFindings, 1)
