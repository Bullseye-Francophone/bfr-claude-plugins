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
