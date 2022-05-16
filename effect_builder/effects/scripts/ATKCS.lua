function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() ..cycler_effect_state.getStringValue()
    return effectString
end