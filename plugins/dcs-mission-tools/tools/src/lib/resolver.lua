local M = {}

-- Extract the quoted first argument of every `funcName("...")` call in a chunk
-- of compiled trigger code. Keys never contain quotes, so a simple capture is
-- exact (and inherently word-anchored: the closing quote ends the key).
function M.extractKeys(text, funcName)
  local keys = {}
  for key in text:gmatch(funcName .. '%(\\?"([^"\\]+)\\?"%)') do
    keys[#keys + 1] = key
  end
  return keys
end

local MISSION_DICT_FIELDS = {
  "descriptionText", "sortie",
  "descriptionBlueTask", "descriptionRedTask", "descriptionNeutralsTask",
}
local MISSION_RESOURCE_LIST_FIELDS = {
  "pictureFileNameB", "pictureFileNameR", "pictureFileNameN",
}

-- Returns an array of {key, namespace="dict"|"resource", where}
function M.collectReferences(mission)
  local refs = {}
  local function add(key, namespace, where)
    if type(key) == "string" and key ~= "" then
      refs[#refs + 1] = { key = key, namespace = namespace, where = where }
    end
  end

  for _, field in ipairs(MISSION_DICT_FIELDS) do
    add(mission[field], "dict", "mission." .. field)
  end
  for _, field in ipairs(MISSION_RESOURCE_LIST_FIELDS) do
    for _, key in pairs(mission[field] or {}) do
      add(key, "resource", "mission." .. field)
    end
  end

  local trig = mission.trig or {}
  for _, section in ipairs({ "actions", "conditions", "funcStartup", "func" }) do
    for index, chunk in pairs(trig[section] or {}) do
      if type(chunk) == "string" then
        local where = "trig." .. section .. "[" .. tostring(index) .. "]"
        for _, key in ipairs(M.extractKeys(chunk, "getValueResourceByKey")) do
          add(key, "resource", where)
        end
        for _, key in ipairs(M.extractKeys(chunk, "getValueDictByKey")) do
          add(key, "dict", where)
        end
      end
    end
  end

  for ruleIndex, rule in pairs(mission.trigrules or {}) do
    local where = "trigrules[" .. tostring(ruleIndex) .. "]"
    for _, action in pairs(rule.actions or {}) do
      add(action.file, "resource", where .. ".actions")
    end
    for _, condition in pairs(rule.rules or {}) do
      if type(condition.text) == "string" and condition.text:match("^DictKey_") then
        add(condition.text, "dict", where .. ".rules")
      end
      add(condition.KeyDict_text, "dict", where .. ".rules")
    end
  end

  return refs
end

return M
