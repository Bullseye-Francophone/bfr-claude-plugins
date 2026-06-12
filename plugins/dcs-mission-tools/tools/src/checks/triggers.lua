local findingsLib = require("lib.findings")

local M = { name = "triggers", layer = "vanilla" }

local function count(tbl)
  local n = 0
  for _ in pairs(tbl or {}) do n = n + 1 end
  return n
end

local function compileFragment(action)
  if action.predicate == "a_do_script" and type(action.text) == "string" then
    local escaped = action.text:gsub("\\", "\\\\"):gsub('"', '\\"')
    return 'a_do_script("' .. escaped .. '");'
  end
  if action.predicate == "a_do_script_file" and type(action.file) == "string" then
    return 'a_do_script_file(getValueResourceByKey("' .. action.file .. '"));'
  end
  return nil
end

function M.run(project)
  local findings, add = findingsLib.collector(M.name)
  local mission = project.mission
  local trig = mission.trig or {}
  local trigrules = mission.trigrules or {}

  local ruleCount = count(trigrules)
  for _, section in ipairs({ "actions", "conditions", "flag" }) do
    local sectionCount = count(trig[section])
    if sectionCount ~= ruleCount then
      add("error", "TRG-CARDINALITY",
        "#trigrules is " .. ruleCount .. " but #trig." .. section .. " is " .. sectionCount ..
        " — the mission was edited outside the Mission Editor or injection was not re-saved",
        "src/mission/mission")
    end
  end

  local funcStartup = trig.funcStartup or {}
  local func = trig.func or {}
  for index = 1, ruleCount do
    local inStartup = funcStartup[index] ~= nil
    local inTick = func[index] ~= nil
    if inStartup and inTick then
      add("error", "TRG-STARTUP-COVERAGE",
        "trigger [" .. index .. "] appears in both trig.funcStartup and trig.func",
        "src/mission/mission")
    elseif not inStartup and not inTick then
      add("error", "TRG-STARTUP-COVERAGE",
        "trigger [" .. index .. "] appears in neither trig.funcStartup nor trig.func — it will never run",
        "src/mission/mission")
    end
    local rule = trigrules[index]
    if rule then
      local isStart = rule.predicate == "triggerStart"
      if isStart and inTick then
        add("error", "TRG-STARTUP-COVERAGE",
          "trigger [" .. index .. "] is a Mission Start trigger but compiled into trig.func (every tick)",
          "src/mission/mission")
      elseif not isStart and inStartup then
        add("error", "TRG-STARTUP-COVERAGE",
          "trigger [" .. index .. "] is not a Mission Start trigger but compiled into trig.funcStartup",
          "src/mission/mission")
      end
    end
  end

  for index = 1, ruleCount do
    local rule = trigrules[index]
    local compiled = trig.actions and trig.actions[index]
    if rule and type(compiled) == "string" then
      local cursor = 1
      for actionIndex, action in ipairs(rule.actions or {}) do
        local fragment = compileFragment(action)
        local needle = fragment or (tostring(action.predicate) .. "(")
        local foundAt = compiled:find(needle, cursor, true)
        if not foundAt then
          add("error", "TRG-RECOMPILE",
            "trig.actions[" .. index .. "] does not match trigrules[" .. index ..
            "].actions[" .. actionIndex .. "] (" .. tostring(action.predicate) ..
            ") — expected fragment not found in compiled trigger",
            "src/mission/mission",
            "expected: " .. needle)
        else
          cursor = foundAt + #needle
        end
      end
    end
  end

  return findings
end

return M
