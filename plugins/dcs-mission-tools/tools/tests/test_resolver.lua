local t = require("helpers")
local model = require("lib.missionModel")
local resolver = require("lib.resolver")

local project = model.loadProject("plugins/dcs-mission-tools/tools/tests/fixtures/clean")
local refs = resolver.collectReferences(project.mission)

local function find(refs, key, namespace)
  for _, r in ipairs(refs) do
    if r.key == key and r.namespace == namespace then return r end
  end
  return nil
end

t.check("resolver: VEAF 102xx key goes to mapResource despite DictKey prefix",
  find(refs, "DictKey_ActionText_10202", "resource") ~= nil)
t.check("resolver: trigrules file field is resource",
  find(refs, "DictKey_ActionText_10309", "resource") ~= nil)
t.check("resolver: predicate keys are dictionary",
  find(refs, "DictKey_ActionText_10501", "dict") ~= nil)
t.check("resolver: 10501 not also resource",
  find(refs, "DictKey_ActionText_10501", "resource") == nil)
t.check("resolver: mission descriptionText is dictionary",
  find(refs, "DictKey_descriptionText_1", "dict") ~= nil)
t.check("resolver: pictureFileNameB is resource",
  find(refs, "ResKey_ImageBriefing_1", "resource") ~= nil)
t.check("resolver: sortie is dictionary",
  find(refs, "DictKey_sortie_2", "dict") ~= nil)

t.eq("resolver: anchored extraction does not truncate keys",
  resolver.extractKeys('getValueResourceByKey("DictKey_ActionText_1044")', "getValueResourceByKey"),
  { "DictKey_ActionText_1044" })
