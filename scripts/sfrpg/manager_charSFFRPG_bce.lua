-- luacheck: globals CharManagerSFRPGBCE BCEManager
-- luacheck: globals onInit onClose customOnResolveStam
local onResolveStam = nil;
local RulesetEffectManager = nil;

function onInit()
    RulesetEffectManager = BCEManager.getRulesetEffectManager();

    onResolveStam = CharManager.onResolveStam;
    CharManager.onResolveStam = customOnResolveStam;
end

function onClose()
    CharManager.onResolveStam = onResolveStam;
end

function customOnResolveStam(nodeChar, rActor)
    onResolveStam(nodeChar, rActor);

    local tMatch = RulesetEffectManager.getEffectsByType(rActor, 'RESTS');
    for _, tEffect in pairs(tMatch) do
        BCEManager.chat('RESTS' .. '  : ');
        BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
    end
end