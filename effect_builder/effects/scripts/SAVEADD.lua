function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    if cycler_save_add.getStringValue() ~= true then
        effectString = effectString .. cycler_save_add.getStringValue()
    end
    return effectString
end