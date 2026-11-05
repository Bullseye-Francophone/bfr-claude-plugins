local M = {}

function M.scrub(text)
  text = text:gsub([[[Cc]:\Users\[^\]+]], [[C:\Users\PLAYER]])
  text = text:gsub([[Saved Games\[^\]+]], [[Saved Games\INSTANCE]])
  text = text:gsub("%d+%.%d+%.%d+%.%d+", "0.0.0.0")
  text = text:gsub("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x", string.rep("0", 32))
  return text
end

if arg and arg[0] and arg[0]:find("anonymize%.lua$") then
  io.write(M.scrub(io.read("*a")))
end

return M
