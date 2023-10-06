-- luacheck: globals createEffectString
function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue()
    return effectString
end
