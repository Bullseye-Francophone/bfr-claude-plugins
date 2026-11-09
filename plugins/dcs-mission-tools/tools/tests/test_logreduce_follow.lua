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

local pipeline = require("logreduce.pipeline")

local FOLLOW_ERROR = '2026-06-30 21:04:58.720 ERROR   Lua::Config (Main): Call error [string "a.lua"]:10: boom\n'
local FOLLOW_FRAME = '\t[string "a.lua"]:20: in function \'run\'\n'
local FOLLOW_OTHER_ERROR = "2026-06-30 21:05:00.000 ERROR   APP (Main): another failure\n"
local sessionPath = os.tmpname()

local function writeSession(mode, data)
  local handle = assert(io.open(sessionPath, mode)); handle:write(data); handle:close()
end

local function newRecordingSession()
  local recording = { events = {}, notices = {} }
  recording.session = pipeline.newFollowSession(sessionPath, {},
    function(event) recording.events[#recording.events + 1] = event end,
    function(notice) recording.notices[#recording.notices + 1] = notice end)
  return recording
end

writeSession("wb", FOLLOW_ERROR .. FOLLOW_FRAME .. FOLLOW_OTHER_ERROR)
local stackRecording = newRecordingSession()
stackRecording.session.tick()
t.eq("follow session: event is emitted once a non-frame line arrives", #stackRecording.events, 1)
t.eq("follow session: emitted event carries its stack", #stackRecording.events[1].stack, 1)
stackRecording.session.tick()
t.eq("follow session: last event is emitted on the next idle poll", #stackRecording.events, 2)

writeSession("wb", FOLLOW_ERROR)
local splitRecording = newRecordingSession()
splitRecording.session.tick()
t.eq("follow session: event waits for frames of the next poll", #splitRecording.events, 0)
writeSession("ab", FOLLOW_FRAME)
splitRecording.session.tick()
splitRecording.session.tick()
t.eq("follow session: frames across polls reach the event", #splitRecording.events[1].stack, 1)

writeSession("wb", FOLLOW_ERROR .. FOLLOW_OTHER_ERROR)
local rotationRecording = newRecordingSession()
rotationRecording.session.tick()
rotationRecording.session.tick()
t.eq("follow session: two events before rotation", #rotationRecording.events, 2)
writeSession("wb", FOLLOW_ERROR)
rotationRecording.session.tick()
rotationRecording.session.tick()
t.eq("follow session: known error is emitted again after rotation", #rotationRecording.events, 3)

writeSession("wb", FOLLOW_ERROR)
local finishRecording = newRecordingSession()
finishRecording.session.tick()
finishRecording.session.finish()
t.eq("follow session: finish emits the pending event", #finishRecording.events, 1)

writeSession("wb", string.rep("\0", 32))
local corruptRecording = newRecordingSession()
local corruptOk, corruptFailure = corruptRecording.session.tick()
t.eq("follow session: all-null file stops the session", corruptOk, nil)
t.contains("follow session: all-null failure explains why", corruptFailure, "all-null")

writeSession("wb", "")
local emptyRecording = newRecordingSession()
t.eq("follow session: empty file keeps waiting", emptyRecording.session.tick(), true)

writeSession("wb", "\1\2\3\n\4\5\6\n")
local binaryRecording = newRecordingSession()
local binaryOk, binaryFailure = binaryRecording.session.tick()
t.eq("follow session: binary file stops the session", binaryOk, nil)
t.contains("follow session: binary failure explains why", binaryFailure, "no DCS log line")

writeSession("wb", FOLLOW_ERROR)
local recreatedRecording = newRecordingSession()
recreatedRecording.session.tick()
recreatedRecording.session.tick()
os.remove(sessionPath)
recreatedRecording.session.tick()
writeSession("wb", FOLLOW_ERROR .. FOLLOW_OTHER_ERROR)
recreatedRecording.session.tick()
recreatedRecording.session.tick()
t.eq("follow session: log recreated after removal is read from its start", #recreatedRecording.events, 3)

local OLDER_LOG_HEADER = "=== Log opened UTC 2026-01-01 08:00:00\n"
local NEWER_LOG_HEADER = "=== Log opened UTC 2026-01-02 09:00:00\n"
writeSession("wb", OLDER_LOG_HEADER .. FOLLOW_ERROR)
local replacedRecording = newRecordingSession()
replacedRecording.session.tick()
replacedRecording.session.tick()
writeSession("wb", NEWER_LOG_HEADER .. FOLLOW_ERROR .. FOLLOW_OTHER_ERROR)
replacedRecording.session.tick()
replacedRecording.session.tick()
t.eq("follow session: log replaced by a longer one is read from its start", #replacedRecording.events, 3)

os.remove(sessionPath)
local missingRecording = newRecordingSession()
t.eq("follow session: missing file keeps waiting", missingRecording.session.tick(), true)
missingRecording.session.tick()
t.eq("follow session: missing file is announced once", #missingRecording.notices, 1)
t.contains("follow session: notice names the file", missingRecording.notices[1], sessionPath)
