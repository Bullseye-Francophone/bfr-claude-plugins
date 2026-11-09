local decode = require("logreduce.decode")

local M = {}
local Follower = {}
Follower.__index = Follower

local SHORTEST_DETECTABLE_PREFIX = 3
local FILE_HEAD_LENGTH = 64

local function resetDecoding(follower)
  follower.position = 0
  follower.lineBuffer = ""
  follower.undecodedBytes = ""
  follower.encoding = nil
  follower.fileHead = ""
end

function M.new(path)
  local follower = setmetatable({ path = path }, Follower)
  resetDecoding(follower)
  return follower
end

function Follower:decodeAvailableBytes()
  if not self.encoding then
    if #self.undecodedBytes < SHORTEST_DETECTABLE_PREFIX then
      local encoding = decode.detectEncoding(self.undecodedBytes)
      if encoding ~= "utf16le" and encoding ~= "utf16be" and not self.undecodedBytes:find("\n", 1, true) then
        return ""
      end
    end
    local encoding, bomLength = decode.detectEncoding(self.undecodedBytes)
    self.encoding = encoding
    self.undecodedBytes = self.undecodedBytes:sub(bomLength + 1)
  end

  if self.encoding == "utf16le" or self.encoding == "utf16be" then
    local decodedText, remainingBytes = decode.decodeUtf16(self.undecodedBytes, self.encoding == "utf16le")
    self.undecodedBytes = remainingBytes
    return decodedText
  end

  local availableBytes = self.undecodedBytes
  self.undecodedBytes = ""
  return availableBytes
end

function Follower:poll()
  local handle = io.open(self.path, "rb")
  if not handle then
    local wasReadingFile = self.position > 0
    resetDecoding(self)
    return {}, { missing = true, rotated = wasReadingFile }
  end
  local status = {}
  local size = handle:seek("end")
  handle:seek("set", 0)
  local currentHead = handle:read(FILE_HEAD_LENGTH) or ""
  if size < self.position or currentHead:sub(1, #self.fileHead) ~= self.fileHead then
    resetDecoding(self)
    status.rotated = true
  end
  self.fileHead = currentHead
  handle:seek("set", self.position)
  local isAtFileStart = self.position == 0
  local chunk = handle:read("*a") or ""
  self.position = handle:seek("cur")
  handle:close()

  if isAtFileStart and chunk ~= "" and decode.isAllNull(chunk) then
    status.corrupt = decode.ALL_NULL_MESSAGE
    return {}, status
  end

  self.undecodedBytes = self.undecodedBytes .. chunk
  self.lineBuffer = self.lineBuffer .. self:decodeAvailableBytes()

  local lines = {}
  while true do
    local newlineIndex = self.lineBuffer:find("\n", 1, true)
    if not newlineIndex then break end
    local line = self.lineBuffer:sub(1, newlineIndex - 1):gsub("\r$", "")
    if line ~= "" then lines[#lines + 1] = decode.normalizeLine(line) end
    self.lineBuffer = self.lineBuffer:sub(newlineIndex + 1)
  end
  return lines, status
end

return M
