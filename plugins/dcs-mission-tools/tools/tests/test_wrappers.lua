local t = require("helpers")

local TOOLS_DIR = "plugins/dcs-mission-tools/tools"
local FIXTURE = TOOLS_DIR .. "/tests/fixtures/clean"

local sandbox = os.tmpname()
os.remove(sandbox)
sandbox = sandbox .. "_wrappers"

local function shell(command)
  local process = io.popen(command .. " 2>&1; echo EXIT:$?")
  local output = process:read("*a")
  process:close()
  return output, tonumber(output:match("EXIT:(%d+)"))
end

local function writeExecutable(path, body)
  local file = io.open(path, "w")
  file:write(body)
  file:close()
  os.execute('chmod +x "' .. path .. '"')
end

local function readFile(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return content
end

os.execute('mkdir -p "' .. sandbox .. '/bin/windows-x64" "' .. sandbox .. '/bin/macos-arm64" "' ..
  sandbox .. '/bin/linux-x64" "' .. sandbox .. '/stubPath"')
os.execute('cp "' .. TOOLS_DIR .. '/miz2json.sh" "' .. TOOLS_DIR .. '/mizlint.sh" "' .. sandbox .. '/"')

writeExecutable(sandbox .. "/stubPath/uname", [[#!/bin/sh
case "$1" in
  -s) echo "$STUB_UNAME_SYSTEM" ;;
  -m) echo "$STUB_UNAME_MACHINE" ;;
esac
]])

local function exportStub(platform)
  return "#!/bin/sh\nprintf '{\"exportedBy\":\"" .. platform .. "\"}' > \"$3\"\n"
end

local function interpreterStub(platform)
  return "#!/bin/sh\necho \"interpretedBy " .. platform .. "\"\n"
end

writeExecutable(sandbox .. "/bin/windows-x64/veaf-tools.exe", exportStub("windows-x64"))
writeExecutable(sandbox .. "/bin/macos-arm64/veaf-tools", exportStub("macos-arm64"))
writeExecutable(sandbox .. "/bin/linux-x64/veaf-tools", exportStub("linux-x64"))
writeExecutable(sandbox .. "/bin/windows-x64/lua54.exe", interpreterStub("windows-x64"))
writeExecutable(sandbox .. "/bin/lua-macos-arm64", interpreterStub("macos-arm64"))
writeExecutable(sandbox .. "/bin/lua-linux-x64", interpreterStub("linux-x64"))

writeExecutable(sandbox .. "/failingExport", "#!/bin/sh\nexit 1\n")
writeExecutable(sandbox .. "/silentExport", "#!/bin/sh\nexit 0\n")

local function withPlatform(system, machine, command)
  return 'env PATH="' .. sandbox .. '/stubPath:/usr/bin:/bin" VEAF_TOOLS= ' ..
    'STUB_UNAME_SYSTEM="' .. system .. '" STUB_UNAME_MACHINE="' .. machine .. '" ' .. command
end

local function exportedPlatform(system, machine)
  local output = sandbox .. "/exported-" .. system:gsub("[^%w]", "_") .. ".json"
  os.remove(output)
  local _, code = shell(withPlatform(system, machine,
    'sh "' .. sandbox .. '/miz2json.sh" "' .. FIXTURE .. '" "' .. output .. '"'))
  return readFile(output), code
end

local gitBashExport, gitBashExportCode = exportedPlatform("MINGW64_NT-10.0-26200", "x86_64")
t.eq("wrappers: miz2json.sh succeeds under Git-Bash", gitBashExportCode, 0)
t.eq("wrappers: miz2json.sh picks the bundled Windows binary under Git-Bash",
  gitBashExport, '{"exportedBy":"windows-x64"}')

local macExport, macExportCode = exportedPlatform("Darwin", "arm64")
t.eq("wrappers: miz2json.sh still succeeds on macOS arm64", macExportCode, 0)
t.eq("wrappers: miz2json.sh still picks the macOS binary", macExport, '{"exportedBy":"macos-arm64"}')

local function lintedPlatform(system, machine)
  return shell(withPlatform(system, machine, 'sh "' .. sandbox .. '/mizlint.sh" all whatever'))
end

local gitBashLint, gitBashLintCode = lintedPlatform("MINGW64_NT-10.0-26200", "x86_64")
t.eq("wrappers: mizlint.sh succeeds under Git-Bash", gitBashLintCode, 0)
t.contains("wrappers: mizlint.sh picks the bundled Windows interpreter under Git-Bash",
  gitBashLint, "interpretedBy windows-x64")

local macLint, macLintCode = lintedPlatform("Darwin", "arm64")
t.eq("wrappers: mizlint.sh still succeeds on macOS arm64", macLintCode, 0)
t.contains("wrappers: mizlint.sh still picks the macOS interpreter", macLint, "interpretedBy macos-arm64")

local function exportWith(tool, arguments)
  return shell('env VEAF_TOOLS="' .. sandbox .. '/' .. tool .. '" ' ..
    'sh "' .. sandbox .. '/miz2json.sh" ' .. arguments)
end

local _, failingCode = exportWith("failingExport", '"' .. FIXTURE .. '" "' .. sandbox .. '/failed.json"')
t.eq("wrappers: miz2json.sh reports a failing export", failingCode, 1)

local silentOutput = sandbox .. "/silent.json"
os.remove(silentOutput)
local _, silentCode = exportWith("silentExport", '"' .. FIXTURE .. '" "' .. silentOutput .. '"')
t.eq("wrappers: miz2json.sh refuses to claim success without an output file", silentCode, 1)

local silentStdout, silentStdoutCode = exportWith("silentExport", '"' .. FIXTURE .. '"')
t.eq("wrappers: miz2json.sh refuses to claim success on an empty stdout export", silentStdoutCode, 1)
t.check("wrappers: a failed stdout export emits no JSON", not silentStdout:find("{", 1, true))
t.contains("wrappers: miz2json.sh says when the export wrote no JSON", silentStdout, "exit 0 but no JSON written")

-- A failing veaf-tools must have its exit code and its own output relayed on
-- stderr (PR #8: a PyInstaller bootloader error was swallowed by >/dev/null).
writeExecutable(sandbox .. "/noisyFailingExport", [[#!/bin/sh
echo "veaf-tools banner"
echo "[PYI-42:ERROR] Could not create temporary directory!" >&2
exit 127
]])
writeExecutable(sandbox .. "/noisyExport", [[#!/bin/sh
echo "veaf-tools banner"
echo "progress noise" >&2
printf '{"exported":true}' > "$3"
]])
os.execute('mkdir -p "' .. sandbox .. '/tmpdir"')

-- stderrOf: run miz2json.sh with stdout sent to a file, return (stderr, code, stdout).
-- The brace group keeps stdout in the file while shell()'s 2>&1 brings stderr back.
local function stderrOf(tool, arguments)
  local stdoutFile = sandbox .. "/captured-stdout"
  os.remove(stdoutFile)
  local stderr, code = shell('{ env TMPDIR="' .. sandbox .. '/tmpdir" VEAF_TOOLS="' .. sandbox .. '/' .. tool .. '" ' ..
    'sh "' .. sandbox .. '/miz2json.sh" ' .. arguments .. ' >"' .. stdoutFile .. '"; }')
  return (stderr:gsub("EXIT:%d+%s*$", "")), code, readFile(stdoutFile) or ""
end

local fileModeErr, fileModeCode = stderrOf("noisyFailingExport", '"' .. FIXTURE .. '" "' .. sandbox .. '/noisy.json"')
t.eq("wrappers: miz2json.sh file mode still exits 1 when veaf-tools fails", fileModeCode, 1)
t.contains("wrappers: miz2json.sh file mode relays veaf-tools' exit code", fileModeErr, "(exit 127)")
t.contains("wrappers: miz2json.sh file mode relays veaf-tools' stderr", fileModeErr,
  "[PYI-42:ERROR] Could not create temporary directory!")
t.contains("wrappers: miz2json.sh file mode relays veaf-tools' stdout", fileModeErr, "veaf-tools banner")

local stdoutModeErr, stdoutModeCode, stdoutModeOut = stderrOf("noisyFailingExport", '"' .. FIXTURE .. '"')
t.eq("wrappers: miz2json.sh stdout mode still exits 1 when veaf-tools fails", stdoutModeCode, 1)
t.contains("wrappers: miz2json.sh stdout mode relays veaf-tools' exit code", stdoutModeErr, "(exit 127)")
t.contains("wrappers: miz2json.sh stdout mode relays veaf-tools' stderr", stdoutModeErr,
  "[PYI-42:ERROR] Could not create temporary directory!")
t.eq("wrappers: miz2json.sh stdout mode keeps the failure off stdout", stdoutModeOut, "")
local quietErr, quietCode, quietOut = stderrOf("noisyExport", '"' .. FIXTURE .. '"')
t.eq("wrappers: miz2json.sh stdout mode succeeds despite veaf-tools noise", quietCode, 0)
t.eq("wrappers: miz2json.sh stdout mode emits only the JSON", quietOut, '{"exported":true}')
t.eq("wrappers: miz2json.sh stays silent on stderr when the export succeeds", quietErr, "")

local leftovers = shell('ls -A "' .. sandbox .. '/tmpdir"')
t.eq("wrappers: miz2json.sh leaves no temp file behind", (leftovers:gsub("EXIT:%d+%s*$", "")), "")

os.execute('rm -rf "' .. sandbox .. '"')
