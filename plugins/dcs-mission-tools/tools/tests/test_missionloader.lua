local t = require("helpers")
local loader = require("lib.missionLoader")

local tmp = os.tmpname()
local f = io.open(tmp, "w")
f:write('myTable = {\n    ["a"] = "hello",\n    [1] = 2,\n}\n')
f:close()

local tbl, err = loader.loadLuaTable(tmp, "myTable")
t.eq("loader: loads table", tbl and tbl.a, "hello")
t.eq("loader: numeric keys", tbl and tbl[1], 2)

local missing, err2 = loader.loadLuaTable(tmp .. "_nope", "myTable")
t.eq("loader: missing file returns nil", missing, nil)
t.contains("loader: missing file error message", err2, "cannot open")

f = io.open(tmp, "w")
f:write('otherName = {}')
f:close()
local wrong, err3 = loader.loadLuaTable(tmp, "myTable")
t.eq("loader: wrong global returns nil", wrong, nil)
t.contains("loader: wrong global names the expectation", err3, "myTable")

f = io.open(tmp, "w")
f:write('myTable = { os.exit(99) }')
f:close()
local sandboxed, err4 = loader.loadLuaTable(tmp, "myTable")
t.eq("loader: sandbox blocks os access", sandboxed, nil)
t.contains("loader: sandbox error mentions file", err4, "myTable")

os.remove(tmp)

local first = loader.tempPath("mizlint-test", ".json")
local second = loader.tempPath("mizlint-test", ".json")
t.check("loader: tempPath differs within a process", first ~= second)
t.contains("loader: tempPath keeps the prefix", first, "/mizlint-test-")
t.check("loader: tempPath keeps the suffix", first:sub(-5) == ".json")

-- Two processes started in the same second used to get the same name (issue #41).
local srcDir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./") .. "../src/"
local probeFile = loader.tempPath("mizlint-probe", ".lua")
f = io.open(probeFile, "w")
f:write("package.path = ", string.format("%q", srcDir .. "?.lua;"), " .. package.path\n",
  'print(require("lib.missionLoader").tempPath("p"))\n')
f:close()
local probe = '"' .. arg[-1] .. '" "' .. probeFile .. '"'
if package.config:sub(1, 1) == "\\" then probe = '"' .. probe .. '"' end -- cmd /c strips one pair
local fromOne = io.popen(probe):read("*l")
local fromTwo = io.popen(probe):read("*l")
os.remove(probeFile)
t.check("loader: tempPath differs across processes", fromOne ~= nil and fromOne ~= fromTwo, tostring(fromOne))
