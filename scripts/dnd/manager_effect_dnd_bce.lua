--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals EffectManagerDnDBCE BCEManager BCEDnDManager EffectManagerBCE DiceManagerDnDBCE
-- luacheck: globals onInit onClose onTabletopInit onEffectRollHandler addEffectPre addEffectPost
-- luacheck: globals applyOngoingDamage applyOngoingRegen customOnEffectTextDecode customOnEffectTextEncode
-- luacheck: globals splitTagByComma ActionSaveDnDBCE
local RulesetEffectManager = nil;

local onEffectTextDecode = nil;
local onEffectTextEncode = nil;

function onInit()
    RulesetEffectManager = BCEManager.getRulesetEffectManager();

    ActionsManager.registerResultHandler('effectbce', onEffectRollHandler)

    EffectManagerBCE.setCustomPreAddEffect(addEffectPre);
    EffectManagerBCE.setCustomPostAddEffect(addEffectPost);

    onEffectTextDecode = RulesetEffectManager.onEffectTextDecode;
    onEffectTextEncode = RulesetEffectManager.onEffectTextEncode;

    RulesetEffectManager.onEffectTextDecode = customOnEffectTextDecode;
    RulesetEffectManager.onEffectTextEncode = customOnEffectTextEncode;
    EffectManager.setCustomOnEffectTextEncode(customOnEffectTextEncode);
    EffectManager.setCustomOnEffectTextDecode(customOnEffectTextDecode);
end

function onClose()
    RulesetEffectManager.onEffectTextDecode = onEffectTextDecode;
    RulesetEffectManager.onEffectTextEncode = onEffectTextEncode;
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
    DiceManagerDnDBCE.isDie(rTarget, rEffect, DB.getPath(nodeEffect));
    if rEffect.sSource == '' then
        rSource = rTarget;
    else
        rSource = ActorManager.resolveActor(rEffect.sSource);
    end
    local aTags = {'REGENA', 'TREGENA', 'DMGA', 'SAVEA'};
    for _, sTag in pairs(aTags) do
        local tMatch;
        if sTag == 'SAVEA' then
            tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag, ActionSaveDnDBCE.aSaveFilter);
        else
            tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag, nil, rSource);
        end
        for _, tEffect in pairs(tMatch) do
            if sTag == 'REGENA' then
                BCEManager.chat('REGENA: ');
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rTarget, tEffect);
            elseif sTag == 'TREGENA' then
                BCEManager.chat('TREGENA: ');
                EffectManagerDnDBCE.applyOngoingRegen(rSource, rTarget, tEffect, true);
            elseif sTag == 'DMGA' then
                BCEManager.chat('DMGA: ');
                EffectManagerDnDBCE.applyOngoingDamage(rSource, rTarget, tEffect);
            elseif sTag == 'SAVEA' then
                for _, tEffect in pairs(tMatch) do
                    BCEManager.chat('SAVEA : ', tEffect);
                    ActionSaveDnDBCE.saveEffect(rTarget, tEffect);
                end
            end
        end
    end
    return false;
end

function applyOngoingDamage(rSource, rTarget, rEffectComp, bHalf)
    BCEManager.chat('applyOngoingDamage DND: ');
    local rAction = {};
    local aClause = {};
    rAction.clauses = {};

    aClause.dice = rEffectComp.dice;
    aClause.modifier = rEffectComp.mod;
    aClause.dmgtype = string.lower(table.concat(rEffectComp.remainder, ','));
    table.insert(rAction.clauses, aClause);
    if rEffectComp.sEffectNode then
        rAction.label = EffectManagerBCE.getLabelShort(rEffectComp.sEffectNode);
    else
        rAction.label = 'Ongoing Damage';
    end

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
    table.insert(rAction.clauses, aClause);

    rAction.label = EffectManagerBCE.getLabelShort(rEffectComp.sEffectNode);
    if bTemp == true then
        rAction.subtype = 'temp';
    end

    local rRoll = ActionHeal.getRoll(rTarget, rAction);
    ActionsManager.actionDirect(rSource, 'heal', {rRoll}, {{rTarget}});
end

function customOnEffectTextDecode(sEffect, rEffect)
    BCEManager.chat('customOnEffectTextDecode : ');
    local sReturn = onEffectTextDecode(sEffect, rEffect);
    if sReturn ~= '' and sReturn:match('%[DUSE%]') then
        sReturn = sReturn:gsub('%[DUSE%]', '');
        rEffect.sApply = 'duse';
    end
    if sReturn ~= '' and sReturn:match('%[ATS%]') then
        sReturn = sReturn:gsub('%[ATS%]', '');
        rEffect.sChangeState = 'ats';
    elseif sReturn:match('%[DTS%]') then
        sReturn = sReturn:gsub('%[DTS%]', '');
        rEffect.sChangeState = 'dts';
    elseif sReturn:match('%[RTS%]') then
        sReturn = sReturn:gsub('%[RTS%]', '');
        rEffect.sChangeState = 'rts';
    elseif sReturn:match('%[RE%]') then
        sReturn = sReturn:gsub('%[RE%]', '');
        rEffect.sChangeState = 're';
    elseif sReturn:match('%[SAS%]') then
        sReturn = sReturn:gsub('%[SAS%]', '');
        rEffect.sChangeState = 'sas';
    elseif sReturn:match('%[SDS%]') then
        sReturn = sReturn:gsub('%[SDS%]', '');
        rEffect.sChangeState = 'sds';
    elseif sReturn:match('%[SRS%]') then
        sReturn = sReturn:gsub('%[SRS%]', '');
        rEffect.sChangeState = 'srs';
    elseif sReturn:match('%[SAE%]') then
        sReturn = sReturn:gsub('%[SAE%]', '');
        rEffect.sChangeState = 'sae';
    elseif sReturn:match('%[SDE%]') then
        sReturn = sReturn:gsub('%[SDE%]', '');
        rEffect.sChangeState = 'sde';
    elseif sReturn:match('%[SRE%]') then
        sReturn = sReturn:gsub('%[SRE%]', '');
        rEffect.sChangeState = 'sre';
    elseif sReturn:match('%[AS%]') then
        sReturn = sReturn:gsub('%[AS%]', '');
        rEffect.sChangeState = 'as';
    elseif sReturn:match('%[DS%]') then
        sReturn = sReturn:gsub('%[DS%]', '');
        rEffect.sChangeState = 'ds';
    elseif sReturn:match('%[RS%]') then
        sReturn = sReturn:gsub('%[RS%]', '');
        rEffect.sChangeState = 'rs';
    elseif sReturn:match('%[AE%]') then
        sReturn = sReturn:gsub('%[AE%]', '');
        rEffect.sChangeState = 'ae';
    elseif sReturn:match('%[DE%]') then
        sReturn = sReturn:gsub('%[DE%]', '');
        rEffect.sChangeState = 'de';

    end
    return sReturn;
end

function customOnEffectTextEncode(rEffect)
    BCEManager.chat('customOnEffectTextEncode : ', rEffect);
    local sReturn = onEffectTextEncode(rEffect);
    if rEffect.sChangeState and rEffect.sChangeState ~= '' then
        sReturn = sReturn .. string.format(' [%s]', rEffect.sChangeState:upper());
    end
    return sReturn;
end

function splitTagByComma(sEffect)
    local sRemainder = sEffect:match("^%w+%s*:(.+)");
    return StringManager.split(sRemainder, ",", true);
end
