-- luacheck: globals createEffectString cycler_save_add bce_stringfield_valueholder
function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    if cycler_save_add.getStringValue() ~= true then
        effectString = effectString .. cycler_save_add.getStringValue()
    end
    if bce_stringfield_valueholder.getValue() ~= Interface.getString('effect_draganddrop') then
        effectString = effectString .. ': ' .. bce_stringfield_valueholder.getValue()
    end
    return effectString
end
