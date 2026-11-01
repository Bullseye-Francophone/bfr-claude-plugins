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

-- Windows listings are produced by `cmd /u` (UTF-16LE output) into a temp file
-- read in binary, then converted to UTF-8. A plain `io.popen` pipe is text-mode:
-- names would come back in the console OEM code page (accents mangled, while the
-- mission data they are compared to is UTF-8) and the read stops at the first
-- 0x1A byte, which UTF-16 produces for common letters such as Cyrillic 'К'.
local function utf16leToUtf8(data)
  local chars, i = {}, 1
  while i + 1 <= #data do
    local unit = data:byte(i) + data:byte(i + 1) * 256
    i = i + 2
    if unit >= 0xD800 and unit <= 0xDBFF and i + 1 <= #data then
      local low = data:byte(i) + data:byte(i + 1) * 256
      if low >= 0xDC00 and low <= 0xDFFF then
        unit = 0x10000 + (unit - 0xD800) * 0x400 + (low - 0xDC00)
        i = i + 2
      end
    end
    chars[#chars + 1] = utf8.char(unit)
  end
  return table.concat(chars)
end

local listingCounter = 0
local function windowsListingTempPath()
  listingCounter = listingCounter + 1
  local tempDir = os.getenv("TEMP") or os.getenv("TMP") or "."
  return string.format("%s\\mizlint-listing-%d-%d-%d.txt",
    tempDir, os.time(), math.random(1, 1000000000), listingCounter)
end

-- Runs `dir /b <flags>` from inside `dir` and returns the entries relative to it,
-- '/'-separated ({} when `dir` is not a directory). The first output line is the
-- working directory as cmd spells it, which is also the prefix `dir /s` puts on
-- every entry. pushd (not cd /d) so UNC paths keep working.
local function windowsRelativeEntries(dir, flags)
  local outFile = windowsListingTempPath()
  local windowsDir = dir:gsub("/", "\\"):gsub('"', "")
  os.execute('cmd /u /c "pushd "' .. windowsDir .. '" 2>nul && ((cd & dir /b ' .. flags ..
    ') >"' .. outFile .. '" 2>nul & popd)"')
  local handle = io.open(outFile, "rb")
  if not handle then return {} end
  local text = utf16leToUtf8(handle:read("a") or "")
  handle:close()
  os.remove(outFile)
  local entries, prefix = {}, nil
  for line in text:gmatch("[^\r\n]+") do
    if not prefix then
      prefix = line:gsub("\\+$", "") .. "\\"
    else
      if line:sub(1, #prefix) == prefix then line = line:sub(#prefix + 1) end
      entries[#entries + 1] = (line:gsub("\\", "/"))
    end
  end
  return entries
end

local function windowsListing(dir, flags)
  local base = dir:gsub("[/\\]+$", "")
  local paths = {}
  for i, entry in ipairs(windowsRelativeEntries(dir, flags)) do
    paths[i] = base .. "/" .. entry
  end
  return paths
end

function M.listFiles(dir)
  if M.isWindows then
    return windowsListing(dir, "/s /a:-d")
  end
  return popenLines('find ' .. quoted(dir) .. ' -type f 2>/dev/null')
end

-- Immediate subdirectories only, matching `find -mindepth 1 -maxdepth 1`.
function M.listDirs(dir)
  if M.isWindows then
    return windowsListing(dir, "/a:d")
  end
  return popenLines('find ' .. quoted(dir) .. ' -mindepth 1 -maxdepth 1 -type d 2>/dev/null')
end

return M
