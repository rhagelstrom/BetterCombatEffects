function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    if effect_temphp.getValue() > 0 then
        effectString = 'T' .. effectString
    end

    effectString = effectString .. ': ' .. dice_value.getStringValue()

    return effectString
end
