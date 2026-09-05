local VorpCore = exports.vorp_core:GetCore()

local Lawyers       = {}
local LawyerAlerts  = {}
local AlertCooldown = {}

local function lcfg(key, default)
    local c = Config.Lawyers or {}
    local v = c[key]
    if v == nil then return default end
    return v
end

local function pkey(id) return tostring(id) end

local function CacheFromRows(rows)
    Lawyers = {}
    if not rows then return end
    for _, row in ipairs(rows) do
        Lawyers[pkey(row.charidentifier)] = { name = row.name, since = row.since }
    end
end

local function MigrateLegacyJson()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'lawyers.json')
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' or next(data) == nil then return end

    for cid, info in pairs(data) do
        local name  = type(info) == 'table' and info.name or nil
        local since = (type(info) == 'table' and info.since) or os.time()
        MySQL.insert('INSERT IGNORE INTO doj_lawyers (charidentifier, name, since) VALUES (?, ?, ?)',
            { tonumber(cid), name, since })
        Lawyers[pkey(cid)] = { name = name, since = since }
    end

    SaveResourceFile(GetCurrentResourceName(), 'lawyers.json.bak', raw, -1)
    SaveResourceFile(GetCurrentResourceName(), 'lawyers.json', '', -1)
    print('[wfrp-doj] Imported legacy lawyers.json into doj_lawyers (backup: lawyers.json.bak).')
end

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `doj_lawyers` (
            `charidentifier` INT NOT NULL,
            `name`     VARCHAR(255) DEFAULT NULL,
            `hired_by` VARCHAR(255) DEFAULT NULL,
            `since`    INT DEFAULT NULL,
            PRIMARY KEY (`charidentifier`)
        )
    ]], {}, function()
        MySQL.query('SELECT `charidentifier`, `name`, `since` FROM `doj_lawyers`', {}, function(rows)
            CacheFromRows(rows)
            MigrateLegacyJson()
            print(('[wfrp-doj] Loaded %d lawyer(s) from doj_lawyers.'):format(rows and #rows or 0))
        end)
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `doj_lawyer_ledger` (
            `id`             INT NOT NULL AUTO_INCREMENT,
            `charidentifier` INT NOT NULL,
            `type`           VARCHAR(16) NOT NULL,
            `amount`         DECIMAL(12,2) NOT NULL,
            `party`          VARCHAR(255) DEFAULT NULL,
            `reason`         VARCHAR(255) DEFAULT NULL,
            `created`        INT DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_doj_ledger_char` (`charidentifier`)
        )
    ]], {})
end)

local function notify(src, msg, time)
    if src and src > 0 then
        VorpCore.NotifyRightTip(src, msg, time or 4000)
    else
        print('[wfrp-doj] ' .. tostring(msg))
    end
end

local function GetUsedCharacter(src)
    local user = VorpCore.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

local function CharId(src)
    local c = GetUsedCharacter(src)
    return c and c.charIdentifier or nil
end

local function CharName(src)
    local c = GetUsedCharacter(src)
    if not c then return GetPlayerName(src) or 'Unknown' end
    return (c.firstname or '?') .. ' ' .. (c.lastname or '?')
end

local function IsDojBoss(src)
    if src == 0 then return true end
    local c = GetUsedCharacter(src)
    if not c or c.job ~= Config.JobName then return false end
    local g = Config.Grades[c.jobGrade]
    return g ~= nil and g.isBoss == true
end

local function IsLawyerChar(charId)
    return charId ~= nil and Lawyers[pkey(charId)] ~= nil
end

local function IsLawyer(src)
    if IsLawyerChar(CharId(src)) then return true end
    if lcfg('includeOnDutyDoj', true) and OnDuty and OnDuty[src] then return true end
    return false
end

local function OnlineLawyerSources()
    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        local s = tonumber(pid)
        if s and IsLawyer(s) then list[#list + 1] = s end
    end
    return list
end

local function PushLawyerStatus(src)
    TriggerClientEvent('doj:lawyerStatus', src, IsLawyerChar(CharId(src)))
end

RegisterNetEvent('doj:requestLawyerStatus', function()
    PushLawyerStatus(source)
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    SetTimeout(2500, function()
        if GetPlayerName(src) then PushLawyerStatus(src) end
    end)
end)

RegisterCommand(lcfg('hireCommand', 'lawyerhire'), function(src, args)
    if not IsDojBoss(src) then notify(src, _L('lw_not_boss')); return end

    local targetId = tonumber(args[1])
    if not targetId then
        notify(src, _L('lw_hire_usage', lcfg('hireCommand', 'lawyerhire')))
        return
    end
    if not GetPlayerName(targetId) then notify(src, _L('lw_bad_target')); return end

    local tchar = GetUsedCharacter(targetId)
    if not tchar then notify(src, _L('lw_target_nochar')); return end

    local cid  = tchar.charIdentifier
    local name = (tchar.firstname or '?') .. ' ' .. (tchar.lastname or '?')
    if IsLawyerChar(cid) then notify(src, _L('lw_already', name)); return end

    local now     = os.time()
    local hiredBy = (src == 0) and 'console' or (CharName(src) or 'console')

    Lawyers[pkey(cid)] = { name = name, since = now }
    MySQL.insert(
        'INSERT INTO doj_lawyers (charidentifier, name, hired_by, since) VALUES (?, ?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE name = ?, hired_by = ?, since = ?',
        { cid, name, hiredBy, now, name, hiredBy, now })

    notify(src, _L('lw_hired', name))
    notify(targetId, _L('lw_you_hired', lcfg('menuCommand', 'lawyermenu')), 6000)
    PushLawyerStatus(targetId)
    LogLawyerHire((src == 0) and 'Console' or CharName(src), { name = name, charId = cid })
end, false)

RegisterCommand(lcfg('fireCommand', 'lawyerfire'), function(src, args)
    if not IsDojBoss(src) then notify(src, _L('lw_not_boss')); return end

    local n = tonumber(args[1])
    if not n then
        notify(src, _L('lw_hire_usage', lcfg('fireCommand', 'lawyerfire')))
        return
    end

    local cid, name, onlineSrc
    if GetPlayerName(n) then
        local tchar = GetUsedCharacter(n)
        cid  = tchar and tchar.charIdentifier
        name = tchar and ((tchar.firstname or '?') .. ' ' .. (tchar.lastname or '?')) or nil
        onlineSrc = n
    else
        cid = n
    end

    if not cid or not IsLawyerChar(cid) then
        notify(src, _L('lw_not_listed', name or ('#' .. tostring(n))))
        return
    end

    name = name or (Lawyers[pkey(cid)] and Lawyers[pkey(cid)].name) or ('#' .. tostring(cid))
    Lawyers[pkey(cid)] = nil
    MySQL.update('DELETE FROM doj_lawyers WHERE charidentifier = ?', { cid })

    notify(src, _L('lw_fired', name))
    if onlineSrc then
        notify(onlineSrc, _L('lw_you_fired'), 6000)
        PushLawyerStatus(onlineSrc)
    end
    LogLawyerFire((src == 0) and 'Console' or CharName(src), { name = name, charId = cid })
end, false)

RegisterNetEvent('doj:lawyerAlert', function(message, coords)
    local src = source
    local cid = CharId(src) or src
    local now = os.time()
    local cd  = tonumber(lcfg('alertCooldown', 30)) or 30

    local last = AlertCooldown[pkey(cid)]
    if last and (now - last) < cd then
        notify(src, _L('lw_alert_cooldown', cd - (now - last)))
        return
    end
    AlertCooldown[pkey(cid)] = now

    message = tostring(message or ''):gsub('^%s*(.-)%s*$', '%1')
    if message == '' then message = _L('lw_no_message') end
    if #message > 150 then message = message:sub(1, 150) end

    coords = coords or {}
    local alert = {
        sender  = CharName(src),
        message = message,
        x       = tonumber(coords.x) or 0.0,
        y       = tonumber(coords.y) or 0.0,
        z       = tonumber(coords.z) or 0.0,
        time    = now,
        when    = os.date('%H:%M', now)
    }

    table.insert(LawyerAlerts, 1, alert)
    local maxN = tonumber(lcfg('maxStoredAlerts', 25)) or 25
    while #LawyerAlerts > maxN do table.remove(LawyerAlerts) end

    for _, s in ipairs(OnlineLawyerSources()) do
        TriggerClientEvent('doj:lawyerAlertIncoming', s, alert)
    end

    notify(src, _L('lw_alert_sent'))
end)

RegisterNetEvent('doj:requestLawyerMenu', function()
    local src = source
    if not IsLawyer(src) then notify(src, _L('lw_not_lawyer')); return end
    TriggerClientEvent('doj:openLawyerMenu', src, {
        alerts = LawyerAlerts,
        online = #OnlineLawyerSources()
    })
end)

local function round2(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end

local function money(n)
    n = round2(n)
    if n == math.floor(n) then return string.format('%d', math.floor(n)) end
    return string.format('%.2f', n)
end

local PendingBills    = {}
local PendingByTarget = {}
local nextBillId      = 0

local function LedgerBalance(charId)
    local bal = MySQL.scalar.await(
        'SELECT COALESCE(SUM(amount), 0) FROM doj_lawyer_ledger WHERE charidentifier = ?', { charId })
    return round2(bal or 0)
end

local function LedgerHistory(charId)
    local n = tonumber(lcfg('maxLedgerHistory', 20)) or 20
    local rows = MySQL.query.await(
        'SELECT `type`, `amount`, `party`, `reason`, `created` FROM doj_lawyer_ledger '
        .. 'WHERE charidentifier = ? ORDER BY id DESC LIMIT ?', { charId, n })
    local out = {}
    if rows then
        for _, r in ipairs(rows) do
            out[#out + 1] = {
                type   = r.type,
                amount = math.abs(tonumber(r.amount) or 0),
                party  = r.party,
                reason = r.reason,
                when   = r.created and os.date('%m/%d %H:%M', r.created) or ''
            }
        end
    end
    return out
end

local function SendLedger(src)
    local cid = CharId(src)
    if not cid then return end
    TriggerClientEvent('doj:openLawyerLedger', src, {
        balance = LedgerBalance(cid),
        history = LedgerHistory(cid)
    })
end

RegisterNetEvent('doj:requestLawyerLedger', function()
    local src = source
    if not IsLawyer(src) then notify(src, _L('lw_not_lawyer')); return end
    SendLedger(src)
end)

RegisterNetEvent('doj:requestLawyerBill', function()
    local src = source
    if not IsLawyer(src) then notify(src, _L('lw_not_lawyer')); return end
    TriggerClientEvent('doj:openLawyerBill', src)
end)

RegisterNetEvent('doj:lawyerBill', function(targetId, amount, reason)
    local src = source
    if not IsLawyer(src) then notify(src, _L('lw_not_lawyer')); return end

    targetId = tonumber(targetId)
    amount   = round2(amount)
    reason   = tostring(reason or ''):gsub('^%s*(.-)%s*$', '%1')

    if amount <= 0 then notify(src, _L('lw_bill_bad_amount')); return end
    local maxBill = tonumber(lcfg('maxBill', 0)) or 0
    if maxBill > 0 and amount > maxBill then notify(src, _L('lw_bill_over_max', money(maxBill))); return end
    if reason == '' then notify(src, _L('lw_bill_no_reason')); return end
    if #reason > 150 then reason = reason:sub(1, 150) end
    if not targetId or not GetPlayerName(targetId) then notify(src, _L('lw_bill_target_off')); return end
    if targetId == src then notify(src, _L('lw_bill_self')); return end
    if PendingByTarget[targetId] then notify(src, _L('lw_bill_pending')); return end

    local billerCid = CharId(src)
    if not billerCid then return end

    nextBillId = nextBillId + 1
    local billId = nextBillId
    PendingBills[billId] = {
        biller     = billerCid,
        billerSrc  = src,
        billerName = CharName(src),
        targetSrc  = targetId,
        targetName = CharName(targetId),
        amount     = amount,
        reason     = reason
    }
    PendingByTarget[targetId] = billId

    TriggerClientEvent('doj:lawyerBillIncoming', targetId, {
        billId = billId,
        from   = CharName(src),
        amount = amount,
        reason = reason
    })
    notify(src, _L('lw_bill_sent', money(amount), CharName(targetId)))
    LogLawyerBill('sent', { lawyer = CharName(src), target = CharName(targetId), amount = money(amount), reason = reason })

    local timeout = (tonumber(lcfg('billTimeout', 60)) or 60) * 1000
    SetTimeout(timeout, function()
        local b = PendingBills[billId]
        if not b then return end
        PendingBills[billId] = nil
        if PendingByTarget[b.targetSrc] == billId then PendingByTarget[b.targetSrc] = nil end
        if GetPlayerName(b.targetSrc) then TriggerClientEvent('doj:lawyerBillClose', b.targetSrc, billId) end
        if GetPlayerName(b.billerSrc) then notify(b.billerSrc, _L('lw_bill_expired', b.targetName)) end
        LogLawyerBill('expired', { lawyer = b.billerName, target = b.targetName, amount = money(b.amount) })
    end)
end)

RegisterNetEvent('doj:lawyerBillRespond', function(billId, accept)
    local src = source
    billId = tonumber(billId)
    local b = billId and PendingBills[billId] or nil
    if not b or b.targetSrc ~= src then notify(src, _L('lw_bill_invalid')); return end

    PendingBills[billId] = nil
    if PendingByTarget[src] == billId then PendingByTarget[src] = nil end

    if not accept then
        notify(src, _L('lw_bill_refused', b.billerName))
        if GetPlayerName(b.billerSrc) then notify(b.billerSrc, _L('lw_bill_denied', CharName(src))) end
        LogLawyerBill('denied', { lawyer = b.billerName, target = CharName(src), amount = money(b.amount) })
        return
    end

    local payer = GetUsedCharacter(src)
    if not payer then notify(src, _L('lw_bill_invalid')); return end
    payer.removeCurrency(0, b.amount)

    MySQL.insert(
        'INSERT INTO doj_lawyer_ledger (charidentifier, `type`, amount, party, reason, created) '
        .. 'VALUES (?, ?, ?, ?, ?, ?)',
        { b.biller, 'bill', b.amount, CharName(src), b.reason, os.time() })

    notify(src, _L('lw_bill_paid', money(b.amount), b.billerName))
    if GetPlayerName(b.billerSrc) then
        notify(b.billerSrc, _L('lw_bill_accepted', CharName(src), money(b.amount)))
    end
    LogLawyerBill('accepted', { lawyer = b.billerName, target = CharName(src), amount = money(b.amount), reason = b.reason })
end)

RegisterNetEvent('doj:lawyerLedgerWithdraw', function(amount)
    local src = source
    if not IsLawyer(src) then notify(src, _L('lw_not_lawyer')); return end

    amount = round2(amount)
    if amount <= 0 then notify(src, _L('lw_ledger_bad')); return end

    local cid = CharId(src)
    if not cid then return end

    local balance = LedgerBalance(cid)
    if amount > balance then notify(src, _L('lw_ledger_short', money(balance))); return end

    MySQL.insert(
        'INSERT INTO doj_lawyer_ledger (charidentifier, `type`, amount, created) VALUES (?, ?, ?, ?)',
        { cid, 'withdraw', -amount, os.time() })

    local char = GetUsedCharacter(src)
    if char then char.addCurrency(0, amount) end

    notify(src, _L('lw_ledger_withdrew', money(amount)))
    LogLawyerLedger(CharName(src), money(amount), money(balance - amount))
    SendLedger(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local billId = PendingByTarget[src]
    if not billId then return end
    local b = PendingBills[billId]
    PendingBills[billId] = nil
    PendingByTarget[src] = nil
    if b and GetPlayerName(b.billerSrc) then
        notify(b.billerSrc, _L('lw_bill_expired', b.targetName))
    end
end)
