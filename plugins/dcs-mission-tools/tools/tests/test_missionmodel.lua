local t = require("helpers")
local model = require("lib.missionModel")

local FIXTURES = "plugins/dcs-mission-tools/tools/tests/fixtures"
local project, err = model.loadProject(FIXTURES .. "/clean")
t.eq("model: project loads", err, nil)
t.eq("model: theatre", project.theatre, "Caucasus")
t.eq("model: vmct markers detected", project.hasVmctMarkers, true)
t.eq("model: l10n files indexed", project.l10nFiles["briefing.png"], true)
t.eq("model: community scripts indexed", project.communityScripts["mist.lua"], true)
t.contains("model: script text concatenated", project.scriptText, "combatZone_Bravo")

local zones = model.zoneNames(project.mission)
t.eq("model: zone names", zones, { ["combatZone_Alpha"] = true, ["combatZone_Bravo"] = true })

local groups = model.groupNames(project.mission)
t.eq("model: group names", groups, { ["Ground-Alpha"] = true })

local bad, badErr = model.loadProject(FIXTURES .. "/does-not-exist")
t.eq("model: missing project is nil", bad, nil)
t.contains("model: missing project error", badErr, "src/mission")
