local M = {}

M.entries = {
  {
    id = "edcore-precision-loss", layer = "engine-noise", severity = "noise",
    category = "engine-noise", noise = true, hint = "Renderer precision spam; safe to ignore.",
    when = { subsystem = "EDCORE", message = "Severe precision loss" },
  },
  {
    id = "edcore-fabsf-assert", layer = "engine-noise", severity = "noise",
    category = "engine-noise", noise = true, hint = "Renderer assert spam; safe to ignore.",
    when = { subsystem = "EDCORE", message = "Failed assert `fabsf" },
  },
  {
    id = "regmapstorage-exhausted", layer = "dcs-envelope", severity = "critical",
    category = "engine-fatal", noise = false, hint = "DCS ran out of map storage IDs; server needs a restart.",
    when = { message = "RegMapStorage has no more IDs" },
  },
  {
    id = "server-unlisted", layer = "dcs-envelope", severity = "critical",
    category = "networking", noise = false, hint = "Server was delisted from the master server.",
    when = { subsystem = "ASYNCNET", message = "will be unlisted" },
  },
  {
    id = "hook-load-failure", layer = "hook", severity = "critical",
    category = "hook-load", noise = false, hint = "A Hooks script failed to load; the feature it provides is off.",
    when = { subsystem = "APP", message = "Failed to load .*Hooks" },
  },
  {
    id = "mission-script-runtime", layer = "veaf", severity = "error",
    category = "mission-script-runtime", noise = false, hint = "Runtime error in a mission script; correlate to file:line.",
    when = { has_luaerror = true },
  },
  {
    id = "veaf-warning", layer = "veaf", severity = "warning",
    category = "veaf-warning", noise = false, hint = "A VEAF module reported a warning.",
    when = { veaf_level = "W" },
  },
  {
    id = "veaf-error", layer = "veaf", severity = "error",
    category = "veaf-error", noise = false, hint = "A VEAF module reported an error.",
    when = { veaf_level = "E" },
  },
}

local function matches(when, record)
  if when.subsystem and record.subsystem ~= when.subsystem then return false end
  if when.message and not (record.message and record.message:find(when.message)) then return false end
  if when.veaf_level and not (record.veaf and record.veaf.level == when.veaf_level) then return false end
  if when.has_luaerror and not record.luaerror then return false end
  return true
end

local function defaultFor(record)
  local severity = "info"
  if record.level == "ERROR" then severity = "error"
  elseif record.level == "WARNING" then severity = "warning" end
  return {
    id = "generic", layer = "dcs-envelope", severity = severity,
    category = "uncategorized", hint = nil, noise = false,
  }
end

function M.classify(record)
  if record.kind ~= "log" then return defaultFor(record) end
  for _, entry in ipairs(M.entries) do
    if matches(entry.when, record) then
      return {
        id = entry.id, layer = entry.layer, severity = entry.severity,
        category = entry.category, hint = entry.hint, noise = entry.noise,
      }
    end
  end
  return defaultFor(record)
end

return M
