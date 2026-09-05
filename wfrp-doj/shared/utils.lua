function _L(key, ...)
    local tbl = Locales[Config.Locale] or Locales['en']
    local str = tbl[key] or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format('%02d:%02d:%02d', h, m, s)
end
