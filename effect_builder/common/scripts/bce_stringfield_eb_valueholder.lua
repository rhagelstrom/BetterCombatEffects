function onInit()
    if super and super.onInit then
        super.onInit()
    end
    setValue(Interface.getString("effect_draganddrop"))
end

function onDrop(x, y, dragdata)
    if super and super.onDrop and dragdata.getType() == "effect" then
        local sEffect =  EffectManager.decodeEffectFromDrag(dragdata)
        local aEffectComps = EffectManager.parseEffect(sEffect.sName)
        if next (EffectsManagerBCE.matchEffect(aEffectComps[1])) then
            dragdata.setStringData(aEffectComps[1])
        else
            dragdata.setStringData(Interface.getString("effect_draganddrop"))
        end

    end
    return super.onDrop(x,y,dragdata)
end