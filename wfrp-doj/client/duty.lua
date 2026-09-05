local npcEntity   = nil
local dutyPrompt  = nil
local promptGroup = GetHashKey('DOJ_DUTY_GRP')

CreateThread(function()
    if not Config.Courthouse.blip.enabled then return end
    local b = Config.Courthouse.blip
    local blip = Citizen.InvokeNative(0x554D9D53F696D002,
        GetHashKey(b.sprite), b.coords.x, b.coords.y, b.coords.z)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, b.label)
end)

CreateThread(function()
    if not Config.Courthouse.npc.enabled then return end
    local c     = Config.Courthouse.npc
    local model = GetHashKey(c.model)
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 200 do
        Wait(20); tries = tries + 1
    end
    if not HasModelLoaded(model) then return end

    npcEntity = CreatePed(model, c.coords.x, c.coords.y, c.coords.z - 1.0, c.coords.w, false, false, false, false)
    SetEntityInvincible(npcEntity, true)
    FreezeEntityPosition(npcEntity, true)
    SetBlockingOfNonTemporaryEvents(npcEntity, true)
    Citizen.InvokeNative(0x283978A15512B2FE, npcEntity, true)
    SetModelAsNoLongerNeeded(model)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and npcEntity and DoesEntityExist(npcEntity) then
        DeleteEntity(npcEntity)
    end
end)

CreateThread(function()
    dutyPrompt = PromptRegisterBegin()
    PromptSetControlAction(dutyPrompt, 0xC7B5340A)
    local labelStr = CreateVarString(10, 'LITERAL_STRING', Config.Courthouse.npc.promptLabel)
    PromptSetText(dutyPrompt, labelStr)
    PromptSetEnabled(dutyPrompt, true)
    PromptSetVisible(dutyPrompt, true)
    PromptSetStandardMode(dutyPrompt, true)
    PromptSetGroup(dutyPrompt, promptGroup)
    PromptRegisterEnd(dutyPrompt)
end)

CreateThread(function()
    local npcCfg = Config.Courthouse.npc
    local checkPos = vector3(npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z)
    local dist2    = (npcCfg.interactDistance or 2.5) ^ 2
    local groupLabel = CreateVarString(10, 'LITERAL_STRING', 'Courthouse Clerk')

    while true do
        local sleep = 750
        local ped   = PlayerPedId()
        local pos   = GetEntityCoords(ped)
        local dx, dy, dz = pos.x - checkPos.x, pos.y - checkPos.y, pos.z - checkPos.z
        if (dx*dx + dy*dy + dz*dz) <= dist2 then
            sleep = 0
            PromptSetActiveGroupThisFrame(promptGroup, groupLabel)
            if PromptHasStandardModeCompleted(dutyPrompt) then
                RequestOpenDutyBook()
                Wait(750)
            end
        end
        Wait(sleep)
    end
end)
