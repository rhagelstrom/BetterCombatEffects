-- luacheck: globals createEffectString cycler_actor cycler_turn_add effect_savesdc number_value cycler_save_adv stat_value
-- luacheck: globals effect_savemagic effect_saveinvert effect_saveonhalf effect_deactivate effect_remove effect_removeany
function createEffectString()
    local effectString = '';
    if cycler_actor.getStringValue() ~= true and cycler_turn_add.getStringValue() ~= 'A' then
        effectString = cycler_actor.getStringValue()
    end
    effectString = effectString .. 'SAVE' .. cycler_turn_add.getStringValue() .. ': ';

    if effect_savesdc.getValue() > 0 then
        effectString = effectString .. ' [SDC]'
    else
        effectString = effectString .. number_value.getStringValue()
    end

    if cycler_save_adv.getStringValue() ~= true then
        effectString = effectString .. ' ' .. cycler_save_adv.getStringValue()
    end

    effectString = effectString .. ' ' .. stat_value.getStringValue()
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
