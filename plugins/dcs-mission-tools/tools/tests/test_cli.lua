local t = require("helpers")

local LUA = "plugins/dcs-mission-tools/tools/bin/lua-macos-arm64"
local MAIN = "plugins/dcs-mission-tools/tools/src/main.lua"
local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures"

local function runCli(args)
  local proc = io.popen(LUA .. " " .. MAIN .. " " .. args .. " 2>&1; echo EXIT:$?")
  local output = proc:read("*a")
  proc:close()
  local code = tonumber(output:match("EXIT:(%d+)"))
  return output, code
end

local output, code = runCli("all " .. FIX .. "/clean")
t.eq("cli: clean project exits 0", code, 0)
t.contains("cli: clean summary", output, "0 error")

local brokenOutput, brokenCode = runCli("all " .. FIX .. "/broken-resources")
t.eq("cli: errors exit 2", brokenCode, 2)
t.contains("cli: finding code shown", brokenOutput, "RES-MISSING-FILE")

local _, flagsCode = runCli("flags " .. FIX .. "/broken-flags")
t.eq("cli: warnings-only exits 1", flagsCode, 1)

local jsonOutput, jsonCode = runCli("all " .. FIX .. "/broken-resources --json")
t.eq("cli: json exits 2 too", jsonCode, 2)
t.contains("cli: json structure", jsonOutput, '"code":"RES-MISSING-FILE"')

local multiOutput = runCli("all " .. FIX)
t.contains("cli: multi-project discovery finds clean", multiOutput, "clean")
t.contains("cli: multi-project discovery finds broken", multiOutput, "broken-resources")

local badOutput, badCode = runCli("all /nonexistent/path")
t.eq("cli: bad path exits 3", badCode, 3)

local _, unknownCode = runCli("nosuchcheck " .. FIX .. "/clean")
t.eq("cli: unknown check exits 3", unknownCode, 3)

for fixture, ownCheck in pairs({ ["broken-triggers"] = "triggers", ["broken-loading"] = "loading",
                                  ["broken-flags"] = "flags", ["broken-names"] = "names" }) do
  for _, otherCheck in ipairs({ "resources", "triggers", "loading", "flags", "names" }) do
    if otherCheck ~= ownCheck then
      local _, isolationCode = runCli(otherCheck .. " " .. FIX .. "/" .. fixture)
      t.eq("cli: " .. fixture .. " is clean for " .. otherCheck, isolationCode, 0)
    end
  end
end
