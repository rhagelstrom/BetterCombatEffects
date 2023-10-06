-- luacheck: globals createEffectString cycler_effect_state
function createEffectString()
    local effectString = "ATK" .. cycler_effect_state.getStringValue()
    return effectString
end
