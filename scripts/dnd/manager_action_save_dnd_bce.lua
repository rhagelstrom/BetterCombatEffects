--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals ActionSaveDnDBCE BCEManager EffectManagerBCE EffectManagerDnDBCE CombatManagerBCE ActionDamageDnDBCE
-- luacheck: globals onInit onTabletopInit onClose processEffectTurnStartSave processEffectTurnEndSave onSaveRollHandler
-- luacheck: globals saveAddEffect saveEffect saveRemoveDisable onDamage addEffectPost getDCEffectMod moveModtoMod replaceSaveDC
local onSave = nil;
local RulesetEffectManager = nil;
local RulesetActorManager = nil;

local aSaveFilter = {}

function onInit()
    RulesetEffectManager = BCEManager.getRulesetEffectManager();
    RulesetActorManager = BCEManager.getRulesetActorManager();

    ActionsManager.registerResultHandler('save', onSaveRollHandler);
    EffectManagerBCE.setCustomPostAddEffect(addEffectPost);

    onSave = ActionSave.onSave;
    ActionSave.onSave = onSaveRollHandler;

    CombatManagerBCE.setCustomProcessTurnStart(processEffectTurnStartSave);
    CombatManagerBCE.setCustomProcessTurnEnd(processEffectTurnEndSave);
    ActionDamageDnDBCE.setProcessEffectOnDamage(onDamage);

    EffectManagerBCE.registerEffectCompType('SAVEADD', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('SAVEADDP', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('SAVEA', {bOneShot = true, bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('SAVES', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('SAVEE', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('SAVEONDMG', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('SAVEDMG', {bIgnoreOtherFilter = true, bIgnoreDisabledCheck = true});
end

function onTabletopInit()
    if User.getRulesetName() == '5E' then
        aSaveFilter = DataCommon.ability_ltos;
    else
        aSaveFilter = DataCommon.save_ltos;
        for i, v in pairs(DataCommon.save_stol) do
            aSaveFilter[i] = v;
        end
    end
end

function onClose()
    ActionsManager.unregisterResultHandler('save');
    ActionSave.onSave = onSave;

    CombatManagerBCE.removeCustomProcessTurnStart(processEffectTurnStartSave);
    CombatManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEndSave);
end

function processEffectTurnStartSave(rSource)
    BCEManager.chat('processEffectTurnStartSave : ');
    local tMatch;
    tMatch = RulesetEffectManager.getEffectsByType(rSource, 'SAVES', aSaveFilter);
    for _, tEffect in pairs(tMatch) do
        BCEManager.chat('SAVES : ', tEffect);
        ActionSaveDnDBCE.saveEffect(rSource, tEffect);
    end
    return false;
end

function processEffectTurnEndSave(rSource)
    BCEManager.chat('processEffectTurnEndSave : ');
    local tMatch;

    tMatch = RulesetEffectManager.getEffectsByType(rSource, 'SAVEE', aSaveFilter);
    for _, tEffect in pairs(tMatch) do
        BCEManager.chat('SAVEE : ', tEffect);
        ActionSaveDnDBCE.saveEffect(rSource, tEffect);
    end
    return false;
end

-- rSource is the source of the actor making the roll, hence it is the target of whatever is causing the same
-- rTarget is null for some reason.
function onSaveRollHandler(rSource, rTarget, rRoll)
    BCEManager.chat('onSaveRollHandler : ');
    if not rRoll.sSaveDesc or not rRoll.sSaveDesc:match('%[BCE]') then
        return onSave(rSource, rTarget, rRoll);
    end
    -- Get the original save effect path so we can correlate with damage
    local sPath = rRoll.sSaveDesc:match('%[PATH%][%a%d%.%-]*%[!PATH%]');
    rRoll.sSaveDesc:gsub('%[PATH%][%a%d%.%-]*%[!PATH%]', '');
    if not sPath then
        return onSave(rSource, rTarget, rRoll);
    end
    sPath = sPath:gsub('%[!*PATH%]', '');
    local nodeEffect = DB.findNode(sPath);
    local nodeTarget = DB.findNode(rRoll.sSource);
    local nodeSource = ActorManager.getCTNode(rSource);
    rTarget = ActorManager.resolveActor(nodeTarget);
    -- something is wrong. Likely an extension messing with things
    if not rTarget or not rSource or not nodeTarget or not nodeSource then
        return onSave(rSource, rTarget, rRoll);
    end

    local tMatch;
    local aTags;

    onSave(rSource, rTarget, rRoll);

    local nResult = ActionsManager.total(rRoll);
    local bAct = false;
    -- Have the flip tag
    if rRoll.sSaveDesc:match('%[FLIP]') then
        if nResult < tonumber(rRoll.nTarget) then
            bAct = true;
        end
    else
        if nResult >= tonumber(rRoll.nTarget) then
            bAct = true;
        end
    end

    -- Need the original effect because we only want to do things that are in the same effect
    -- if we just pull all the tags on the Actor then we can't have multiple saves doing
    -- multiple different things. We have to be careful about the one shot options expireing
    -- our effect hence the check for nil
    if bAct and nodeEffect then
        aTags = {'SAVEADDP'};
        if rRoll.sSaveDesc:match('%[HALF ON SAVE]') then
            table.insert(aTags, 'SAVEDMG');
        end
        for _, sTag in pairs(aTags) do

            tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag, aSaveFilter, rTarget);
            for _, tEffect in pairs(tMatch) do
                if tEffect.sEffectNode == sPath then
                    if sTag == 'SAVEADDP' then
                        BCEManager.chat('SAVEADDP : ', tEffect);
                        ActionSaveDnDBCE.saveAddEffect(nodeSource, nodeTarget, tEffect);
                        ActionSaveDnDBCE.saveRemoveDisable(tEffect.sEffectNode, tEffect, true);

                    elseif sTag == 'SAVEDMG' then
                        BCEManager.chat('SAVEDMG : ', tEffect);
                        EffectManagerDnDBCE.applyOngoingDamage(rTarget, rSource, tEffect, true);
                        ActionSaveDnDBCE.saveRemoveDisable(tEffect.sEffectNode, tEffect, true);
                    end
                end
            end
        end
    elseif nodeEffect then
        aTags = {'SAVEADD', 'SAVEDMG'};
        for _, sTag in pairs(aTags) do
            tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag, aSaveFilter, rTarget);
            for _, tEffect in pairs(tMatch) do
                if tEffect.sEffectNode == sPath then
                    if sTag == 'SAVEADD' then
                        BCEManager.chat('SAVEADD : ', tEffect);
                        ActionSaveDnDBCE.saveAddEffect(nodeSource, nodeTarget, tEffect);
                        ActionSaveDnDBCE.saveRemoveDisable(tEffect.sEffectNode, tEffect);
                    elseif sTag == 'SAVEDMG' then
                        BCEManager.chat('SAVEDMG : ', tEffect);
                        EffectManagerDnDBCE.applyOngoingDamage(rTarget, rSource, tEffect, false);
                        ActionSaveDnDBCE.saveRemoveDisable(tEffect.sEffectNode, tEffect);
                    end
                end
            end
        end
    end
    ActionSaveDnDBCE.saveRemoveDisable(sPath, nil, (not bAct), rRoll);
end

function saveAddEffect(nodeSource, nodeTarget, rEffectComp)
    BCEManager.chat('saveAddEffect : ');
    BCEManager.notifyAddEffect(nodeSource, nodeTarget, rEffectComp.remainder[1]);
end

function saveEffect(rTarget, rEffectComp)
    BCEManager.chat('saveEffect : ');

    local rSource;
    local nodeEffect = DB.findNode(rEffectComp.sEffectNode);
    local rEffect = EffectManager.getEffect(nodeEffect);
    if (not rEffect.sSource or rEffect.sSource == '') then
        rSource = rTarget;
    else
        rSource = ActorManager.resolveActor(rEffect.sSource);
    end

    local aParsedRemainder = StringManager.parseWords(rEffectComp.remainder[1]);
    local sAbility;
    if User.getRulesetName() == '5E' then
        sAbility = DataCommon.ability_stol[aParsedRemainder[1]:upper()];
    else
        sAbility = DataCommon.save_stol[aParsedRemainder[1]:upper()];
    end
    if sAbility and sAbility ~= '' then
        local bSecret = false;
        local rAction = {};
        rAction.savemod = tonumber(aParsedRemainder[2]);

        if not rAction.savemod then
            rAction.savemod = rEffectComp.mod;
        end
        rAction.label = rEffectComp.remainder[1];
        if rEffectComp.original:match('%(M%)') then
            rAction.magic = true;
        end
        if rEffectComp.original:match('%(H%)') then
            rAction.onmissdamage = 'half';
        end
        local rSaveVsRoll;
        if User.getRulesetName() == '5E' then
            rSaveVsRoll = ActionPower.getSaveVsRoll(rSource, rAction);
        else
            rSaveVsRoll = ActionSpell.getSaveVsRoll(rSource, rAction);
        end

        rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [' .. StringManager.capitalize(sAbility) .. ' DC ' .. rSaveVsRoll.nMod .. ']';
        if DB.getValue(nodeEffect, 'isgmonly', 0) == 1 then
            bSecret = true;
        end

        if rEffectComp.original:match('%(D%)') then
            rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [DISABLE ON SAVE]';
        end
        if rEffectComp.original:match('%(R%)') then
            rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [REMOVE ON SAVE]';
        end
        if rEffectComp.original:match('%(RA%)') then
            rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [REMOVE ANY SAVE]';
        end
        if rEffectComp.original:match('%(F%)') then
            rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [FLIP]';
        end
        local aSaveFilterAbility = {};
        table.insert(aSaveFilterAbility, sAbility:lower());

        -- if we don't have a filter, modSave will figure out the other adv/dis later
        if #(RulesetEffectManager.getEffectsByType(rTarget, 'ADVSAV', aSaveFilterAbility, rSource)) > 0 then
            rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [ADV]';
        end
        if #(RulesetEffectManager.getEffectsByType(rTarget, 'DISSAV', aSaveFilterAbility, rSource)) > 0 then
            rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [DIS]';
        end
        rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. ' [PATH]' .. rEffectComp.sEffectNode .. '[!PATH] [BCE]';
        ActionSave.performVsRoll(nil, rTarget, sAbility, rSaveVsRoll.nMod, bSecret, rSource, false, rSaveVsRoll.sDesc);
    end
end

function saveRemoveDisable(sNodeEffect, rEffectComp, bRAOnly, rRoll)
    BCEManager.chat('saveRemoveDisable : ', rRoll);
    if not bRAOnly and ((rEffectComp and rEffectComp.original:match('%(R%)')) or (rRoll and rRoll.sSaveDesc:match('%[REMOVE ON SAVE%]'))) then
        BCEManager.modifyEffect(sNodeEffect, 'Remove');
    elseif not bRAOnly and ((rEffectComp and rEffectComp.original:match('%(D%)')) or (rRoll and rRoll.sSaveDesc:match('%[DISABLE ON SAVE%]'))) then
        BCEManager.modifyEffect(sNodeEffect, 'Deactivate');
    elseif (rEffectComp and (rEffectComp.original:match('%(RA%)')) or (rRoll and rRoll.sSaveDesc:match('%[REMOVE ANY SAVE%]'))) then
        BCEManager.modifyEffect(sNodeEffect, 'Remove');
    end
end

-- function onDamage(rSource, rTarget, rRoll)
function onDamage(rSource, rTarget, _)
    BCEManager.chat('onDamage : ');
    local tMatch;

    tMatch = RulesetEffectManager.getEffectsByType(rTarget, 'SAVEONDMG', aSaveFilter, rSource);
    for _, tEffect in pairs(tMatch) do
        BCEManager.chat('SAVEONDMG : ', tEffect);
        ActionSaveDnDBCE.saveEffect(rTarget, tEffect);
    end
    return false;
end

-- function addEffectPost(nodeActor, nodeEffect)
function addEffectPost(nodeActor, _)
    BCEManager.chat('addEffectPost : ');
    local rTarget = ActorManager.resolveActor(nodeActor);
    local tMatch;

    tMatch = RulesetEffectManager.getEffectsByType(rTarget, 'SAVEA', aSaveFilter);
    for _, tEffect in pairs(tMatch) do
        BCEManager.chat('SAVEA : ', tEffect);
        ActionSaveDnDBCE.saveEffect(rTarget, tEffect);
    end
    return false;
end

function getDCEffectMod(rActor)
    BCEManager.chat('getDCEffectMod : ');
    local nDC = 0;
    local tMatch = RulesetEffectManager.getEffectsByType(rActor, 'DC');
    for _, tEffect in pairs(tMatch) do
        if nDC < tEffect.mod then
            nDC = tEffect.mod;
        end
    end
    return nDC;
end

-- Legacy support
function moveModtoMod(rEffect)
    BCEManager.chat('moveModtoMod : ');
    local aMatch = {};
    for _, sAbility in pairs(DataCommon.abilities) do
        table.insert(aMatch, DataCommon.ability_ltos[sAbility]:upper());
    end

    local aEffectComps = EffectManager.parseEffect(rEffect.sName);
    for i, sEffectComp in ipairs(aEffectComps) do
        local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
        if rEffectComp.type == 'SAVEE' or rEffectComp.type == 'SAVES' or rEffectComp.type == 'SAVEA' or rEffectComp.type == 'SAVEONDMG' then
            local aSplitString = StringManager.splitTokens(sEffectComp);
            if StringManager.contains(aMatch, aSplitString[2]) then
                table.insert(aSplitString, 2, aSplitString[3]);
                table.remove(aSplitString, 4);
            end
            aEffectComps[i] = table.concat(aSplitString, ' ');
        end
    end
    rEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps);
    return rEffect;
end

function replaceSaveDC(rNewEffect, rActor)
    BCEManager.chat('replaceSaveDC : ');
    if rNewEffect.sName:match('%[SDC]') and
        (rNewEffect.sName:match('SAVEE%s*:') or rNewEffect.sName:match('SAVES%s*:') or rNewEffect.sName:match('SAVEA%s*:') or
            rNewEffect.sName:match('SAVEONDMG%s*:')) then
        local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
        local nSpellcastingDC = 0;
        local bNewSpellcasting = true;
        local nDC = ActionSaveDnDBCE.getDCEffectMod(rActor);
        if sNodeType == 'pc' then
            nSpellcastingDC = 8 + RulesetActorManager.getAbilityBonus(rActor, 'prf') + nDC;
            for _, nodeFeature in ipairs(DB.getChildList(nodeActor, 'featurelist')) do
                local sFeatureName = StringManager.trim(DB.getValue(nodeFeature, 'name', ''):lower());
                if sFeatureName == 'spellcasting' or sFeatureName == 'pact magic' then
                    local sDesc = DB.getValue(nodeFeature, 'text', ''):lower();
                    local sStat = sDesc:match('(%w+) is your spellcasting ability') or '';
                    nSpellcastingDC = nSpellcastingDC + RulesetActorManager.getAbilityBonus(rActor, sStat);
                    -- savemod is the db tag in the power group to get the power modifier
                    break;
                end
            end
        elseif sNodeType == 'ct' or sNodeType == 'npc' then
            nSpellcastingDC = 8 + RulesetActorManager.getAbilityBonus(rActor, 'prf') + nDC;
            for _, nodeTrait in ipairs(DB.getChildList(nodeActor, 'traits')) do
                local sTraitName = StringManager.trim(DB.getValue(nodeTrait, 'name', ''):lower());
                if sTraitName == 'spellcasting' or string.find(sTraitName, 'innate spellcasting') then
                    local sDesc = DB.getValue(nodeTrait, 'desc', ''):lower();
                    local sStat = sDesc:match('spellcasting ability is (%w+)') or '';
                    nSpellcastingDC = nSpellcastingDC + RulesetActorManager.getAbilityBonus(rActor, sStat);
                    bNewSpellcasting = false;
                    break;
                end
            end
            if bNewSpellcasting then
                for _, nodeAction in ipairs(DB.getChildList(nodeActor, 'actions')) do
                    local sActionName = StringManager.trim(DB.getValue(nodeAction, 'name', ''):lower());
                    if sActionName == 'spellcasting' then
                        local sDesc = DB.getValue(nodeAction, 'desc', ''):lower();
                        nSpellcastingDC = nDC + (tonumber(sDesc:match('spell save dc (%d+)')) or 0);
                        break;
                    end
                end
            end
        end
        local tMatch = RulesetEffectManager.getEffectsByType(rActor, 'SDC');
        for _, tEffect in pairs(tMatch) do
            nSpellcastingDC = nSpellcastingDC + tEffect.mod;
        end
        rNewEffect.sName = rNewEffect.sName:gsub('%[SDC]', tostring(nSpellcastingDC));
    end
    return rNewEffect;
end
