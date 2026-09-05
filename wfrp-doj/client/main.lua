VorpCore = exports.vorp_core:GetCore()

OnDutyData = nil

function IsOnDuty()
    return OnDutyData ~= nil
end

function ClientNotify(msg, time)
    VorpCore.NotifyRightTip(msg, time or 4000)
end

RegisterNetEvent('doj:dutyState', function(state, data)
    if state then
        OnDutyData = data
    else
        OnDutyData = nil
    end
end)
