--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
-- luacheck: globals ActionDamageDnDBCE
local RulesetEffectManager = nil;
local resetHealth = nil;

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

    EffectManagerBCE.processSourceTurn(rSource.sCTNode, true);
    return false;
end

function processEffectTurnEndDND(rSource)
    BCEManager.chat('processEffectTurnEndDND: ');
    local aTags = {'DMGOE', 'REGENE', 'TREGENE'};
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag);
        for _, tEffect in pairs(tMatch) do
            local sLabel = EffectManagerBCE.getLabelShort(tEffect.sEffectNode);
            BCEManager.chat(tEffect.type .. '  : ');
            if sTag == 'DMGOE' then
                EffectManagerDnDBCE.applyOngoingDamage(rSource, rSource, tEffect, false, sLabel);
            elseif sTag == 'REGENE' then
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rSource, tEffect, false);
            elseif sTag == 'TREGENE' then
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rSource, tEffect, true);
            end
        end
    end

    EffectManagerBCE.processSourceTurn(rSource.sCTNode, false);
    return false;
end

function processSDMGO(rSource, rTarget, sTag)
    BCEManager.chat('processSDMGO : ');
    local tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag);
    for _, tEffect in pairs(tMatch) do
        EffectManagerDnDBCE.applyOngoingDamage(rSource, rTarget, tEffect, false);
    end
end

function processSREGEN(rSource, rTarget, sTag)
    BCEManager.chat('processSREGEN : ');
    local tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag);
    for _, tEffect in pairs(tMatch) do
        EffectManagerDnDBCE.applyOngoingRegen(rSource, rTarget, tEffect, false);
    end
end

function processSTREGEN(rSource, rTarget, sTag)
    BCEManager.chat('processSTREGEN : ');
    local tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag);
    for _, tEffect in pairs(tMatch) do
        EffectManagerDnDBCE.applyOngoingRegen(rSource, rTarget, tEffect, true);
    end
end
