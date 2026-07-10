local M = {}
local Follower = {}
Follower.__index = Follower

function M.new(path)
  return setmetatable({ path = path, pos = 0, buffer = "" }, Follower)
end

function Follower:poll()
  local handle = io.open(self.path, "rb")
  if not handle then return {} end
  local size = handle:seek("end")
  if size < self.pos then
    self.pos = 0
    self.buffer = ""
  end
  handle:seek("set", self.pos)
  local chunk = handle:read("*a") or ""
  self.pos = handle:seek("cur")
  handle:close()

  self.buffer = self.buffer .. chunk
  local lines = {}
  while true do
    local nl = self.buffer:find("\n", 1, true)
    if not nl then break end
    local line = self.buffer:sub(1, nl - 1):gsub("\r$", "")
    if line ~= "" then lines[#lines + 1] = line end
    self.buffer = self.buffer:sub(nl + 1)
  end
  return lines
end

return M
