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
if neverRead then
  t.contains("flags: never-read names the flag", neverRead.message, "Never-Read-Flag")
end

local singleQuoteProject = {
  mission = { trig = { actions = {}, conditions = { [1] = "return(c_flag_is_true(\"Quoted-Flag\") )" } } },
  scriptText = "trigger.action.setUserFlag('Quoted-Flag', true)",
}
t.eq("flags: single-quoted setUserFlag satisfies double-quoted read",
  flags.run(singleQuoteProject), {})

local radioCompiledProject = {
  mission = { trig = {
    actions = { [1] = "a_add_radio_item(getValueDictByKey(\"DictKey_ActionRadioText_312\"), \"Radio-Flag-A\", 1);" },
    conditions = { [1] = "return(c_flag_is_true(\"Radio-Flag-A\") )" },
  } },
  scriptText = "",
}
t.eq("flags: compiled radio item counts as setter", flags.run(radioCompiledProject), {})

local radioCoalitionProject = {
  mission = { trig = {
    actions = { [1] = "a_add_radio_item_for_coalition(\"red\", getValueDictByKey(\"DictKey_ActionRadioText_1873\"), \"Radio-Flag-B\", 1);" },
    conditions = { [1] = "return(c_flag_is_true(\"Radio-Flag-B\") )" },
  } },
  scriptText = "",
}
t.eq("flags: compiled coalition radio item counts as setter", flags.run(radioCoalitionProject), {})

local radioTrigrulesProject = {
  mission = {
    trig = {
      actions = {},
      conditions = { [1] = "return(c_flag_is_true(\"Radio-Flag-C\") )" },
    },
    trigrules = { [1] = {
      predicate = "triggerOnce",
      actions = { [1] = { flag = "Radio-Flag-C", predicate = "a_add_radio_item_for_group", radiotext = "DictKey_ActionRadioText_9", value = 1 } },
      rules = {},
    } },
  },
  scriptText = "",
}
t.eq("flags: trigrules radio item variant counts as setter", flags.run(radioTrigrulesProject), {})

local dynamicSetProject = {
  mission = { trig = {
    actions = {},
    conditions = { [1] = "return(c_flag_is_true(\"Persisted-Flag-Detruit\") )" },
  } },
  scriptText = 'local ListeTriggers = {"Persisted-Flag-Detruit","Other-Entry-Detruit"}\nfor i = 1, #ListeTriggers do\n    trigger.action.setUserFlag(ListeTriggers[i],0)\nend\n',
}
local dynamicFindings = flags.run(dynamicSetProject)
local dynamicFinding = t.hasFinding("flags: dynamic literal downgrades to FLAG-DYNAMIC-SET", dynamicFindings, "FLAG-DYNAMIC-SET")
if dynamicFinding then
  t.eq("flags: dynamic-set is info", dynamicFinding.severity, "info")
end
t.hasNoFinding("flags: no never-set warning when literal is dynamically settable", dynamicFindings, "FLAG-NEVER-SET")

local dynamicTrueProject = {
  mission = { trig = {
    actions = {},
    conditions = { [1] = "return(c_flag_is_true(\"Typo-Flag-Detruit\") )" },
  } },
  scriptText = 'local ListeTriggers = {"Correct-Flag-Detruit"}\ntrigger.action.setUserFlag(ListeTriggers[i],0)\n',
}
local typoFindings = flags.run(dynamicTrueProject)
local typoFinding = t.hasFinding("flags: non-literal flag stays never-set despite dynamic setter", typoFindings, "FLAG-NEVER-SET")
if typoFinding then
  t.eq("flags: true positive stays a warning", typoFinding.severity, "warning")
end
t.hasNoFinding("flags: typo flag is not downgraded", typoFindings, "FLAG-DYNAMIC-SET")
