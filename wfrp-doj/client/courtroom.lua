function GetCurrentCourtroom()
    local pos = GetEntityCoords(PlayerPedId())
    for _, c in ipairs(Config.Courtrooms) do
        if #(pos - c.coords) <= c.radius then
            return c
        end
    end
    return nil
end

RegisterNetEvent('doj:gavelBroadcast', function(courtroomName)
    local room
    for _, c in ipairs(Config.Courtrooms) do
        if c.name == courtroomName then room = c; break end
    end
    if not room then return end
    local pos = GetEntityCoords(PlayerPedId())
    if #(pos - room.coords) > room.radius then return end

    SendNUIMessage({ type = 'gavelStrike', volume = 0.75 })
    VorpCore.NotifyObjective(_L('gavel_broadcast'), 4000)
end)

local GAVEL_PROMPT_RANGE = 2.0

local gavelPrompt
local gavelPromptGroup = GetHashKey('DOJ_GAVEL_GRP')
local gavelActive      = false
local gavelAnchor      = nil

CreateThread(function()
    gavelPrompt = PromptRegisterBegin()
    PromptSetControlAction(gavelPrompt, 0xC7B5340A)
    PromptSetText(gavelPrompt, CreateVarString(10, 'LITERAL_STRING', 'Strike Gavel'))
    PromptSetEnabled(gavelPrompt, true)
    PromptSetVisible(gavelPrompt, true)
    PromptSetStandardMode(gavelPrompt, true)
    PromptSetGroup(gavelPrompt, gavelPromptGroup)
    PromptRegisterEnd(gavelPrompt)
end)

function ActivateGavelPrompt()
    if not GetCurrentCourtroom() then
        ClientNotify(_L('gavel_not_courtroom'))
        return
    end
    gavelAnchor = GetEntityCoords(PlayerPedId())
    gavelActive = true
    ClientNotify(_L('gavel_ready'))
end

CreateThread(function()
    local groupLabel = CreateVarString(10, 'LITERAL_STRING', 'Court')
    local range2     = GAVEL_PROMPT_RANGE * GAVEL_PROMPT_RANGE
    while true do
        local sleep = 500
        if gavelActive and gavelAnchor then
            local pos = GetEntityCoords(PlayerPedId())
            local dx, dy, dz = pos.x - gavelAnchor.x, pos.y - gavelAnchor.y, pos.z - gavelAnchor.z
            if (dx * dx + dy * dy + dz * dz) <= range2 then
                sleep = 0
                PromptSetActiveGroupThisFrame(gavelPromptGroup, groupLabel)
                if PromptHasStandardModeCompleted(gavelPrompt) then
                    local room = GetCurrentCourtroom()
                    if room then
                        TriggerServerEvent('doj:gavel', room.name)
                    else
                        ClientNotify(_L('gavel_not_courtroom'))
                    end
                    Wait(500)
                end
            else
                gavelActive = false
                gavelAnchor = nil
                ClientNotify(_L('gavel_left'))
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then gavelActive = false end
end)
