local fs = require("lib.fileSystem")
local json = require("lib.json")

local M = {}

-- Mission files are plain data (`mission = {...}`); execute them in an empty
-- environment so a malformed or malicious file cannot touch the host. This is
-- the fallback path, used only when veaf-tools is not available (see below).
function M.loadLuaTable(path, globalName)
  local handle, openErr = io.open(path, "rb")
  if not handle then
    return nil, "cannot open " .. path .. ": " .. tostring(openErr)
  end
  local source = handle:read("*a")
  handle:close()

  local env = {}
  local chunk, parseErr = load(source, "@" .. path, "t", env)
  if not chunk then
    return nil, "lua parse error in " .. path .. ": " .. tostring(parseErr)
  end

  local ok, runErr = pcall(chunk)
  if not ok then
    return nil, "error evaluating " .. globalName .. " in " .. path .. ": " .. tostring(runErr)
  end

  local result = env[globalName]
  if type(result) ~= "table" then
    return nil, path .. " did not define global table '" .. globalName .. "'"
  end
  return result
end

-- ---------------------------------------------------------------------------
-- veaf-tools export path (safe parse — no Lua execution)
--
-- `veaf-tools export <input> --format json` parses mission/dictionary/mapResource
-- with a pure-Python state machine that never runs Lua, eliminating the code-
-- execution surface of loadLuaTable. We consume its frozen JSON contract
-- (schemaVersion 2) via json.decode. See doc/developer/export-json-contract.md.
-- ---------------------------------------------------------------------------

local SUPPORTED_SCHEMA = 2

local function quote(path)
  if fs.isWindows then
    return '"' .. path:gsub('"', "") .. '"'
  end
  return '"' .. path:gsub('"', '\\"') .. '"'
end

local function tempJsonPath()
  local dir = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
  M._counter = (M._counter or 0) + 1
  return dir .. "/mizlint-export-" .. tostring(os.time()) .. "-" .. tostring(M._counter) .. ".json"
end

local function succeeded(status)
  -- os.execute returns true (Lua 5.4) or 0 on success depending on the build
  return status == true or status == 0
end

-- Run a command with its output discarded. On Windows, `cmd /c` mis-parses a line
-- that starts with a quoted executable followed by more quoted arguments, so the
-- whole command is wrapped in one extra pair of quotes (cmd strips the outermost
-- pair, leaving the inner quoting intact).
local function runQuiet(inner)
  local redirected = inner .. (fs.isWindows and " >nul 2>nul" or " >/dev/null 2>&1")
  local cmd = fs.isWindows and ('"' .. redirected .. '"') or redirected
  return succeeded(os.execute(cmd))
end

-- The veaf-tools.exe vendored next to this tool, derived from this file's own
-- location (tools/src/lib/missionLoader.lua -> tools/bin/windows-x64/...). Only a
-- Windows binary is shipped, so this never resolves on other platforms (which keep
-- the lua54 fallback); the committed .exe is not runnable there anyway.
local function bundledVeafTools()
  if not fs.isWindows then return nil end
  local file = debug.getinfo(1, "S").source:match("^@(.*)$")
  local toolsDir = file and file:match("^(.*)[/\\]src[/\\]lib[/\\]missionLoader%.lua$")
  if not toolsDir then return nil end
  local exe = toolsDir .. "/bin/windows-x64/veaf-tools.exe"
  return fs.exists(exe) and exe or nil
end

-- Resolve the veaf-tools binary (memoized): the VEAF_TOOLS env var (path or name)
-- wins as an override, then the vendored binary, then `veaf-tools` on PATH.
-- Returns the command string, or nil if none is available.
local resolved, resolvedBin = false, nil
function M.resolveVeafTools()
  if resolved then return resolvedBin end
  resolved = true
  local env = os.getenv("VEAF_TOOLS")
  if env and env ~= "" then
    resolvedBin = env
  elseif bundledVeafTools() then
    resolvedBin = bundledVeafTools()
  elseif runQuiet(quote("veaf-tools") .. " --help") then
    resolvedBin = "veaf-tools"
  end
  return resolvedBin
end

-- Parse a mission project (folder or .miz) via veaf-tools export. Returns the
-- decoded contract object {schemaVersion, theatre, mission, dictionary,
-- mapResource}, or nil + error. When `extractDir` is given (used for a .miz
-- input), veaf-tools also unpacks the archive's embedded resources there.
function M.exportTables(input, extractDir)
  local bin = M.resolveVeafTools()
  if not bin then return nil, "veaf-tools not found (set VEAF_TOOLS or add it to PATH)" end

  local outFile = tempJsonPath()
  local args = {
    quote(bin), "export", quote(input), quote(outFile),
    "--format", "json", "--compact", "--no-pause",
  }
  if extractDir then
    args[#args + 1] = "--extract-dir"
    args[#args + 1] = quote(extractDir)
  end

  if not runQuiet(table.concat(args, " ")) then
    os.remove(outFile)
    return nil, "veaf-tools export failed for " .. input
  end

  local content, readErr = fs.readAll(outFile)
  os.remove(outFile)
  if not content then return nil, "veaf-tools produced no output for " .. input .. ": " .. tostring(readErr) end

  local ok, decoded = pcall(json.decode, content)
  if not ok then return nil, "cannot decode veaf-tools JSON for " .. input .. ": " .. tostring(decoded) end
  if decoded.schemaVersion ~= SUPPORTED_SCHEMA then
    return nil, "unsupported export schemaVersion " .. tostring(decoded.schemaVersion)
      .. " (this plugin supports " .. SUPPORTED_SCHEMA .. ")"
  end
  if type(decoded.mission) ~= "table" then
    return nil, "veaf-tools export for " .. input .. " has no mission table"
  end
  decoded.dictionary = decoded.dictionary or {}
  decoded.mapResource = decoded.mapResource or {}
  return decoded
end

return M
