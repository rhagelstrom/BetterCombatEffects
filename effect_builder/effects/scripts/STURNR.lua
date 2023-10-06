-- luacheck: globals createEffectString cycler_turn
function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. cycler_turn.getStringValue()
    return effectString
end
