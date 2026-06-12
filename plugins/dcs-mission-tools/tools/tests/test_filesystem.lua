local t = require("helpers")
local fs = require("lib.fileSystem")

local tmp = os.tmpname()
os.remove(tmp)
local dir = tmp .. "_fsdir"
os.execute('mkdir -p "' .. dir .. '/sub"')
local f = io.open(dir .. "/a.txt", "w") f:write("hello") f:close()
f = io.open(dir .. "/sub/b.lua", "w") f:write("x") f:close()

t.eq("fs: exists true", fs.exists(dir .. "/a.txt"), true)
t.eq("fs: exists false", fs.exists(dir .. "/nope.txt"), false)
t.eq("fs: isDir", fs.isDir(dir), true)
t.eq("fs: isDir on file", fs.isDir(dir .. "/a.txt"), false)
t.eq("fs: readAll", fs.readAll(dir .. "/a.txt"), "hello")
t.eq("fs: basename", fs.basename("/x/y/z.lua"), "z.lua")
t.eq("fs: join", fs.join("a", "b", "c"), "a/b/c")

local files = fs.listFiles(dir)
table.sort(files)
t.eq("fs: recursive listing", files, { dir .. "/a.txt", dir .. "/sub/b.lua" })

local names = fs.listDirs(dir)
t.eq("fs: subdirectories", names, { dir .. "/sub" })

local dirContent, dirErr = fs.readAll(dir)
t.eq("fs: readAll on directory returns nil", dirContent, nil)
t.check("fs: readAll on directory returns an error message", type(dirErr) == "string")

f = io.open(dir .. '/wei"rd.txt', "w") f:write("q") f:close()
local foundQuoted = false
for _, path in ipairs(fs.listFiles(dir)) do
  if path:find('wei"rd.txt', 1, true) then foundQuoted = true end
end
t.check("fs: listFiles handles quotes in names", foundQuoted)

os.execute('rm -rf "' .. dir .. '"')
