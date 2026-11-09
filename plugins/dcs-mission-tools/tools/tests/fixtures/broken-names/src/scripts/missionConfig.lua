veafCombatZone.AddZone(
    VeafCombatZone:new()
        :setMissionEditorZoneName("combatZone_Missing")
        :setFriendlyName("Bravo training zone")
)

veafCombatZone.AddOperation(
    VeafCombatOperation:new()
        :setMissionEditorZoneName("operation_WithoutEditorZone")
        :setFriendlyName("Charlie operation")
)

veafCombatZone.AddOperation(
    VeafCombatOperation:new()
        :setFriendlyName("Operation declaring no editor zone")
)
veafCombatZone.AddZone(
    VeafCombatZone:new()
        :setMissionEditorZoneName("combatZone_MissingAfterBareOperation")
        :setFriendlyName("Delta training zone")
)

local function watchAlpha()
    if trigger.misc.getUserFlag("Zone-Alpha-Active") == 1 then
        trigger.action.outText("Alpha is active", 10)
    end
end

trigger.action.setUserFlag("Start-Zone-Alpha", true)
mist.scheduleFunction(watchAlpha, {}, timer.getTime() + 10, 30)
local protectors = mist.DBs.groupsByName["No-Such-Group"]
