local findingsLib = require("lib.findings")

local M = { name = "flags", layer = "vanilla" }

local SET_PATTERNS = {
  'a_set_flag%(\\?"([^"\\]+)\\?"',
  'setUserFlag%(%s*"([^"]+)"',
  "setUserFlag%(%s*'([^']+)'",
}
local READ_PATTERNS = {
  'c_flag_is_true%(\\?"([^"\\]+)\\?"',
  'c_flag_is_false%(\\?"([^"\\]+)\\?"',
  'c_time_since_flag%(\\?"([^"\\]+)\\?"',
  'getUserFlag%(%s*"([^"]+)"',
  "getUserFlag%(%s*'([^']+)'",
}

local function collect(text, patterns, into)
  for _, pattern in ipairs(patterns) do
    for flag in text:gmatch(pattern) do into[flag] = true end
  end
end

function M.run(project)
  local findings, add = findingsLib.collector(M.name)

  local trigText = {}
  local trig = project.mission.trig or {}
  for _, section in ipairs({ "actions", "conditions" }) do
    for _, chunk in pairs(trig[section] or {}) do
      if type(chunk) == "string" then trigText[#trigText + 1] = chunk end
    end
  end
  local missionText = table.concat(trigText, "\n")

  local setFlags, readFlags = {}, {}
  collect(missionText, SET_PATTERNS, setFlags)
  collect(missionText, READ_PATTERNS, readFlags)
  collect(project.scriptText, SET_PATTERNS, setFlags)
  collect(project.scriptText, READ_PATTERNS, readFlags)

  local sortedReads = {}
  for flag in pairs(readFlags) do sortedReads[#sortedReads + 1] = flag end
  table.sort(sortedReads)
  for _, flag in ipairs(sortedReads) do
    if not setFlags[flag] then
      add("warning", "FLAG-NEVER-SET",
        "flag '" .. flag .. "' is tested but never set by any trigger or mission script")
    end
  end

  local sortedSets = {}
  for flag in pairs(setFlags) do sortedSets[#sortedSets + 1] = flag end
  table.sort(sortedSets)
  for _, flag in ipairs(sortedSets) do
    if not readFlags[flag] then
      add("info", "FLAG-NEVER-READ",
        "flag '" .. flag .. "' is set but never tested — dead flag or external consumer")
    end
  end

  return findings
end

return M
