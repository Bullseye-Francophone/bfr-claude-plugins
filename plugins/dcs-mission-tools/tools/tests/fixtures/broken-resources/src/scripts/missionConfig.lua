veafCombatZone.AddZone(
    VeafCombatZone:new()
        :setMissionEditorZoneName("combatZone_Bravo")
        :setFriendlyName("Bravo training zone")
)

local function watchAlpha()
    if trigger.misc.getUserFlag("Zone-Alpha-Active") == 1 then
        trigger.action.outText("Alpha is active", 10)
    end
end

trigger.action.setUserFlag("Start-Zone-Alpha", true)
mist.scheduleFunction(watchAlpha, {}, timer.getTime() + 10, 30)
local protectors = mist.DBs.groupsByName["Ground-Alpha"]
