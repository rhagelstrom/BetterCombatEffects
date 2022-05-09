function createEffectString()
    local effectString = dmgadd_first.getStringValue() .. parentcontrol.window.effect.getStringValue()  .. dmgadd_second.getStringValue() ..":"
    return effectString
end