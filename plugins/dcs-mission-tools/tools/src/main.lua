local here = arg[0]:match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. package.path

local fs = require("lib.fileSystem")
local json = require("lib.json")
local model = require("lib.missionModel")
local projection = require("lib.projection")

local CHECKS = {}
CHECKS[#CHECKS + 1] = require("checks.resources")
CHECKS[#CHECKS + 1] = require("checks.triggers")
CHECKS[#CHECKS + 1] = require("checks.loading")
CHECKS[#CHECKS + 1] = require("checks.flags")
CHECKS[#CHECKS + 1] = require("checks.names")

local USAGE = [[
mizlint — static analysis for DCS World missions (VEAF template)

Usage:
  mizlint <check>|all <path> [--json] [--checks-dir <dir>]
  mizlint coords <theatre> <x> <y> [--json]
  mizlint list
  mizlint help

<path> is a mission project (folder containing src/mission), a src/mission
folder, or a folder containing several mission projects.
Exit codes: 0 clean, 1 warnings only, 2 errors, 3 execution failure.
]]

local function fail(message)
  io.stderr:write("mizlint: ", message, "\n")
  os.exit(3)
end

local function parseArgs()
  local options = { positional = {} }
  local i = 1
  while i <= #arg do
    if arg[i] == "--json" then
      options.json = true
    elseif arg[i] == "--checks-dir" then
      i = i + 1
      options.checksDir = arg[i] or fail("--checks-dir needs a value")
    else
      options.positional[#options.positional + 1] = arg[i]
    end
    i = i + 1
  end
  return options
end

local function loadExtraChecks(dir)
  for _, path in ipairs(fs.listFiles(dir)) do
    if path:match("%.lua$") then
      local chunk, err = loadfile(path)
      if not chunk then fail("cannot load extra check " .. path .. ": " .. tostring(err)) end
      local module = chunk()
      if type(module) ~= "table" or type(module.run) ~= "function" or not module.name then
        fail(path .. " is not a valid check module (must return {name=..., run=function})")
      end
      CHECKS[#CHECKS + 1] = module
    end
  end
end

local function discoverProjects(path)
  path = path:gsub("[/\\]+$", "")
  if path:match("%.miz$") and fs.exists(path) then
    return { path }
  end
  if fs.exists(fs.join(path, "src", "mission", "mission"))
     or fs.exists(fs.join(path, "mission")) then
    return { path }
  end
  local projects = {}
  for _, candidate in ipairs(fs.listDirs(path)) do
    if fs.exists(fs.join(candidate, "src", "mission", "mission")) then
      projects[#projects + 1] = candidate
    end
  end
  return projects
end

local function runChecks(checkName, projectPath, allFindings)
  local project, err = model.loadProject(projectPath)
  if not project then fail(err) end
  for _, check in ipairs(CHECKS) do
    local selected = checkName == "all" or check.name == checkName
    local applicable = check.layer ~= "vmct" or project.hasVmctMarkers
    if selected and applicable then
      for _, finding in ipairs(check.run(project)) do
        finding.project = project.root
        -- For a .miz there is no source tree on disk; drop the checks' hardcoded
        -- "src/mission/mission" file hint so it does not mislead.
        if project.isMiz and finding.file == "src/mission/mission" then
          finding.file = nil
        end
        allFindings[#allFindings + 1] = finding
      end
    end
  end
end

local SEVERITY_ORDER = { error = 1, warning = 2, info = 3 }

local function report(findings, asJson, allProjects)
  if asJson then
    io.write(json.encode(findings), "\n")
  else
    table.sort(findings, function(a, b)
      if a.project ~= b.project then return tostring(a.project) < tostring(b.project) end
      if a.severity ~= b.severity then
        return SEVERITY_ORDER[a.severity] < SEVERITY_ORDER[b.severity]
      end
      return a.code < b.code
    end)
    local projectsWithFindings = {}
    local lastProject = nil
    for _, f in ipairs(findings) do
      if f.project ~= lastProject then
        io.write("\n", f.project, "\n")
        lastProject = f.project
        projectsWithFindings[f.project] = true
      end
      io.write(string.format("  %-7s %-22s %s%s\n",
        f.severity:upper(), f.code, f.message, f.file and (" [" .. f.file .. "]") or ""))
      if f.detail then io.write("          ", f.detail, "\n") end
    end
    if allProjects then
      table.sort(allProjects)
      for _, projectPath in ipairs(allProjects) do
        if not projectsWithFindings[projectPath] then
          io.write("\n", projectPath, "\n")
          io.write("  (no findings)\n")
        end
      end
    end
  end

  local errors, warnings = 0, 0
  for _, f in ipairs(findings) do
    if f.severity == "error" then errors = errors + 1
    elseif f.severity == "warning" then warnings = warnings + 1 end
  end
  if not asJson then
    io.write(string.format("\n%d error(s), %d warning(s), %d finding(s) total\n",
      errors, warnings, #findings))
  end
  if errors > 0 then os.exit(2) end
  if warnings > 0 then os.exit(1) end
  os.exit(0)
end

local options = parseArgs()
local command = options.positional[1]

if command == nil or command == "help" or command == "--help" then
  io.write(USAGE)
  os.exit(command and 0 or 3)
end

if command == "list" then
  for _, check in ipairs(CHECKS) do
    io.write(check.name, "  (layer: ", check.layer, ")\n")
  end
  os.exit(0)
end

if command == "coords" then
  local theatre, x, y = options.positional[2], tonumber(options.positional[3]), tonumber(options.positional[4])
  if not theatre or not x or not y then fail("usage: mizlint coords <theatre> <x> <y>") end
  local lat, lon = projection.xyToLatLon(theatre, x, y)
  if not lat then fail(lon) end
  if options.json then
    io.write(json.encode({ lat = lat, lon = lon }), "\n")
  else
    io.write(string.format("lat %.6f  lon %.6f\n", lat, lon))
  end
  os.exit(0)
end

local knownCheck = command == "all"
for _, check in ipairs(CHECKS) do
  if check.name == command then knownCheck = true end
end
if not knownCheck then fail("unknown check '" .. command .. "' (try: mizlint list)") end

local targetPath = options.positional[2] or fail("missing <path>\n" .. USAGE)
if options.checksDir then loadExtraChecks(options.checksDir) end

local projects = discoverProjects(targetPath)
if #projects == 0 then fail("no mission project found under " .. targetPath) end

local allFindings = {}
for _, projectPath in ipairs(projects) do
  runChecks(command, projectPath, allFindings)
end
report(allFindings, options.json, projects)
