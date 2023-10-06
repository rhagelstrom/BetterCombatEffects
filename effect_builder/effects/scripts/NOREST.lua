-- luacheck: globals createEffectString effect_norestlong
function createEffectString()
    local sRet = parentcontrol.window.effect.getStringValue()
    if effect_norestlong.getValue() > 0 then
        sRet = sRet .. 'L'
    end

    -- end
    return sRet
end
