function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    if cycler_actor.getStringValue() == 'S' then
        effectString = cycler_actor.getStringValue() .. effectString .. cycler_turn.getStringValue()
    elseif cycler_turn.getStringValue() ~= 'S' then
        effectString = effectString .. cycler_turn.getStringValue()
    end

    effectString = effectString .. ': ' .. dice_value.getStringValue()
    local damageType = damage_types.getStringValue()
    if damageType ~= '' then
        effectString = effectString .. ' ' .. damageType
    end

    return effectString
end
