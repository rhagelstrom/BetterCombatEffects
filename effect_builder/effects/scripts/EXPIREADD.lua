function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    if bce_stringfield_valueholder.getValue() ~= Interface.getString('effect_draganddrop') then
        effectString = effectString .. ': ' .. bce_stringfield_valueholder.getValue()
    end
    return effectString
end
