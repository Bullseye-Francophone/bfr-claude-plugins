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

write("wb", "caf\233\n")
local latin1Follower = follow.new(path)
t.eq("follow: iso-8859 line becomes utf-8", latin1Follower:poll(), { "caf\195\169" })

write("wb", "\239\187\191alpha\n")
local utf8BomFollower = follow.new(path)
t.eq("follow: utf-8 bom is stripped", utf8BomFollower:poll(), { "alpha" })

write("wb", "\255\254a\0\n\0b\0")
local utf16Follower = follow.new(path)
t.eq("follow: utf-16le lines are decoded", utf16Follower:poll(), { "a" })
write("ab", "\n")
t.eq("follow: utf-16le odd byte is withheld", utf16Follower:poll(), {})
write("ab", "\0")
t.eq("follow: utf-16le line completes across polls", utf16Follower:poll(), { "b" })

write("wb", "\254\255\0c\0\n")
local bigEndianFollower = follow.new(path)
t.eq("follow: utf-16be lines are decoded", bigEndianFollower:poll(), { "c" })

write("wb", "\255\254x\0\n\0y\0\n\0")
local rotatedFollower = follow.new(path)
t.eq("follow: utf-16 file read before rotation", rotatedFollower:poll(), { "x", "y" })
write("wb", "z\n")
t.eq("follow: rotation to plain text re-detects the encoding", rotatedFollower:poll(), { "z" })

os.remove(path)
