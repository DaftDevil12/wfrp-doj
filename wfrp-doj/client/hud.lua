local function DrawTxt(content, x, y, scale, r, g, b, a)
    SetTextScale(scale, scale)
    SetTextColor(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
    SetTextCentre(false)
    SetTextDropshadow(1, 0, 0, 0, 200)
    Citizen.InvokeNative(0xADA9255D, 1)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(content)), x, y)
end

CreateThread(function()
    while true do
        if OnDutyData then
            local h = Config.HUD
            local r, g, b, a = h.color[1], h.color[2], h.color[3], h.color[4]

            local elapsed = os.time() - (OnDutyData.startTime or os.time())

            DrawTxt(_L('hud_on_duty', OnDutyData.label or '?'),
                h.x, h.y, h.scale, r, g, b, a)
            DrawTxt(_L('hud_time', FormatDuration(elapsed)),
                h.x, h.y + 0.022, h.scale, r, g, b, a)

            Wait(0)
        else
            Wait(1000)
        end
    end
end)
