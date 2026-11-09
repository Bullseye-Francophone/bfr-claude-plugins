local t = require("helpers")
local json = require("lib.json")
local fs = require("lib.fileSystem")
local pipeline = require("logreduce.pipeline")

local FIX = "plugins/dcs-mission-tools/tools/tests/fixtures/logs"

local function goldenMatch(name)
  local digest = assert(pipeline.runOnce(FIX .. "/" .. name .. ".log"))
  local golden = json.decode(assert(fs.readAll(FIX .. "/" .. name .. ".golden.json")))
  t.eq("cli: " .. name .. " digest matches golden", digest, golden)
end

goldenMatch("clean")
goldenMatch("script-errors")
goldenMatch("client-ctd")

local digest, err = pipeline.runOnce(FIX .. "/corrupt-null.log")
t.eq("cli: corrupt-null digest is nil", digest, nil)
t.contains("cli: corrupt-null error explains", err, "all-null")

local LOGMAIN = t.luaCommand() .. " plugins/dcs-mission-tools/tools/src/logmain.lua "

local _, invalidThresholdCode = t.run(LOGMAIN .. FIX .. "/clean.log --threshold zzz")
t.eq("cli: invalid --threshold exits with code 3", invalidThresholdCode, 3)

local onceOutput, onceCode = t.run(LOGMAIN .. "--once " .. FIX .. "/clean.log")
local defaultOutput = t.run(LOGMAIN .. FIX .. "/clean.log")
t.eq("cli: --once exits 0", onceCode, 0)
t.eq("cli: --once prints the same digest as the default mode", onceOutput, defaultOutput)

local _, exclusiveModesCode = t.run(LOGMAIN .. "--once --follow " .. FIX .. "/clean.log")
t.eq("cli: --once with --follow exits with code 3", exclusiveModesCode, 3)

local anonymize = require("anonymize")

t.eq("anonymize: windows user dir replaced",
  anonymize.scrub([[C:\Users\Jeux1\Saved Games\SRV4\x.lua]]),
  [[C:\Users\PLAYER\Saved Games\INSTANCE\x.lua]])

t.contains("anonymize: ip replaced",
  anonymize.scrub("client 192.168.1.42 connected"), "0.0.0.0")

t.eq("anonymize: ucid-like hex masked",
  anonymize.scrub("ucid abcdef0123456789abcdef0123456789"),
  "ucid " .. string.rep("0", 32))

t.eq("anonymize: forward-slash user dir replaced",
  anonymize.scrub("C:/Users/RealName/Saved Games/SRV4/x.lua"),
  "C:/Users/PLAYER/Saved Games/INSTANCE/x.lua")

t.eq("anonymize: dcs version is preserved",
  anonymize.scrub("DCS/2.9.27.25340 (x86_64)"), "DCS/2.9.27.25340 (x86_64)")

t.eq("anonymize: low-numbered dcs version is preserved",
  anonymize.scrub("DCS/2.9.2.100"), "DCS/2.9.2.100")

t.eq("anonymize: labelled version is preserved",
  anonymize.scrub("version 1.2.3.4"), "version 1.2.3.4")

t.eq("anonymize: ip next to a version is still replaced",
  anonymize.scrub("DCS/2.9.27.25340 from 192.168.1.42:10308"),
  "DCS/2.9.27.25340 from 0.0.0.0:10308")

local onceThresholdOutput = t.run(LOGMAIN .. "--once --threshold critical " .. FIX .. "/script-errors.log")
local onceInfoOutput = t.run(LOGMAIN .. "--once --threshold info " .. FIX .. "/script-errors.log")
t.eq("cli: --threshold changes the digest", onceThresholdOutput == onceInfoOutput, false)
