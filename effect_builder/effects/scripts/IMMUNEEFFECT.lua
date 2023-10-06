-- luacheck: globals createEffectString bce_stringfield_valueholder
function createEffectString()
    local effectString = 'IMMUNE'
    if bce_stringfield_valueholder.getValue() ~= Interface.getString('effect_draganddrop') then
        effectString = effectString .. ': ' .. bce_stringfield_valueholder.getValue()
    end
    return effectString
end
