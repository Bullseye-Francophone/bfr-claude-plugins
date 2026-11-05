local fs = require("lib.fileSystem")
local decode = require("logreduce.decode")
local parser = require("logreduce.parser")
local reducer = require("logreduce.reducer")

local M = {}

function M.runOnce(path, opts)
  local bytes, readErr = fs.readAll(path)
  if not bytes then return nil, readErr end
  local text, decodeErr = decode.toText(bytes)
  if not text then return nil, path .. ": " .. decodeErr end
  local r = reducer.new(opts)
  for _, line in ipairs(decode.splitLines(text)) do
    r:add(parser.parseLine(line))
  end
  return r:digest()
end

return M
