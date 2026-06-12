local M = {}

function M.collector(checkName)
  local findings = {}
  local function add(severity, code, message, file, detail)
    findings[#findings + 1] = {
      check = checkName, severity = severity, code = code,
      message = message, file = file, detail = detail,
    }
  end
  return findings, add
end

return M
