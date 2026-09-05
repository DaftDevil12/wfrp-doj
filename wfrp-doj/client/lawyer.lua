local function setFocus(focus) SetNuiFocus(focus, focus) end

RegisterCommand(Config.Lawyers.alertCommand, function(_, args)
    local message = table.concat(args, ' ')
    local p = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('doj:lawyerAlert', message, { x = p.x, y = p.y, z = p.z })
end, false)

RegisterCommand(Config.Lawyers.menuCommand, function()
    TriggerServerEvent('doj:requestLawyerMenu')
end, false)

RegisterCommand(Config.Lawyers.billCommand, function()
    TriggerServerEvent('doj:requestLawyerBill')
end, false)

RegisterNetEvent('doj:lawyerAlertIncoming', function(alert)
    VorpCore.NotifyObjective(_L('lw_incoming', alert.sender, alert.message), 6000)
    SendNUIMessage({ type = 'lawyerAlertAdd', alert = alert })
end)

RegisterNetEvent('doj:openLawyerMenu', function(payload)
    SendNUIMessage({
        type   = 'openLawyer',
        alerts = payload.alerts or {},
        online = payload.online or 0
    })
    setFocus(true)
end)

local function CreateLocateBlip(x, y, z)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, GetHashKey('blip_ambient_law'), x, y, z)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', 'Lawyer Alert'))
    ClientNotify(_L('lw_located'))

    local life = (Config.Lawyers.locateBlipTime or 60) * 1000
    SetTimeout(life, function()
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end

RegisterNUICallback('lawyer_locate', function(data, cb)
    setFocus(false)
    local x = tonumber(data.x)
    local y = tonumber(data.y)
    local z = tonumber(data.z)
    if x and y then CreateLocateBlip(x + 0.0, y + 0.0, (z or 0) + 0.0) end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

local isRegisteredLawyer = false

RegisterNetEvent('doj:lawyerStatus', function(registered)
    isRegisteredLawyer = registered and true or false
end)

AddEventHandler('vorp:SelectedCharacter', function()
    TriggerServerEvent('doj:requestLawyerStatus')
end)
CreateThread(function()
    Wait(3000)
    TriggerServerEvent('doj:requestLawyerStatus')
end)

local function CanUseLawyerMenu()
    if isRegisteredLawyer then return true end
    if Config.Lawyers.includeOnDutyDoj and IsOnDuty and IsOnDuty() then return true end
    return false
end

local billPrompt
local billPromptGroup = GetHashKey('DOJ_LAWYER_GRP')

CreateThread(function()
    billPrompt = PromptRegisterBegin()
    PromptSetControlAction(billPrompt, 0xC7B5340A)
    PromptSetText(billPrompt, CreateVarString(10, 'LITERAL_STRING', Config.Lawyers.promptLabel or 'Law Office'))
    PromptSetEnabled(billPrompt, true)
    PromptSetVisible(billPrompt, true)
    PromptSetStandardMode(billPrompt, true)
    PromptSetGroup(billPrompt, billPromptGroup)
    PromptRegisterEnd(billPrompt)
end)

CreateThread(function()
    local locations  = Config.Lawyers.menuLocations or {}
    local dist       = Config.Lawyers.promptDistance or 2.0
    local dist2      = dist * dist
    local groupLabel = CreateVarString(10, 'LITERAL_STRING', Config.Lawyers.promptLabel or 'Law Office')

    while true do
        local sleep = 1000
        if #locations > 0 and CanUseLawyerMenu() then
            local pos  = GetEntityCoords(PlayerPedId())
            local near = false
            for _, loc in ipairs(locations) do
                local dx, dy, dz = pos.x - loc.x, pos.y - loc.y, pos.z - loc.z
                if (dx * dx + dy * dy + dz * dz) <= dist2 then near = true; break end
            end
            if near then
                sleep = 0
                PromptSetActiveGroupThisFrame(billPromptGroup, groupLabel)
                if PromptHasStandardModeCompleted(billPrompt) then
                    TriggerServerEvent('doj:requestLawyerLedger')
                    Wait(600)
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('doj:openLawyerLedger', function(payload)
    SendNUIMessage({
        type    = 'openLedger',
        balance = payload.balance or 0,
        history = payload.history or {}
    })
    setFocus(true)
end)

RegisterNetEvent('doj:openLawyerBill', function()
    SendNUIMessage({ type = 'openBill' })
    setFocus(true)
end)

RegisterNetEvent('doj:lawyerBillIncoming', function(bill)
    SendNUIMessage({
        type   = 'openBillPrompt',
        billId = bill.billId,
        from   = bill.from,
        amount = bill.amount,
        reason = bill.reason
    })
    setFocus(true)
end)

RegisterNetEvent('doj:lawyerBillClose', function(billId)
    SendNUIMessage({ type = 'closeBillPrompt', billId = billId })
    setFocus(false)
end)

RegisterNUICallback('lawyer_bill_send', function(data, cb)
    TriggerServerEvent('doj:lawyerBill', data.target, data.amount, data.reason)
    cb('ok')
end)

RegisterNUICallback('lawyer_ledger_withdraw', function(data, cb)
    TriggerServerEvent('doj:lawyerLedgerWithdraw', data.amount)
    cb('ok')
end)

RegisterNUICallback('lawyer_bill_respond', function(data, cb)
    setFocus(false)
    TriggerServerEvent('doj:lawyerBillRespond', data.billId, data.accept and true or false)
    cb('ok')
end)
