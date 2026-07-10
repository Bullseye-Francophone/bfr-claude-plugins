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

local ok, kind, code = os.execute(
  "./plugins/dcs-mission-tools/tools/logreduce.sh " .. FIX .. "/clean.log --threshold zzz 2>/dev/null"
)
t.eq("cli: invalid --threshold exits with code 3", code, 3)

local anonymize = require("anonymize")

t.eq("anonymize: windows user dir replaced",
  anonymize.scrub([[C:\Users\Jeux1\Saved Games\SRV4\x.lua]]),
  [[C:\Users\PLAYER\Saved Games\INSTANCE\x.lua]])

t.contains("anonymize: ip replaced",
  anonymize.scrub("client 192.168.1.42 connected"), "0.0.0.0")

t.eq("anonymize: ucid-like hex masked",
  anonymize.scrub("ucid abcdef0123456789abcdef0123456789"),
  "ucid " .. string.rep("0", 32))
