local model = require("lib.missionModel")
local findingsLib = require("lib.findings")

local M = { name = "names", layer = "mist" }

local EDITOR_ZONE_NAME_PATTERN = ':setMissionEditorZoneName%(%s*"([^"]+)"'
local OPERATION_CONSTRUCTOR_PATTERN = 'VeafCombatOperation%s*[:.]%s*new%s*%('
local ANY_VEAF_CONSTRUCTOR_PATTERN = 'Veaf%w*%s*[:.]%s*new%s*%('

local ZONE_PATTERNS = {
  'veafCombatZone%.ActivateZone%(\\?"([^"\\]+)\\?"',
  'veafCombatZone%.DesactivateZone%(\\?"([^"\\]+)\\?"',
  EDITOR_ZONE_NAME_PATTERN,
  'mist%.DBs%.zonesByName%[%s*"([^"]+)"',
}
local GROUP_PATTERNS = {
  'mist%.DBs%.groupsByName%[%s*"([^"]+)"',
  'Group%.getByName%(%s*"([^"]+)"',
  ':setGroupName%(%s*"([^"]+)"',
}

local function collect(text, patterns, into)
  for _, pattern in ipairs(patterns) do
    for name in text:gmatch(pattern) do into[name] = true end
  end
end

local function collectOperationZoneNames(text, into)
  local searchFrom = 1
  while true do
    local _, constructorEnd = text:find(OPERATION_CONSTRUCTOR_PATTERN, searchFrom)
    if not constructorEnd then return end
    local nextConstructorStart = text:find(ANY_VEAF_CONSTRUCTOR_PATTERN, constructorEnd + 1)
    local declarationChain = text:sub(constructorEnd + 1, (nextConstructorStart or #text + 1) - 1)
    for name in declarationChain:gmatch(EDITOR_ZONE_NAME_PATTERN) do into[name] = true end
    searchFrom = constructorEnd + 1
  end
end

function M.run(project)
  local findings, add = findingsLib.collector(M.name)

  local trigChunks = {}
  for _, section in ipairs({ "actions", "conditions" }) do
    for _, chunk in pairs((project.mission.trig or {})[section] or {}) do
      if type(chunk) == "string" then trigChunks[#trigChunks + 1] = chunk end
    end
  end
  local allText = table.concat(trigChunks, "\n") .. "\n" .. project.scriptText

  local referencedZones, referencedGroups, operationNames = {}, {}, {}
  collect(allText, ZONE_PATTERNS, referencedZones)
  collect(allText, GROUP_PATTERNS, referencedGroups)
  collectOperationZoneNames(allText, operationNames)

  local zones = model.zoneNames(project.mission)
  local groups = model.groupNames(project.mission)

  local sortedZones = {}
  for name in pairs(referencedZones) do sortedZones[#sortedZones + 1] = name end
  table.sort(sortedZones)
  for _, name in ipairs(sortedZones) do
    if not zones[name] and not operationNames[name] then
      add("error", "NAME-ZONE-MISSING",
        "trigger zone '" .. name .. "' is referenced by scripts/triggers but does not exist in the mission")
    end
  end

  local sortedGroups = {}
  for name in pairs(referencedGroups) do sortedGroups[#sortedGroups + 1] = name end
  table.sort(sortedGroups)
  for _, name in ipairs(sortedGroups) do
    if not groups[name] then
      add("warning", "NAME-GROUP-MISSING",
        "group '" .. name .. "' is referenced by scripts but not present in the mission " ..
        "(fine if it is spawned at runtime)")
    end
  end

  return findings
end

return M
