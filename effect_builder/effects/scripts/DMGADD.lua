function createEffectString()
    local effectString = dmgadd_first.getStringValue() .. parentcontrol.window.effect.getStringValue() ..  dmgadd_second.getStringValue()
    if bce_stringfield_valueholder.getValue() ~= Interface.getString("effect_draganddrop") then
        effectString = effectString .. ": "  .. bce_stringfield_valueholder.getValue()
    end
    return effectString
end