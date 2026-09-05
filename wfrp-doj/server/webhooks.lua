local function send(url, title, fields, color)
    if not url or url == '' then return end
    local payload = {
        username   = Config.WebhookName,
        avatar_url = Config.WebhookAvatar ~= '' and Config.WebhookAvatar or nil,
        embeds     = { {
            title  = title,
            color  = color,
            fields = fields,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') }
        } }
    }
    PerformHttpRequest(url, function() end, 'POST',
        json.encode(payload),
        { ['Content-Type'] = 'application/json' })
end

function LogDuty(action, character, grade)
    local titles = {
        on         = 'Went On Duty',
        off        = 'Went Off Duty',
        kicked     = 'Forced Off Duty',
        disconnect = 'Off Duty (disconnect)'
    }
    local colors = {
        on         = 3066993,
        off        = 15158332,
        kicked     = 15105570,
        disconnect = 9807270
    }
    send(Config.Webhooks.duty, titles[action] or action, {
        { name = 'Name',    value = (character.firstname or '?') .. ' ' .. (character.lastname or '?'), inline = true },
        { name = 'Char ID', value = tostring(character.charIdentifier or '?'),                          inline = true },
        { name = 'Grade',   value = grade.label or '?',                                                 inline = true }
    }, colors[action] or 16777215)
end

function LogKick(kicker, target)
    local kgrade = Config.Grades[kicker.jobGrade] or { label = '?' }
    local tgrade = Config.Grades[target.jobGrade] or { label = '?' }
    send(Config.Webhooks.kick, 'Forced Off Duty', {
        { name = 'Boss',   value = kicker.firstName .. ' ' .. kicker.lastName .. ' (' .. kgrade.label .. ')' },
        { name = 'Target', value = target.firstName .. ' ' .. target.lastName .. ' (' .. tgrade.label .. ')' }
    }, 15105570)
end

function LogLawyerHire(bossName, target)
    send(Config.Webhooks.lawyer, 'Lawyer Hired', {
        { name = 'Lawyer',  value = target.name or '?',             inline = true },
        { name = 'Char ID', value = tostring(target.charId or '?'), inline = true },
        { name = 'By',      value = bossName or '?',                inline = true }
    }, 3066993)
end

function LogLawyerFire(bossName, target)
    send(Config.Webhooks.lawyer, 'Lawyer Dismissed', {
        { name = 'Lawyer',  value = target.name or '?',             inline = true },
        { name = 'Char ID', value = tostring(target.charId or '?'), inline = true },
        { name = 'By',      value = bossName or '?',                inline = true }
    }, 15158332)
end

function LogLawyerBill(action, data)
    local titles = { sent = 'Bill Issued', accepted = 'Bill Paid', denied = 'Bill Denied', expired = 'Bill Expired' }
    local colors = { sent = 3447003, accepted = 3066993, denied = 15158332, expired = 9807270 }
    local fields = {
        { name = 'Lawyer',    value = data.lawyer or '?',          inline = true },
        { name = 'Recipient', value = data.target or '?',          inline = true },
        { name = 'Amount',    value = '$' .. (data.amount or '0'),  inline = true }
    }
    if data.reason and data.reason ~= '' then
        fields[#fields + 1] = { name = 'Reason', value = data.reason, inline = false }
    end
    send(Config.Webhooks.lawyer, titles[action] or 'Bill', fields, colors[action] or 16777215)
end

function LogLawyerLedger(lawyerName, amount, balance)
    send(Config.Webhooks.lawyer, 'Ledger Withdrawal', {
        { name = 'Lawyer',   value = lawyerName or '?',         inline = true },
        { name = 'Withdrew', value = '$' .. (amount or '0'),    inline = true },
        { name = 'Balance',  value = '$' .. (balance or '0'),   inline = true }
    }, 15844367)
end
