local decode = require("logreduce.decode")

local M = {}
local Follower = {}
Follower.__index = Follower

local SHORTEST_DETECTABLE_PREFIX = 3

local function resetDecoding(follower)
  follower.position = 0
  follower.lineBuffer = ""
  follower.undecodedBytes = ""
  follower.encoding = nil
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
  if not handle then return {} end
  local size = handle:seek("end")
  if size < self.position then resetDecoding(self) end
  handle:seek("set", self.position)
  local chunk = handle:read("*a") or ""
  self.position = handle:seek("cur")
  handle:close()

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
  return lines
end

return M
