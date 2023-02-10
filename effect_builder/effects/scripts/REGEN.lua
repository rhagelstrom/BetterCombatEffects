function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    if effect_temphp.getValue() > 0 then
        effectString = 'T' .. effectString
    end
    if cycler_actor.getStringValue() == 'S' then
        effectString = cycler_actor.getStringValue() .. effectString .. cycler_turn.getStringValue()
    elseif effect_temphp.getValue() > 0 or cycler_turn.getStringValue() ~= 'S' then
        effectString = effectString .. cycler_turn.getStringValue()
    end

    effectString = effectString .. ': ' .. dice_value.getStringValue()
    if not damage_type_1.isEmpty() and not damage_type_2.isEmpty() then
        effectString = effectString .. ' ' .. damage_type_1.getValue() .. ' ' .. and_or.getStringValue() .. ' ' .. damage_type_2.getValue()
    elseif not damage_type_1.isEmpty() or not damage_type_2.isEmpty() then
        effectString = effectString .. ' ' .. damage_type_1.getValue() .. damage_type_2.getValue()
    end

    return effectString
end
