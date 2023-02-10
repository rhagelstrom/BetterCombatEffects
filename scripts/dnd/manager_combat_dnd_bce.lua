--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local RulesetEffectManager = nil;
local resetHealth = nil
function onInit()
    CombatManagerBCE.setCustomProcessTurnStart(CombatManagerDnDBCE.processEffectTurnStartDND);
    CombatManagerBCE.setCustomProcessTurnEnd(CombatManagerDnDBCE.processEffectTurnEndDND);
    RulesetEffectManager = BCEManager.getRulesetEffectManager();

    resetHealth = CombatManager2.resetHealth;
    CombatManager2.resetHealth = customResetHealth;
end

function onClose()
    CombatManager2.resetHealth = resetHealth;
end

function customResetHealth(nodeCT, bLong)
    BCEManager.chat('customResetHealth : ');
    local rSource = ActorManager.resolveActor(nodeCT)

    local aTags = {'RESTS'};
    if bLong == true then
        table.insert(aTags, 'RESTL');
    end

    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag);
        for _, tEffect in pairs(tMatch) do
            BCEManager.chat(sTag .. '  : ');
            BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
        end
    end
    resetHealth(nodeCT, bLong);
end

function processEffectTurnStartDND(rSource)
    BCEManager.chat('processEffectTurnStartDND: ');
    -- Only process these if on the source node
    local tMatch = RulesetEffectManager.getEffectsByType(rSource, 'TREGENS');
    for _, tEffect in pairs(tMatch) do
        EffectManagerDnDBCE.applyOngoingRegen(rSource, rSource, tEffect, true);
    end

    -- Tags to be processed on other nodes in the CT
    local aTags = {'SDMGOS', 'SREGENS', 'STREGENS'};
    local ctEntries = CombatManager.getCombatantNodes();
    for _, nodeCT in pairs(ctEntries) do
        local rActor = ActorManager.resolveActor(nodeCT);
        if rActor ~= rSource then
            for _, sTag in pairs(aTags) do
                tMatch = RulesetEffectManager.getEffectsByType(rActor, sTag, nil, rSource);
                for _, tEffect in pairs(tMatch) do
                    local sLabel = EffectManagerBCE.getLabelShort(tEffect.sEffectNode)
                    BCEManager.chat(sTag .. '  : ');
                    if tEffect.type == 'SDMGOS' then
                        EffectManagerDnDBCE.applyOngoingDamage(rSource, rActor, tEffect, false, sLabel);
                    elseif tEffect.type == 'SREGENS' then
                        EffectManagerDnDBCE.applyOngoingRegen(rSource, rActor, tEffect, false);
                    elseif tEffect.type == 'STREGENS' then
                        EffectManagerDnDBCE.applyOngoingRegen(rSource, rActor, tEffect, true);
                    end
                end
            end
        end
    end
    return false;
end

function processEffectTurnEndDND(rSource)
    BCEManager.chat('processEffectTurnEndDND: ');
    local aTags = {'DMGOE', 'REGENE', 'TREGENE'}
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag);
        for _, tEffect in pairs(tMatch) do
            local sLabel = EffectManagerBCE.getLabelShort(tEffect.sEffectNode)
            BCEManager.chat(sTag .. '  : ');
            if tEffect.type == 'DMGOE' then
                EffectManagerDnDBCE.applyOngoingDamage(rSource, rSource, tEffect, false, sLabel);
            elseif tEffect.type == 'REGENE' then
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rSource, tEffect, false);
            elseif tEffect.type == 'TREGENE' then
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rSource, tEffect, true);
            end
        end
    end

    -- Tags to be processed on other nodes in the CT
    aTags = {'SDMGOE', 'SREGENE', 'STREGENE'};
    local ctEntries = CombatManager.getCombatantNodes();
    for _, nodeCT in pairs(ctEntries) do
        local rActor = ActorManager.resolveActor(nodeCT);
        if rActor ~= rSource then
            for _, sTag in pairs(aTags) do
                local tMatch = RulesetEffectManager.getEffectsByType(rActor, sTag, nil, rSource);
                for _, tEffect in pairs(tMatch) do
                    local sLabel = EffectManagerBCE.getLabelShort(tEffect.sEffectNode)
                    BCEManager.chat(sTag .. '  : ');
                    if tEffect.type == 'SDMGOE' then
                        EffectManagerDnDBCE.applyOngoingDamage(rSource, rActor, tEffect, false, sLabel);
                    elseif tEffect.type == 'SREGENE' then
                        EffectManagerDnDBCE.applyOngoingRegen(rSource, rActor, tEffect, false);
                    elseif tEffect.type == 'STREGENE' then
                        EffectManagerDnDBCE.applyOngoingRegen(rSource, rActor, tEffect, true);
                    end
                end
            end
        end
    end
    return false;
end
