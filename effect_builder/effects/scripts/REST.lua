function createEffectString()
    local sRet = parentcontrol.window.effect.getStringValue()
    if effect_removerest.getValue() > 0 then
        sRet = sRet .. 'S'
    else
        sRet = sRet .. 'L'
    end
    return sRet
end
