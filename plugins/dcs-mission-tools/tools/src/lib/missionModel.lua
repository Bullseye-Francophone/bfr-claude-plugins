local fs = require("lib.fileSystem")
local loader = require("lib.missionLoader")

local M = {}

local GROUP_CATEGORIES = { "plane", "helicopter", "vehicle", "ship", "static" }
local COALITIONS = { "blue", "red", "neutrals" }

function M.zoneNames(mission)
  local names = {}
  local zones = mission.triggers and mission.triggers.zones or {}
  for _, zone in pairs(zones) do
    if type(zone) == "table" and zone.name then names[zone.name] = true end
  end
  return names
end

function M.groupNames(mission)
  local names = {}
  for _, coalitionName in ipairs(COALITIONS) do
    local coalition = mission.coalition and mission.coalition[coalitionName]
    local countries = coalition and coalition.country or {}
    for _, country in pairs(countries) do
      for _, category in ipairs(GROUP_CATEGORIES) do
        local groups = country[category] and country[category].group or {}
        for _, group in pairs(groups) do
          if type(group) == "table" and group.name then names[group.name] = true end
        end
      end
    end
  end
  return names
end

local function indexBasenames(paths)
  local set = {}
  for _, path in ipairs(paths) do set[fs.basename(path)] = true end
  return set
end

local function detectVmctMarkers(dictionary)
  local predicate = dictionary["DictKey_ActionText_10501"]
  return type(predicate) == "string" and predicate:find("-- scripts", 1, true) ~= nil
end

local extractCounter = 0
local function tempExtractDir()
  local dir = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
  extractCounter = extractCounter + 1
  return dir .. "/mizlint-miz-" .. tostring(os.time()) .. "-" .. tostring(extractCounter)
end

-- An extracted VEAF mission project: src/mission tree + src/scripts + node_modules.
local function loadFolder(root)
  local missionDir = fs.join(root, "src", "mission")
  if not fs.exists(fs.join(missionDir, "mission")) then
    if fs.exists(fs.join(root, "mission")) and root:match("src[/\\]mission$") then
      missionDir = root
      root = root:gsub("[/\\]src[/\\]mission$", "")
    else
      return nil, root .. " is not a mission project (no src/mission/mission file)"
    end
  end

  local l10nDir = fs.join(missionDir, "l10n", "DEFAULT")

  -- veaf-tools is the parser whenever it is available (safe pure-Python parse, no
  -- Lua execution). If it is present but fails, that is a hard error: we must NOT
  -- fall back to executing the file's Lua, which could be hostile. The sandboxed
  -- lua54 loader runs only as the degraded path when veaf-tools is absent entirely.
  local mission, dictionary, mapResource
  if loader.resolveVeafTools() then
    local exported, err = loader.exportTables(root)
    if not exported then return nil, err end
    mission, dictionary, mapResource = exported.mission, exported.dictionary, exported.mapResource
  else
    local err
    mission, err = loader.loadLuaTable(fs.join(missionDir, "mission"), "mission")
    if not mission then return nil, err end
    dictionary, err = loader.loadLuaTable(fs.join(l10nDir, "dictionary"), "dictionary")
    if not dictionary then return nil, err end
    mapResource, err = loader.loadLuaTable(fs.join(l10nDir, "mapResource"), "mapResource")
    if not mapResource then return nil, err end
  end

  local l10nFiles = {}
  for _, path in ipairs(fs.listFiles(l10nDir)) do
    local base = fs.basename(path)
    if base ~= "dictionary" and base ~= "mapResource" then l10nFiles[base] = true end
  end

  local scriptFiles, scriptChunks = {}, {}
  local scriptsDir = fs.join(root, "src", "scripts")
  for _, path in ipairs(fs.listFiles(scriptsDir)) do
    if path:match("%.lua$") then
      scriptFiles[#scriptFiles + 1] = path
      scriptChunks[#scriptChunks + 1] = "-- FILE: " .. path .. "\n" .. (fs.readAll(path) or "")
    end
  end

  local communityDir = fs.join(root, "node_modules", "veaf-mission-creation-tools", "src", "scripts", "community")
  local communityScripts = indexBasenames(fs.listFiles(communityDir))

  return {
    root = root,
    missionDir = missionDir,
    l10nDir = l10nDir,
    mission = mission,
    dictionary = dictionary,
    mapResource = mapResource,
    theatre = mission.theatre,
    l10nFiles = l10nFiles,
    scriptFiles = scriptFiles,
    scriptText = table.concat(scriptChunks, "\n"),
    communityScripts = communityScripts,
    hasVmctMarkers = detectVmctMarkers(dictionary),
  }
end

-- A packed .miz: veaf-tools parses the data tables and extracts the embedded
-- resources. The archive is flat -- every *.lua under l10n/DEFAULT is a real
-- runtime script (mission + framework + community), so they all populate
-- scriptText/scriptFiles and count as injected (communityScripts), which is what
-- makes a built artifact "complete"; the rest of l10n/DEFAULT is sounds/images.
-- Module-specific resources (kneeboards, A-10 radio presets) live outside
-- l10n/DEFAULT and are intentionally ignored here.
local function loadMiz(mizPath)
  local extractDir = tempExtractDir()
  local exported, err = loader.exportTables(mizPath, extractDir)
  if not exported then
    return nil, "cannot read " .. mizPath .. ": " .. (err or "veaf-tools export failed")
  end

  local l10nDir = fs.join(extractDir, "l10n", "DEFAULT")
  local scriptFiles, scriptChunks, communityScripts, l10nFiles = {}, {}, {}, {}
  for _, path in ipairs(fs.listFiles(l10nDir)) do
    local base = fs.basename(path)
    if path:match("%.lua$") then
      scriptFiles[#scriptFiles + 1] = path
      scriptChunks[#scriptChunks + 1] = "-- FILE: " .. path .. "\n" .. (fs.readAll(path) or "")
      communityScripts[base] = true
    elseif base ~= "dictionary" and base ~= "mapResource" then
      l10nFiles[base] = true
    end
  end

  return {
    root = mizPath, -- display name; also makes LOAD-MIZ-AT-ROOT a no-op (a file lists empty)
    missionDir = extractDir,
    l10nDir = l10nDir,
    mission = exported.mission,
    dictionary = exported.dictionary,
    mapResource = exported.mapResource,
    theatre = exported.mission.theatre,
    l10nFiles = l10nFiles,
    scriptFiles = scriptFiles,
    scriptText = table.concat(scriptChunks, "\n"),
    communityScripts = communityScripts,
    hasVmctMarkers = detectVmctMarkers(exported.dictionary),
  }
end

-- Load a mission project from either a packed `.miz` file or an extracted
-- mission folder, returning the project object the checks consume.
function M.loadProject(input)
  input = input:gsub("[/\\]+$", "")
  if input:match("%.miz$") and fs.exists(input) then
    return loadMiz(input)
  end
  return loadFolder(input)
end

return M
