local t = require("helpers")
local follow = require("logreduce.follow")

local path = os.tmpname()
local function write(mode, data)
  local h = assert(io.open(path, mode)); h:write(data); h:close()
end

write("wb", "alpha\nbeta\n")
local f = follow.new(path)
t.eq("follow: reads initial complete lines", f:poll(), { "alpha", "beta" })
t.eq("follow: nothing new yields empty", f:poll(), {})

write("ab", "gam")
t.eq("follow: partial line withheld", f:poll(), {})
write("ab", "ma\n")
t.eq("follow: partial line completes", f:poll(), { "gamma" })

write("wb", "small\n")
t.eq("follow: truncation resets and re-reads", f:poll(), { "small" })

os.remove(path)
