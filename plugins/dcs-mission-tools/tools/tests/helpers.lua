local M = { passed = 0, failed = 0, skipped = 0, errors = {} }

M.isWindows = package.config:sub(1, 1) == "\\"

local function dump(v, depth)
  depth = depth or 0
  if depth > 4 then return "..." end
  if type(v) == "table" then
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts + 1] = tostring(k) .. "=" .. dump(val, depth + 1)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

function M.check(label, ok, extra)
  if ok then
    M.passed = M.passed + 1
  else
    M.failed = M.failed + 1
    M.errors[#M.errors + 1] = label .. (extra and (" — " .. extra) or "")
    io.write("FAIL: ", label, extra and ("\n      " .. extra) or "", "\n")
  end
end

-- An explicit, counted skip: for an assertion that is meaningless on this platform.
function M.skip(label, reason)
  M.skipped = M.skipped + 1
  io.write("SKIP: ", label, "\n      ", reason, "\n")
end

-- ---------------------------------------------------------------------------
-- Portable process / temp-file plumbing. On POSIX these keep the exact shell
-- idioms the suite always used; on Windows they go through cmd.
-- ---------------------------------------------------------------------------

-- A fresh path (nothing created) in the system temp directory. On Windows,
-- os.tmpname() names a file at the drive root, so TEMP is used instead, with
-- '/' separators so the path also works inside sh.
local tempCounter = 0
function M.tempPath(suffix)
  if not M.isWindows then
    local path = os.tmpname()
    os.remove(path)
    return path .. (suffix or "")
  end
  tempCounter = tempCounter + 1
  local dir = (os.getenv("TEMP") or os.getenv("TMP") or "."):gsub("\\", "/")
  return string.format("%s/mizlint-test-%d-%d-%d%s",
    dir, os.time(), math.random(1, 1000000000), tempCounter, suffix or "")
end

function M.makeDirs(path)
  if M.isWindows then
    os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
  else
    os.execute('mkdir -p "' .. path .. '"')
  end
end

function M.removeTree(path)
  if M.isWindows then
    os.execute('rmdir /s /q "' .. path:gsub("/", "\\") .. '" 2>nul')
  else
    os.execute('rm -rf "' .. path .. '"')
  end
end

-- The interpreter running this suite, quoted for the platform shell, so the CLI
-- tests exercise the same Lua whatever the host (arg[-n] is the interpreter).
function M.luaCommand()
  local first = 0
  while arg and arg[first - 1] do first = first - 1 end
  local interpreter = (arg and first < 0 and arg[first]) or "lua"
  if M.isWindows then interpreter = interpreter:gsub("/", "\\") end
  return '"' .. interpreter .. '"'
end

-- Runs a command line in the platform shell (sh on POSIX, cmd on Windows) and
-- returns its combined stdout+stderr and its exit code. POSIX keeps the
-- `echo EXIT:$?` capture; cmd has no $?, but there io.popen's close() returns
-- the exit code (the extra quote pair is stripped by cmd /c, keeping inner quotes).
function M.run(command)
  if M.isWindows then
    local proc = io.popen('"' .. command .. ' 2>&1"')
    local output = proc:read("a")
    local _, _, code = proc:close()
    return output, code
  end
  local proc = io.popen(command .. " 2>&1; echo EXIT:$?")
  local output = proc:read("a")
  proc:close()
  local code = tonumber(output:match("EXIT:(%d+)%s*$"))
  return (output:gsub("EXIT:%d+%s*$", "")), code
end

-- Whether POSIX shell scripts can be run: always on POSIX, on Windows only when
-- an `sh` (Git Bash / MSYS2) is on PATH.
function M.hasPosixShell()
  if not M.isWindows then return true end
  local found = os.execute("where sh >nul 2>nul")
  return found == true or found == 0
end

-- Runs a POSIX shell command line; returns combined output and exit code. On
-- Windows the line is written to a temp script run by `sh` (cmd cannot run it).
function M.runPosix(command)
  if not M.isWindows then return M.run(command) end
  local script = M.tempPath(".sh")
  local file = io.open(script, "wb")
  file:write("exec 2>&1\n", command, "\n")
  file:close()
  local proc = io.popen('sh "' .. script .. '"')
  local output = proc:read("a")
  local _, _, code = proc:close()
  os.remove(script)
  return output, code
end

function M.eq(label, actual, expected)
  M.check(label, deepEqual(actual, expected),
    "expected " .. dump(expected) .. " got " .. dump(actual))
end

function M.contains(label, haystack, needle)
  M.check(label, type(haystack) == "string" and haystack:find(needle, 1, true) ~= nil,
    "expected to contain " .. tostring(needle) .. " in " .. tostring(haystack))
end

function M.hasFinding(label, findings, code)
  for _, f in ipairs(findings) do
    if f.code == code then M.check(label, true) return f end
  end
  M.check(label, false, "no finding with code " .. code .. " in " .. dump(findings))
end

function M.hasNoFinding(label, findings, code)
  for _, f in ipairs(findings) do
    if f.code == code then
      M.check(label, false, "unexpected finding " .. code .. ": " .. tostring(f.message))
      return
    end
  end
  M.check(label, true)
end

return M
