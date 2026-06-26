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

function M.loadProject(root)
  root = root:gsub("[/\\]+$", "")
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

  -- Prefer veaf-tools (safe pure-Python parse, no Lua execution); fall back to
  -- the sandboxed lua54 loader when veaf-tools is not installed.
  local mission, dictionary, mapResource
  local exported = loader.exportTables(root)
  if exported then
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

  local predicate = dictionary["DictKey_ActionText_10501"]
  local hasVmctMarkers = type(predicate) == "string" and predicate:find("-- scripts", 1, true) ~= nil

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
    hasVmctMarkers = hasVmctMarkers,
  }
end

return M
