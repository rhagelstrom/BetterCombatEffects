local extensions = {}

function onInit()
    for index, name in pairs(Extension.getExtensions()) do
         extensions[name] = index
    end
end

function shouldLoadEffects()
    return extensions["FG-Effect-Builder"] and (extensions["FG-Effect-Builder-Plugin-5E"] or extensions["FG-Effect-Builder-Plugin-35E-PFRPG"])
end