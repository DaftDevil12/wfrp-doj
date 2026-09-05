VorpCore = exports.vorp_core:GetCore()

OnDuty       = {}
OpenDutyBook = {}

local PENDING_FILE = 'pending_pay.json'
local PendingPay   = {}

local function pkey(charId) return tostring(charId) end

local function round2(n)
    return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100
end

local function money(n)
    n = round2(n)
    if n == math.floor(n) then
        return string.format('%d', math.floor(n))
    end
    return string.format('%.2f', n)
end

local function GetPending(charId)
    if not charId then return 0 end
    return PendingPay[pkey(charId)] or 0
end

local function SavePending()
    SaveResourceFile(GetCurrentResourceName(), PENDING_FILE, json.encode(PendingPay), -1)
end

local function LoadPending()
    local raw = LoadResourceFile(GetCurrentResourceName(), PENDING_FILE)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then
        PendingPay = data
    end
end
LoadPending()

local function notify(src, msg, time)
    VorpCore.NotifyRightTip(src, msg, time or 4000)
end

local function GetUsedCharacter(src)
    local user = VorpCore.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

local function GetDojCharacter(src)
    local character = GetUsedCharacter(src)
    if not character then return nil end
    if character.job ~= Config.JobName then return nil end
    return character
end

local function PayOutPending(src, charId)
    local amount = round2(GetPending(charId))
    if amount <= 0 then return 0 end
    local character = GetUsedCharacter(src)
    if not character then return 0 end
    character.addCurrency(0, amount)
    PendingPay[pkey(charId)] = nil
    SavePending()
    return amount
end

local function ViewerCharId(src, info)
    if info then return info.charId end
    local c = GetUsedCharacter(src)
    return c and c.charIdentifier or nil
end

local function BuildRosterFor(viewerSrc)
    local viewerInfo  = OnDuty[viewerSrc]
    local viewerGrade = viewerInfo and Config.Grades[viewerInfo.jobGrade] or nil
    local canKick     = viewerGrade and viewerGrade.isBoss or false

    local roster = {}
    for src, info in pairs(OnDuty) do
        local g = Config.Grades[info.jobGrade] or { label = '?' }
        roster[#roster + 1] = {
            id    = src,
            name  = (info.firstName or '?') .. ' ' .. (info.lastName or '?'),
            grade = g.label,
            self  = (src == viewerSrc)
        }
    end
    table.sort(roster, function(a, b) return a.name < b.name end)
    return roster, canKick
end

local function PushDutyBookUpdate()
    for src in pairs(OpenDutyBook) do
        local info   = OnDuty[src]
        local g      = info and Config.Grades[info.jobGrade] or nil
        local roster, canKick = BuildRosterFor(src)
        TriggerClientEvent('doj:updateDutyBook', src, {
            onDuty     = info ~= nil,
            gradeLabel = g and g.label or nil,
            roster     = roster,
            canKick    = canKick,
            pendingPay = GetPending(ViewerCharId(src, info))
        })
    end
end

local function GoOnDuty(src, character)
    local grade = Config.Grades[character.jobGrade]
    if not grade then
        notify(src, _L('not_doj'))
        return
    end
    local info = {
        charId    = character.charIdentifier,
        jobGrade  = character.jobGrade,
        startTime = os.time(),
        lastPaid  = os.time(),
        firstName = character.firstname,
        lastName  = character.lastname
    }
    OnDuty[src] = info
    notify(src, _L('on_duty', grade.label))
    TriggerClientEvent('doj:dutyState', src, true, {
        label     = grade.label,
        startTime = info.startTime,
        isBoss    = grade.isBoss or false,
        canJudge  = grade.canJudge or false
    })
    LogDuty('on', character, grade)
    PushDutyBookUpdate()
end

local function GoOffDuty(src, reason)
    local info = OnDuty[src]
    if not info then return end
    local grade = Config.Grades[info.jobGrade] or { label = 'Unknown' }
    OnDuty[src] = nil

    local paid = PayOutPending(src, info.charId)

    notify(src, _L('off_duty'))
    if paid > 0 then
        notify(src, _L('salary_paid', money(paid)))
    end
    TriggerClientEvent('doj:dutyState', src, false, nil)
    LogDuty(reason or 'off', {
        firstname      = info.firstName,
        lastname       = info.lastName,
        charIdentifier = info.charId
    }, grade)
    PushDutyBookUpdate()
end

local function HandleDutyToggle(src)
    if OnDuty[src] then
        GoOffDuty(src, 'off')
    else
        local character = GetDojCharacter(src)
        if not character then
            notify(src, _L('not_doj'))
            return
        end
        GoOnDuty(src, character)
    end
end

RegisterNetEvent('doj:requestToggle', function()
    HandleDutyToggle(source)
end)

RegisterNetEvent('doj:requestDutyBook', function()
    local src     = source
    local info    = OnDuty[src]
    local character = GetDojCharacter(src)
    if not character and not info then
        notify(src, _L('not_doj'))
        return
    end

    OpenDutyBook[src] = true

    local roster, canKick = BuildRosterFor(src)
    local gradeLabel = nil
    if info then
        local g = Config.Grades[info.jobGrade]
        gradeLabel = g and g.label or '?'
    elseif character then
        local g = Config.Grades[character.jobGrade]
        gradeLabel = g and g.label or '?'
    end

    TriggerClientEvent('doj:openDutyBook', src, {
        onDuty     = info ~= nil,
        gradeLabel = gradeLabel,
        roster     = roster,
        canKick    = canKick,
        pendingPay = GetPending(ViewerCharId(src, info))
    })
end)

RegisterNetEvent('doj:menuClosed', function()
    OpenDutyBook[source] = nil
end)

RegisterNetEvent('doj:requestKick', function(targetId)
    local src  = source
    local info = OnDuty[src]
    if not info then
        notify(src, _L('not_on_duty'))
        return
    end
    local grade = Config.Grades[info.jobGrade]
    if not grade or not grade.isBoss then
        notify(src, _L('not_boss'))
        return
    end

    targetId = tonumber(targetId)
    if not targetId or targetId == src or GetPlayerName(targetId) == nil then
        notify(src, _L('target_invalid'))
        return
    end

    local targetInfo = OnDuty[targetId]
    if not targetInfo then
        notify(src, _L('target_not_doj'))
        return
    end

    local kickerName = info.firstName .. ' ' .. info.lastName
    local targetName = targetInfo.firstName .. ' ' .. targetInfo.lastName

    GoOffDuty(targetId, 'kicked')
    notify(src, _L('kicked_target', targetName))
    notify(targetId, _L('you_were_kicked', kickerName), 5000)

    LogKick(info, targetInfo)
end)

RegisterNetEvent('doj:gavel', function(courtroomName)
    local src  = source
    local info = OnDuty[src]
    if not info then
        notify(src, _L('not_on_duty'))
        return
    end
    local grade = Config.Grades[info.jobGrade]
    if not grade or not grade.canJudge then
        notify(src, _L('not_judge'))
        return
    end
    TriggerClientEvent('doj:gavelBroadcast', -1, courtroomName)
end)

CreateThread(function()
    while true do
        Wait(Config.SalaryInterval * 60 * 1000)
        local changed = false
        for src, info in pairs(OnDuty) do
            local character = GetDojCharacter(src)
            if character then
                local grade = Config.Grades[character.jobGrade]
                if grade and grade.salary and grade.salary > 0 then
                    local k = pkey(info.charId)
                    PendingPay[k] = round2((PendingPay[k] or 0) + grade.salary)
                    info.lastPaid = os.time()
                    changed = true
                    notify(src, _L('salary_accrued', money(grade.salary), money(PendingPay[k])))
                end
            end
        end
        if changed then
            SavePending()
            PushDutyBookUpdate()
        end
    end
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    SetTimeout(2500, function()
        if not GetPlayerName(src) then return end
        local character = GetUsedCharacter(src)
        local charId    = character and character.charIdentifier
        if not charId then return end
        local paid = PayOutPending(src, charId)
        if paid > 0 then
            notify(src, _L('salary_backpay', money(paid)))
        end
    end)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000)
        for _, pid in ipairs(GetPlayers()) do
            local src       = tonumber(pid)
            local character = GetUsedCharacter(src)
            local charId    = character and character.charIdentifier
            if charId and GetPending(charId) > 0 then
                local paid = PayOutPending(src, charId)
                if paid > 0 then
                    notify(src, _L('salary_backpay', money(paid)))
                end
            end
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    OpenDutyBook[src] = nil
    if OnDuty[src] then
        local info  = OnDuty[src]
        local grade = Config.Grades[info.jobGrade] or { label = 'Unknown' }
        OnDuty[src] = nil
        LogDuty('disconnect', {
            firstname      = info.firstName,
            lastname       = info.lastName,
            charIdentifier = info.charId
        }, grade)
        PushDutyBookUpdate()
    end
end)
