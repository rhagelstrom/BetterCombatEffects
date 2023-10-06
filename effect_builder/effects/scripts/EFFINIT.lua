-- luacheck: globals createEffectString dice_value
function createEffectString()
    return parentcontrol.window.effect.getStringValue() .. ': ' .. dice_value.getStringValue()
end
