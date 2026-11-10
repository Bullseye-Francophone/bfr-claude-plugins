local here = arg[0]:match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. package.path

local fs = require("lib.fileSystem")
local json = require("lib.json")
local pipeline = require("logreduce.pipeline")

local USAGE = [[
logreduce — reduce a DCS dcs.log to a structured JSON digest

Usage:
  logreduce [--once] <logfile> [--threshold critical|error|warning|info]
  logreduce <logfile> --follow [--threshold ...]

--once (the default) prints one JSON digest. --follow prints one JSON event per line.
Exit codes: 0 ok, 3 execution failure.
]]

local function fail(message)
  io.stderr:write("logreduce: ", message, "\n")
  os.exit(3)
end

local options = { positional = {}, threshold = "warning" }
local i = 1
while i <= #arg do
  if arg[i] == "--follow" then options.follow = true
  elseif arg[i] == "--once" then options.once = true
  elseif arg[i] == "--threshold" then i = i + 1; options.threshold = arg[i] or fail("--threshold needs a value")
  else options.positional[#options.positional + 1] = arg[i] end
  i = i + 1
end

if options.once and options.follow then fail("--once and --follow are mutually exclusive") end

local path = options.positional[1]
if not path or path == "help" then io.write(USAGE); os.exit(path and 0 or 3) end

local VALID_THRESHOLDS = { critical = true, error = true, warning = true, info = true }
if not VALID_THRESHOLDS[options.threshold] then
  fail("invalid --threshold '" .. options.threshold .. "' (expected critical|error|warning|info)")
end

local function sleep(seconds)
  local completed
  if fs.isWindows then completed = os.execute("ping -n " .. (seconds + 1) .. " 127.0.0.1 >nul")
  else completed = os.execute("sleep " .. seconds) end
  return completed == true
end

if options.follow then
  local session = pipeline.newFollowSession(path, options,
    function(event) io.write(json.encode(event), "\n"); io.flush() end,
    function(notice) io.stderr:write("logreduce: ", notice, "\n") end)
  repeat
    local isRunning, failure = session.tick()
    if not isRunning then fail(failure) end
  until not sleep(1)
  session.finish()
else
  local digest, err = pipeline.runOnce(path, options)
  if not digest then fail(err) end
  io.write(json.encode(digest), "\n")
end
