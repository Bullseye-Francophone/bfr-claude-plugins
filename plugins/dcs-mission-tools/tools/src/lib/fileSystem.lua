local M = {}

M.isWindows = package.config:sub(1, 1) == "\\"

local function quoted(path)
  if M.isWindows then
    return '"' .. path:gsub('"', '') .. '"'
  end
  return '"' .. path:gsub('"', '\\"') .. '"'
end

function M.exists(path)
  local handle = io.open(path, "rb")
  if handle then handle:close() return true end
  return false
end

function M.isDir(path)
  if M.isWindows then
    local proc = io.popen('if exist ' .. quoted(path .. '\\*') .. ' (echo yes) else (echo no)')
    local out = proc:read("*l")
    proc:close()
    return out == "yes"
  end
  local proc = io.popen('[ -d ' .. quoted(path) .. ' ] && echo yes || echo no')
  local out = proc:read("*l")
  proc:close()
  return out == "yes"
end

function M.readAll(path)
  local handle, err = io.open(path, "rb")
  if not handle then return nil, err end
  local content = handle:read("*a")
  handle:close()
  if content == nil then return nil, path .. ": not a readable file" end
  return content
end

function M.basename(path)
  return path:match("([^/\\]+)$") or path
end

function M.join(...)
  return table.concat({ ... }, "/")
end

local function popenLines(command)
  local lines = {}
  local proc = io.popen(command)
  for line in proc:lines() do
    if line ~= "" then lines[#lines + 1] = line end
  end
  proc:close()
  return lines
end

function M.listFiles(dir)
  if M.isWindows then
    local lines = popenLines('dir /b /s /a:-d ' .. quoted(dir) .. ' 2>nul')
    for i, line in ipairs(lines) do lines[i] = line:gsub("\\", "/") end
    return lines
  end
  return popenLines('find ' .. quoted(dir) .. ' -type f 2>/dev/null')
end

function M.listDirs(dir)
  if M.isWindows then
    local lines = popenLines('dir /b /s /a:d ' .. quoted(dir) .. ' 2>nul')
    for i, line in ipairs(lines) do lines[i] = line:gsub("\\", "/") end
    return lines
  end
  return popenLines('find ' .. quoted(dir) .. ' -mindepth 1 -maxdepth 1 -type d 2>/dev/null')
end

return M
