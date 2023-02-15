--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
-- luacheck: globals EffectManagerDnDBCE
local RulesetEffectManager = nil;

function onInit()
    RulesetEffectManager = BCEManager.getRulesetEffectManager();

    ActionsManager.registerResultHandler('effectbce', onEffectRollHandler)

    EffectManagerBCE.setCustomPreAddEffect(addEffectPre);
    EffectManagerBCE.setCustomPostAddEffect(addEffectPost);
end

function onClose()
end

function onTabletopInit()
    EffectManagerBCE.registerEffectCompType('REGENA', {bOneShot = true});
    EffectManagerBCE.registerEffectCompType('TREGENA', {bOneShot = true});
    EffectManagerBCE.registerEffectCompType('DMGA', {bOneShot = true});
end

-- function onEffectRollHandler(rSource, rTarget, rRoll)
function onEffectRollHandler(_, _, rRoll)
    BCEManager.chat('onEffectRollHandler DND: ');
    local nodeEffect = DB.findNode(rRoll.sNodeCT)
    local sEffect = DB.getValue(nodeEffect, 'label', '');
    if nodeEffect then
        local nResult = tonumber(ActionsManager.total(rRoll));
        local sResult = tostring(nResult);
        local sValue = rRoll.sValue;
        local sReverseValue = string.reverse(sValue);
        ---Needed to get creative with patern matching - to correctly process
        -- if the negative is to total, or do we have a negative modifier
        if sValue:match('%+%d+') then
            sValue = sValue:gsub('%+%d+', '') .. '%+%d+';
        elseif (sReverseValue:match('%d+%-') and rRoll.nMod ~= 0) then
            sReverseValue = sReverseValue:gsub('%d+%-', '', 1);
            sValue = '%-?' .. string.reverse(sReverseValue) .. '%-*%d?'
        elseif (sReverseValue:match('%d+%-') and rRoll.nMod == 0) then
            sValue = '%-*' .. sValue:gsub('%-', '');
        end
        sEffect = sEffect:gsub(sValue, sResult);
        DB.setValue(nodeEffect, 'label', 'string', sEffect);
    end
end

-- function addEffectPre(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
function addEffectPre(_, _, nodeCT, rNewEffect, _)
    BCEManager.chat('addEffectPre DND: ');
    local rActor = ActorManager.resolveActor(nodeCT)
    BCEDnDManager.replaceAbilityScores(rNewEffect, rActor);
    return false;
end

function addEffectPost(nodeActor, nodeEffect)
    BCEManager.chat('addEffectPost DND: ');
    if not nodeEffect or type(nodeEffect) ~= 'databasenode' then
        return false;
    end
    local rEffect = EffectManager.getEffect(nodeEffect);
    local rTarget = ActorManager.resolveActor(nodeActor);
    local rSource;
    DiceManagerDnDBCE.isDie(rTarget, rEffect, nodeEffect.getPath());
    if rEffect.sSource == '' then
        rSource = rTarget;
    else
        rSource = ActorManager.resolveActor(rEffect.sSource);
    end

    local aTags = {'REGENA', 'TREGENA', 'DMGA'};
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag, nil, rSource);
        for _, tEffect in pairs(tMatch) do
            if sTag =='REGENA' then
                BCEManager.chat('REGENA: ');
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rTarget, tEffect);
            elseif sTag =='TREGENA' then
                BCEManager.chat('TREGENA: ');
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rTarget, tEffect, true);
            elseif sTag =='DMGA' then
                BCEManager.chat('DMGA: ');
                EffectManagerDnDBCE.applyOngoingDamage(rSource, rTarget, tEffect);
            end
        end
    end
    return false;
end

function applyOngoingDamage(rSource, rTarget, rEffectComp, bHalf, sLabel)
    BCEManager.chat('applyOngoingDamage DND: ');
    local rAction = {};
    local aClause = {};
    rAction.clauses = {};

    aClause.dice = rEffectComp.dice;
    aClause.modifier = rEffectComp.mod;
    aClause.dmgtype = string.lower(table.concat(rEffectComp.remainder, ','));
    table.insert(rAction.clauses, aClause);
    if not sLabel then
        sLabel = 'Ongoing Effect';
    end
    rAction.label = sLabel;

    local rRoll = ActionDamage.getRoll(rTarget, rAction);
    if bHalf then
        rRoll.sDesc = rRoll.sDesc .. ' [HALF]';
    end
    ActionsManager.actionDirect(rSource, 'damage', {rRoll}, {{rTarget}});
end

function applyOngoingRegen(rSource, rTarget, rEffectComp, bTemp)
    BCEManager.chat('applyOngoingRegen DND: ');
    local rAction = {};
    local aClause = {};
    rAction.clauses = {};

    aClause.dice = rEffectComp.dice;
    aClause.modifier = rEffectComp.mod;
    table.insert(rAction.clauses, aClause)
    if bTemp == true then
        rAction.label = 'Ongoing Temporary Hitpoints';
        rAction.subtype = 'temp';
    else
        rAction.label = 'Ongoing Regeneration';
    end

    local rRoll = ActionHeal.getRoll(rTarget, rAction);
    ActionsManager.actionDirect(rSource, 'heal', {rRoll}, {{rTarget}});
end
