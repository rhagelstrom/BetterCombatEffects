function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ': '
    if effect_savesdc.getValue() > 0 then
        effectString = effectString .. ' [SDC]'
    else
        effectString = effectString .. number_value.getStringValue()
    end
    if stat_value.getStringValue() ~= '' then
        effectString = effectString .. ' ' .. stat_value.getStringValue()
    end
    if cycler_save_adv.getStringValue() ~= true then
        effectString = effectString .. ' ' .. cycler_save_adv.getStringValue()
    end
    if effect_savemagic.getValue() > 0 then
        effectString = effectString .. ' (M)'
    end
    if effect_saveinvert.getValue() > 0 then
        effectString = effectString .. ' (F)'
    end
    if effect_saveonhalf.getValue() > 0 then
        effectString = effectString .. ' (H)'
    end
    if effect_deactivate.getValue() > 0 then
        effectString = effectString .. ' (D)'
    end
    if effect_remove.getValue() > 0 then
        effectString = effectString .. ' (R)'
    end
    if effect_removeany.getValue() > 0 then
        effectString = effectString .. ' (RA)'
    end

    return effectString
end
