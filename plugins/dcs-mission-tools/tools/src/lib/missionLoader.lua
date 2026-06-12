local M = {}

-- Mission files are plain data (`mission = {...}`); execute them in an empty
-- environment so a malformed or malicious file cannot touch the host.
function M.loadLuaTable(path, globalName)
  local handle, openErr = io.open(path, "rb")
  if not handle then
    return nil, "cannot open " .. path .. ": " .. tostring(openErr)
  end
  local source = handle:read("*a")
  handle:close()

  local env = {}
  local chunk, parseErr = load(source, "@" .. path, "t", env)
  if not chunk then
    return nil, "lua parse error in " .. path .. ": " .. tostring(parseErr)
  end

  local ok, runErr = pcall(chunk)
  if not ok then
    return nil, "error evaluating " .. globalName .. " in " .. path .. ": " .. tostring(runErr)
  end

  local result = env[globalName]
  if type(result) ~= "table" then
    return nil, path .. " did not define global table '" .. globalName .. "'"
  end
  return result
end

return M
