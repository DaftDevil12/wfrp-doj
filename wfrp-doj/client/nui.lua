local function setFocus(focus)
    SetNuiFocus(focus, focus)
end

function RequestOpenDutyBook()
    TriggerServerEvent('doj:requestDutyBook')
end

RegisterNetEvent('doj:openDutyBook', function(payload)
    SendNUIMessage({
        type       = 'openDutyBook',
        onDuty     = payload.onDuty,
        gradeLabel = payload.gradeLabel,
        roster     = payload.roster,
        canKick    = payload.canKick,
        pendingPay = payload.pendingPay
    })
    setFocus(true)
end)

RegisterNetEvent('doj:updateDutyBook', function(payload)
    SendNUIMessage({
        type       = 'updateDutyBook',
        onDuty     = payload.onDuty,
        gradeLabel = payload.gradeLabel,
        roster     = payload.roster,
        canKick    = payload.canKick,
        pendingPay = payload.pendingPay
    })
end)

RegisterNUICallback('close', function(_, cb)
    setFocus(false)
    TriggerServerEvent('doj:menuClosed')
    cb('ok')
end)

RegisterNUICallback('toggle_duty', function(_, cb)
    TriggerServerEvent('doj:requestToggle')
    cb('ok')
end)

RegisterNUICallback('kick', function(data, cb)
    local target = tonumber(data.target)
    if target then
        TriggerServerEvent('doj:requestKick', target)
    end
    cb('ok')
end)

RegisterCommand(Config.Commands.judge, function()
    if not IsOnDuty() then
        ClientNotify(_L('not_on_duty'))
        return
    end
    if not OnDutyData or not OnDutyData.canJudge then
        ClientNotify(_L('not_judge'))
        return
    end
    ActivateGavelPrompt()
end, false)

RegisterCommand(Config.Commands.dutybook, function()
    RequestOpenDutyBook()
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
