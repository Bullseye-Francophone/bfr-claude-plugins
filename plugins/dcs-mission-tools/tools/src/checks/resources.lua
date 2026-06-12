local resolver = require("lib.resolver")
local findingsLib = require("lib.findings")

local M = { name = "resources", layer = "vanilla" }

local function normalizeForCompare(name)
  local normalized = name
  normalized = normalized:gsub("├®", "é"):gsub("├¿", "è"):gsub("├á", "à")
    :gsub("├¬", "ê"):gsub("├ç", "ç"):gsub("├┤", "ô"):gsub("├«", "î")
    :gsub("├╣", "ù"):gsub("├╗", "û"):gsub("├»", "ï"):gsub("├╝", "ü"):gsub("├ó", "â")
  return normalized
end

function M.run(project)
  local findings, add = findingsLib.collector(M.name)
  local refs = resolver.collectReferences(project.mission)

  local injected = {}
  for base in pairs(project.communityScripts) do injected[base] = true end
  for _, path in ipairs(project.scriptFiles) do
    injected[path:match("([^/\\]+)$")] = true
  end

  local function isInjected(fileName)
    if injected[fileName] then return true end
    if project.hasVmctMarkers and fileName:match("^veaf%-scripts?.*%.lua$") then return true end
    return false
  end

  local referencedKeys = { dict = {}, resource = {} }
  local reportedUndeclared = {}
  for _, ref in ipairs(refs) do
    referencedKeys[ref.namespace][ref.key] = true
    local table_ = ref.namespace == "dict" and project.dictionary or project.mapResource
    local dedupeKey = ref.namespace .. ":" .. ref.key
    if table_[ref.key] == nil and not reportedUndeclared[dedupeKey] then
      reportedUndeclared[dedupeKey] = true
      add("error", "RES-UNDECLARED-KEY",
        ref.key .. " is referenced (" .. ref.where .. ") but not declared in " ..
        (ref.namespace == "dict" and "dictionary" or "mapResource"),
        ref.namespace == "dict" and "l10n/DEFAULT/dictionary" or "l10n/DEFAULT/mapResource")
    end
  end

  local declaredFiles = {}
  for key, fileName in pairs(project.mapResource) do
    declaredFiles[fileName] = true
    if not referencedKeys.resource[key] then
      add("warning", "RES-ORPHAN-KEY",
        key .. " is declared in mapResource but never referenced", "l10n/DEFAULT/mapResource")
    end
    if not project.l10nFiles[fileName] and not isInjected(fileName) then
      local matched = false
      for onDisk in pairs(project.l10nFiles) do
        if normalizeForCompare(onDisk) == normalizeForCompare(fileName)
           and onDisk ~= fileName then
          add("error", "RES-ENCODING",
            key .. " declares '" .. fileName .. "' but the file on disk is named '" ..
            onDisk .. "' (encoding mismatch, briefing/sound will break at build)",
            "l10n/DEFAULT/" .. onDisk)
          matched = true
          break
        end
      end
      if not matched then
        add("error", "RES-MISSING-FILE",
          key .. " declares '" .. fileName ..
          "' but no such file exists in l10n/DEFAULT nor in the build-injected script set",
          "l10n/DEFAULT/mapResource")
      end
    end
  end

  for key in pairs(project.dictionary) do
    if not referencedKeys.dict[key] then
      add("warning", "RES-ORPHAN-KEY",
        key .. " is declared in dictionary but never referenced", "l10n/DEFAULT/dictionary")
    end
  end

  for fileName in pairs(project.l10nFiles) do
    if not declaredFiles[fileName] then
      local declaredEquivalent = false
      for declared in pairs(declaredFiles) do
        if normalizeForCompare(declared) == normalizeForCompare(fileName) then
          declaredEquivalent = true
        end
      end
      if not declaredEquivalent then
        add("warning", "RES-ORPHAN-FILE",
          fileName .. " exists in l10n/DEFAULT but is not declared in mapResource",
          "l10n/DEFAULT/" .. fileName)
      end
    end
  end

  return findings
end

return M
