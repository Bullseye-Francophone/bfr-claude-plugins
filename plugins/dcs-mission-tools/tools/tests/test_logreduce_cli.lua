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
