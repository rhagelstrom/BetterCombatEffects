function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() ..cycler_effect_state.getStringValue() .. cycler_turn.getStringValue()
    return effectString
end