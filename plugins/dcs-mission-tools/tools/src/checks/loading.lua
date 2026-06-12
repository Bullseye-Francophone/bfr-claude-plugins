local fs = require("lib.fileSystem")
local resolver = require("lib.resolver")
local findingsLib = require("lib.findings")

local M = { name = "loading", layer = "vmct" }

local function findTrigAction(trig, marker)
  for index, chunk in ipairs(trig.actions or {}) do
    if type(chunk) == "string" and chunk:find(marker, 1, true) then
      return index, chunk
    end
  end
  return nil
end

local function dynamicScripts(chunk)
  local names = {}
  for path in chunk:gmatch('loadfile%(VEAF_DYNAMIC_PATH %.%. \\?"([^"\\]+)\\?"%)') do
    names[#names + 1] = path:match("([^/\\]+)$")
  end
  return names
end

local function staticScripts(chunk, mapResource)
  local names = {}
  for _, key in ipairs(resolver.extractKeys(chunk, "getValueResourceByKey")) do
    names[#names + 1] = mapResource[key] or ("<undeclared:" .. key .. ">")
  end
  return names
end

local function toSet(list)
  local set = {}
  for _, item in ipairs(list) do set[item] = true end
  return set
end

function M.run(project)
  local findings, add = findingsLib.collector(M.name)
  local trig = project.mission.trig or {}

  local _, dynamicChunk = findTrigAction(trig, "DYNAMIC SCRIPTS LOADING")
  local _, staticChunk = findTrigAction(trig, "STATIC SCRIPTS LOADING")

  if dynamicChunk and staticChunk then
    local dynamicList = dynamicScripts(dynamicChunk)
    local staticList = staticScripts(staticChunk, project.mapResource)

    if staticList[1] ~= "mist.lua" then
      add("error", "LOAD-MIST-FIRST",
        "static loading does not load mist.lua first (got '" ..
        tostring(staticList[1]) .. "') — every MIST/VMCT call will fail",
        "src/mission/mission")
    end
    if dynamicList[1] ~= "mist.lua" then
      add("error", "LOAD-MIST-FIRST",
        "dynamic loading does not load mist.lua first (got '" ..
        tostring(dynamicList[1]) .. "')", "src/mission/mission")
    end

    local IGNORED = { ["veaf-scripts.lua"] = true, ["VeafDynamicLoader.lua"] = true }
    local dynamicSet, staticSet = toSet(dynamicList), toSet(staticList)
    for _, name in ipairs(staticList) do
      if not IGNORED[name] and not dynamicSet[name] then
        add("error", "LOAD-PARITY",
          name .. " is loaded in static mode but not in dynamic mode — the two modes diverge",
          "src/mission/mission")
      end
    end
    for _, name in ipairs(dynamicList) do
      if not IGNORED[name] and not staticSet[name] then
        add("error", "LOAD-PARITY",
          name .. " is loaded in dynamic mode but not in static mode — the two modes diverge",
          "src/mission/mission")
      end
    end
  end

  for _, keySuffix in ipairs({ "10501", "10502" }) do
    local key = "DictKey_ActionText_" .. keySuffix
    local value = project.dictionary[key]
    if type(value) == "string" and not value:match("^return%s+false%f[%s\0]") then
      add("warning", "LOAD-COMMITTED-STATE",
        key .. " is '" .. value .. "' — committed missions should be in static state " ..
        "('return false ...'); this looks like an un-extracted build artifact",
        "l10n/DEFAULT/dictionary")
    end
  end

  for _, path in ipairs(fs.listFiles(project.root)) do
    local relative = path:sub(#project.root + 2)
    if relative:match("%.miz$") and not relative:find("/") then
      add("warning", "LOAD-MIZ-AT-ROOT",
        relative .. " sits at the project root — extract it (or delete it) before committing",
        relative)
    end
  end

  for _, moduleName in pairs(project.mission.requiredModules or {}) do
    add("warning", "LOAD-REQUIRED-MODULES",
      "requiredModules contains '" .. tostring(moduleName) ..
      "' — players without this mod cannot join unless the build neutralizes it",
      "src/mission/mission")
  end

  return findings
end

return M
