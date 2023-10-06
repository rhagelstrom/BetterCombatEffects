-- luacheck: globals createEffectString cycler_effect_state
function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. cycler_effect_state.getStringValue() .. 'T'
    return effectString
end
