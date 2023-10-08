--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals EffectManager35EBCE EffectManagerBCE BCEManager ActionSaveDnDBCE
-- luacheck: globals onInit onClose customOnEffectAddIgnoreCheck addEffectPre35E moddedGetEffectsByType isValidCheckEffect
-- luacheck: globals moddedHasEffectCondition moddedHasEffect kelGetEffectsByType kelHasEffectCondition kelHasEffect
local bAdvancedEffects = nil;
local bOverlays = nil;
local getEffectsByType = nil;
local hasEffect = nil;
local hasEffectCondition = nil;

function onInit()
    EffectManagerBCE.setCustomPreAddEffect(addEffectPre35E)

    bAdvancedEffects = BCEManager.hasExtension('FG-PFRPG-Advanced-Effects');
    bOverlays = (BCEManager.hasExtension('Feature: Extended automation and overlays') or
                    BCEManager.hasExtension('Feature: StrainInjury plus extended automation and alternative overlays') or
                    BCEManager.hasExtension('Feature: StrainInjury plus extended automation and overlays') or
                    BCEManager.hasExtension('Feature: Extended automation and alternative overlays'));

    getEffectsByType = EffectManager35E.getEffectsByType;
    hasEffect = EffectManager35E.hasEffect;
    hasEffectCondition = EffectManager35E.hasEffectCondition;
    EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)
    if bOverlays then
        EffectManager35E.getEffectsByType = kelGetEffectsByType;
        EffectManager35E.hasEffect = kelHasEffect;
        EffectManager35E.hasEffectCondition = kelHasEffectCondition;
    else
        EffectManager35E.getEffectsByType = moddedGetEffectsByType;
        EffectManager35E.hasEffect = moddedHasEffect;
        EffectManager35E.hasEffectCondition = moddedHasEffectCondition;
    end
end

function onClose()
    EffectManager35E.getEffectsByType = getEffectsByType;
    EffectManager35E.hasEffect = hasEffect;
    EffectManager35E.hasEffectCondition = hasEffectCondition;

    EffectManagerBCE.removeCustomPreAddEffect(EffectManager35EBCE.addEffectPre35E);
end

-- This is likely where we will conflict with any other extensions
function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
    local sDuplicateMsg = nil
    local nodeEffectsList = DB.getChild(nodeCT, 'effects')
    if not nodeEffectsList then
        return sDuplicateMsg
    end
    if not rEffect.sName:match('STACK') then
        for _, nodeEffect in ipairs(DB.getChildList(nodeEffectsList)) do
            if (DB.getValue(nodeEffect, 'label', '') == rEffect.sName) and (DB.getValue(nodeEffect, 'init', 0) == rEffect.nInit) and
                (DB.getValue(nodeEffect, 'duration', 0) == rEffect.nDuration) and
                (DB.getValue(nodeEffect, 'source_name', '') == rEffect.sSource) then
                sDuplicateMsg = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), rEffect.sName,
                                              Interface.getString('effect_status_exists'))
                break
            end
        end
    end
    return sDuplicateMsg
end

-- function addEffectPre35E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
function addEffectPre35E(_, _, nodeCT, rNewEffect, _)
    BCEManager.chat('addEffectPre35E : ');
    local rActor = ActorManager.resolveActor(nodeCT);
    local rSource;
    if not rNewEffect.sSource or rNewEffect.sSource == '' then
        rSource = rActor;
    else
        local nodeSource = DB.findNode(rNewEffect.sSource);
        rSource = ActorManager.resolveActor(nodeSource);
    end
    -- Save off original so we can match the name. Rebuilding a fully parsed effect
    -- will nuke spaces after a , and thus EE extension will not match names correctly.
    -- Consequently, if the name changes at all, AURA hates it and thus it isnt the same effect
    -- Really this is just to do some string replace. We just won't do string replace for any
    -- Effect that has FROMAURA;

    if not rNewEffect.sName:upper():find('FROMAURA;') then
        rNewEffect = ActionSaveDnDBCE.moveModtoMod(rNewEffect); -- Eventually we can get rid of this. Used to replace old format with New
        rNewEffect = ActionSaveDnDBCE.replaceSaveDC(rNewEffect, rSource);

        local aOriginalComps = EffectManager.parseEffect(rNewEffect.sName);

        rNewEffect.sName = EffectManager35E.evalEffect(rSource, rNewEffect.sName);

        local aNewComps = EffectManager.parseEffect(rNewEffect.sName);
        aNewComps[1] = aOriginalComps[1];
        rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewComps);
    end

    return false
end

-- luacheck: push ignore 561
function moddedGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly) -- luacheck: ignore (cyclomatic complexity)
    local results = {}
    if not rActor then
        return results
    end
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffectType);
    -- Set up filters
    local aRangeFilter = {}
    local aOtherFilter = {}
    if aFilter then
        for _, v in pairs(aFilter) do
            if type(v) ~= 'string' then
                table.insert(aOtherFilter, v)
            elseif StringManager.contains(DataCommon.rangetypes, v) then
                table.insert(aRangeFilter, v)
            elseif not tEffectCompParams.bIgnoreOtherFilter then
                table.insert(aOtherFilter, v)
            end
        end
    end
    local aEffects;
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
    else
        aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
    end

    -- Iterate through effects
    for _, v in pairs(aEffects) do
        local nActive = DB.getValue(v, 'isactive', 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
                            (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

        -- Check effect is from used weapon.
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or (bAdvancedEffects and
            ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or AdvancedEffects.isValidCheckEffect(rActor, v))) then
            -- Check targeting
            local bTargeted = EffectManager.isTargetedEffect(v)
            if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
                local sLabel = DB.getValue(v, 'label', '')
                local aEffectComps = EffectManager.parseEffect(sLabel)

                -- Look for type/subtype match
                local nMatch = 0
                for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManager35E.parseEffectComp(sEffectComp)
                    -- Handle conditionals
                    if rEffectComp.type == 'IF' then
                        if not EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder) then
                            break
                        end
                    elseif rEffectComp.type == 'IFT' then
                        if not rFilterActor then
                            break
                        end
                        if not EffectManager35E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
                            break
                        end
                        bTargeted = true

                        -- Compare other attributes
                    else
                        -- Strip energy/bonus types for subtype comparison
                        local aEffectRangeFilter = {}
                        local aEffectOtherFilter = {}

                        local aComponents = {}
                        for _, vPhrase in ipairs(rEffectComp.remainder) do
                            local nTempIndexOR = 0
                            local aPhraseOR = {}
                            repeat
                                local nStartOR, nEndOR = vPhrase:find('%s+or%s+', nTempIndexOR)
                                if nStartOR then
                                    table.insert(aPhraseOR, vPhrase:sub(nTempIndexOR, nStartOR - nTempIndexOR))
                                    nTempIndexOR = nEndOR
                                else
                                    table.insert(aPhraseOR, vPhrase:sub(nTempIndexOR))
                                end
                            until nStartOR == nil

                            for _, vPhraseOR in ipairs(aPhraseOR) do
                                local nTempIndexAND = 0
                                repeat
                                    local nStartAND, nEndAND = vPhraseOR:find('%s+and%s+', nTempIndexAND)
                                    if nStartAND then
                                        local sInsert =
                                            StringManager.trim(vPhraseOR:sub(nTempIndexAND, nStartAND - nTempIndexAND))
                                        table.insert(aComponents, sInsert)
                                        nTempIndexAND = nEndAND
                                    else
                                        local sInsert = StringManager.trim(vPhraseOR:sub(nTempIndexAND))
                                        table.insert(aComponents, sInsert)
                                    end
                                until nStartAND == nil
                            end
                        end
                        local j = 1
                        while aComponents[j] do
                            if StringManager.contains(DataCommon.dmgtypes, aComponents[j]) or
                                StringManager.contains(DataCommon.bonustypes, aComponents[j]) or aComponents[j] == 'all' then -- luacheck: ignore
                                -- Skip
                            elseif StringManager.contains(DataCommon.rangetypes, aComponents[j]) then
                                table.insert(aEffectRangeFilter, aComponents[j])
                            elseif rEffectComp.type ~= '' and not tEffectCompParams.bIgnoreOtherFilter then
                                table.insert(aEffectOtherFilter, aComponents[j])
                            end

                            j = j + 1
                        end

                        -- Check for match
                        local comp_match = false
                        if rEffectComp.type == sEffectType or rEffectComp.original == sEffectType then
                            -- Check effect targeting
                            if bTargetedOnly and not bTargeted then
                                comp_match = false
                            else
                                BCEManager.chat('Match:', rEffectComp)
                                comp_match = true
                            end

                            -- Check filters
                            if #aEffectRangeFilter > 0 then
                                local bRangeMatch = false
                                for _, v2 in pairs(aRangeFilter) do
                                    if StringManager.contains(aEffectRangeFilter, v2) then
                                        bRangeMatch = true
                                        break
                                    end
                                end
                                if not bRangeMatch then
                                    comp_match = false
                                end
                            end
                            if #aEffectOtherFilter > 0 then
                                BCEManager.chat('Other Filter:', aEffectOtherFilter)
                                local bOtherMatch = false
                                for _, v2 in pairs(aOtherFilter) do
                                    if type(v2) == 'table' then
                                        local bOtherTableMatch = true
                                        for _, v3 in pairs(v2) do
                                            if not StringManager.contains(aEffectOtherFilter, v3) then
                                                bOtherTableMatch = false
                                                break
                                            end
                                        end
                                        if bOtherTableMatch then
                                            bOtherMatch = true
                                            break
                                        end
                                    elseif StringManager.contains(aEffectOtherFilter, v2) then
                                        bOtherMatch = true
                                        break
                                    end
                                end
                                if not bOtherMatch then
                                    comp_match = false
                                end
                            end
                        end

                        -- Match!
                        if comp_match then
                            rEffectComp.sEffectNode = DB.getPath(v);
                            nMatch = kEffectComp
                            if nActive == 1 or bActive then
                                table.insert(results, rEffectComp)
                            end
                        end
                    end
                end -- END EFFECT COMPONENT LOOP

                -- Remove one shot effects
                if nMatch > 0 then
                    if nActive == 2 then
                        DB.setValue(v, 'isactive', 'number', 1)
                    else
                        local sApply = DB.getValue(v, 'apply', '')
                        if sApply == 'action' then
                            EffectManager.notifyExpire(v, 0)
                        elseif sApply == 'roll' then
                            EffectManager.notifyExpire(v, 0, true)
                        elseif sApply == 'single' or tEffectCompParams.bOneShot then
                            EffectManager.notifyExpire(v, nMatch, true)
                        elseif not tEffectCompParams.bNoDUSE and sApply == 'duse' then
                            BCEManager.modifyEffect(DB.getPath(v), 'Deactivate');
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP

    return results
end
-- luacheck: pop

---	This function returns false if the effect is tied to an item and the item is not being used.
function isValidCheckEffect(rActor, nodeEffect)
    if DB.getValue(nodeEffect, 'isactive', 0) ~= 0 then
        local bActionItemUsed, bActionOnly = false, false
        local sItemPath = ''

        local sSource = DB.getValue(nodeEffect, 'source_name', '')
        -- if source is a valid node and we can find "actiononly"
        -- setting then we set it.
        local node = DB.findNode(sSource)
        if node then
            local nodeItem = DB.getChild(node, '...')
            if nodeItem then
                sItemPath = DB.getPath(nodeItem)
                bActionOnly = (DB.getValue(node, 'actiononly', 0) ~= 0)
            end
        end

        if sItemPath and sItemPath ~= '' then
            -- if there is a nodeWeapon do some sanity checking
            if rActor.nodeItem then
                -- here is where we get the node path of the item, not the
                -- effectslist entry
                if bActionOnly and (sItemPath == rActor.nodeItem) then
                    bActionItemUsed = true
                end
            end

            -- if there is a nodeAmmo do some sanity checking
            if AmmunitionManager and rActor.nodeAmmo then
                -- here is where we get the node path of the item, not the
                -- effectslist entry
                if bActionOnly and (sItemPath == rActor.nodeAmmo) then
                    bActionItemUsed = true
                end
            end
        end

        if bActionOnly and not bActionItemUsed then
            return false
        else
            return true
        end
    end
end

function moddedHasEffectCondition(rActor, sEffect)
    return EffectManager35E.hasEffect(rActor, sEffect, nil, false, true);
end

-- luacheck: push ignore 561
--	replace 3.5E EffectManager35E manager_effect_35E.lua hasEffect() with this
function moddedHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    if not sEffect or not rActor then
        return false
    end
    local sLowerEffect = sEffect:lower()
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffect);
    -- Iterate through each effect
    local aMatch = {}
    local aEffects;
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sLowerEffect);
    else
        aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
    end

    -- Iterate through effects
    for _, v in pairs(aEffects) do
        local nActive = DB.getValue(v, 'isactive', 0)
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
                            (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

        -- COMPATIBILITY FOR ADVANCED EFFECTS
        -- to add support for AE in other extensions, make this change
        -- original line: if nActive ~= 0 then
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or (bAdvancedEffects and
            ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or AdvancedEffects.isValidCheckEffect(rActor, v))) then
            -- END COMPATIBILITY FOR ADVANCED EFFECTS

            -- Parse each effect label
            local sLabel = DB.getValue(v, 'label', '')
            local bTargeted = EffectManager.isTargetedEffect(v)
            local aEffectComps = EffectManager.parseEffect(sLabel)

            -- Iterate through each effect component looking for a type match
            local nMatch = 0
            for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                local rEffectComp = EffectManager35E.parseEffectComp(sEffectComp)
                -- Check conditionals
                if rEffectComp.type == 'IF' then
                    if not EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder) then
                        break
                    end
                elseif rEffectComp.type == 'IFT' then
                    if not rTarget then
                        break
                    end
                    if not EffectManager35E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
                        break
                    end

                    -- Check for match
                elseif rEffectComp.original:lower() == sLowerEffect then
                    if bTargeted and not bIgnoreEffectTargets then
                        if EffectManager.isEffectTarget(v, rTarget) then
                            nMatch = kEffectComp
                        end
                    elseif not bTargetedOnly then
                        nMatch = kEffectComp
                    end
                end
            end

            -- If matched, then remove one-off effects
            if nMatch > 0 then
                if nActive == 2 then
                    DB.setValue(v, 'isactive', 'number', 1)
                else
                    table.insert(aMatch, v)
                    local sApply = DB.getValue(v, 'apply', '')
                    if sApply == 'action' then
                        EffectManager.notifyExpire(v, 0)
                    elseif sApply == 'roll' then
                        EffectManager.notifyExpire(v, 0, true)
                    elseif sApply == 'single' or tEffectCompParams.bOneShot then
                        EffectManager.notifyExpire(v, nMatch, true)
                    elseif not tEffectCompParams.bNoDUSE and sApply == 'duse' then
                        BCEManager.modifyEffect(DB.getPath(v), 'Deactivate');
                    end
                end
            end
        end
    end

    if #aMatch > 0 then
        return true
    end
    return false
end
-- luacheck: pop

-------------------KELRUGEM START----------------------

-- KEL add tags
-- luacheck: push ignore 561
function kelGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, rEffectSpell)
    if not rActor then
        return {};
    end
    local results = {};
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffectType);
    -- Set up filters
    local aRangeFilter = {};
    local aOtherFilter = {};
    if aFilter then
        for _, v in pairs(aFilter) do
            if type(v) ~= 'string' then
                table.insert(aOtherFilter, v);
            elseif StringManager.contains(DataCommon.rangetypes, v) then
                table.insert(aRangeFilter, v);
            elseif not tEffectCompParams.bIgnoreOtherFilter then
                table.insert(aOtherFilter, v)
            end
        end
    end

    -- Determine effect type targeting
    -- local bTargetSupport = StringManager.isWord(sEffectType, DataCommon.targetableeffectcomps);

    local aEffects;
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
    else
        aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
    end
    -- Iterate through effects
    for _, v in pairs(aEffects) do
        -- Check active
        local nActive = DB.getValue(v, 'isactive', 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
                            (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

        -- COMPATIBILITY FOR ADVANCED EFFECTS
        -- to add support for AE in other extensions, make this change
        -- Check effect is from used weapon.
        -- original line: if nActive ~= 0 then
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or (bAdvancedEffects and
            ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or AdvancedEffects.isValidCheckEffect(rActor, v))) then
            -- END COMPATIBILITY FOR ADVANCED EFFECTS

            -- Check targeting
            local bTargeted = EffectManager.isTargetedEffect(v);
            if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
                local sLabel = DB.getValue(v, 'label', '');
                local aEffectComps = EffectManager.parseEffect(sLabel);

                -- Look for type/subtype match
                local nMatch = 0;
                for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManager35E.parseEffectComp(sEffectComp);
                    -- Handle conditionals
                    -- KEL adding TAG for SAVE
                    if rEffectComp.type == 'IF' then
                        if not EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder, rFilterActor, false,
                                                                 rEffectSpell) then
                            break
                        end
                    elseif rEffectComp.type == 'NIF' then
                        if EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder, rFilterActor, false, rEffectSpell) then
                            break
                        end
                    elseif rEffectComp.type == 'IFTAG' then
                        if not rEffectSpell then
                            break
                        elseif not EffectManager35E.checkTagConditional(rEffectComp.remainder, rEffectSpell) then
                            break
                        end
                    elseif rEffectComp.type == 'NIFTAG' then
                        if EffectManager35E.checkTagConditional(rEffectComp.remainder, rEffectSpell) then
                            break
                        end
                    elseif rEffectComp.type == 'IFT' then
                        if not rFilterActor then
                            break
                        end
                        if not EffectManager35E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor, false,
                                                                 rEffectSpell) then
                            break
                        end
                        bTargeted = true;
                    elseif rEffectComp.type == 'NIFT' then
                        if rActor.aTargets and not rFilterActor then
                            -- if ( #rActor.aTargets[1] > 0 ) and not rFilterActor then
                            break
                            -- end
                        end
                        if EffectManager35E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor, false, rEffectSpell) then
                            break
                        end
                        if rFilterActor then
                            bTargeted = true;
                        end

                        -- Compare other attributes
                    else
                        -- Strip energy/bonus types for subtype comparison
                        local aEffectRangeFilter = {};
                        local aEffectOtherFilter = {};

                        local aComponents = {};
                        for _, vPhrase in ipairs(rEffectComp.remainder) do
                            local nTempIndexOR = 0;
                            local aPhraseOR = {};
                            repeat
                                local nStartOR, nEndOR = vPhrase:find('%s+or%s+', nTempIndexOR);
                                if nStartOR then
                                    table.insert(aPhraseOR, vPhrase:sub(nTempIndexOR, nStartOR - nTempIndexOR));
                                    nTempIndexOR = nEndOR;
                                else
                                    table.insert(aPhraseOR, vPhrase:sub(nTempIndexOR));
                                end
                            until nStartOR == nil;

                            for _, vPhraseOR in ipairs(aPhraseOR) do
                                local nTempIndexAND = 0;
                                repeat
                                    local nStartAND, nEndAND = vPhraseOR:find('%s+and%s+', nTempIndexAND);
                                    if nStartAND then
                                        local sInsert =
                                            StringManager.trim(vPhraseOR:sub(nTempIndexAND, nStartAND - nTempIndexAND));
                                        table.insert(aComponents, sInsert);
                                        nTempIndexAND = nEndAND;
                                    else
                                        local sInsert = StringManager.trim(vPhraseOR:sub(nTempIndexAND));
                                        table.insert(aComponents, sInsert);
                                    end
                                until nStartAND == nil;
                            end
                        end
                        local j = 1;
                        while aComponents[j] do
                            if StringManager.contains(DataCommon.dmgtypes, aComponents[j]) or
                                StringManager.contains(DataCommon.bonustypes, aComponents[j]) or aComponents[j] == 'all' then
                                j = j;
                                -- Skip
                            elseif StringManager.contains(DataCommon.rangetypes, aComponents[j]) then
                                table.insert(aEffectRangeFilter, aComponents[j]);
                            elseif rEffectComp.type ~= '' and not tEffectCompParams.bIgnoreOtherFilter then
                                table.insert(aEffectOtherFilter, aComponents[j])
                            end

                            j = j + 1;
                        end

                        -- Check for match
                        local comp_match = false;
                        if rEffectComp.type == sEffectType or rEffectComp.original == sEffectType then

                            -- Check effect targeting
                            if bTargetedOnly and not bTargeted then
                                comp_match = false;
                            else
                                comp_match = true;
                            end

                            -- Check filters
                            if #aEffectRangeFilter > 0 then
                                local bRangeMatch = false;
                                for _, v2 in pairs(aRangeFilter) do
                                    if StringManager.contains(aEffectRangeFilter, v2) then
                                        bRangeMatch = true;
                                        break
                                    end
                                end
                                if not bRangeMatch then
                                    comp_match = false;
                                end
                            end
                            if #aEffectOtherFilter > 0 then
                                local bOtherMatch = false;
                                for _, v2 in pairs(aOtherFilter) do
                                    if type(v2) == 'table' then
                                        local bOtherTableMatch = true;
                                        for _, v3 in pairs(v2) do
                                            if not StringManager.contains(aEffectOtherFilter, v3) then
                                                bOtherTableMatch = false;
                                                break
                                            end
                                        end
                                        if bOtherTableMatch then
                                            bOtherMatch = true;
                                            break
                                        end
                                    elseif StringManager.contains(aEffectOtherFilter, v2) then
                                        bOtherMatch = true;
                                        break
                                    end
                                end
                                if not bOtherMatch then
                                    comp_match = false;
                                end
                            end
                        end

                        -- Match!
                        if comp_match then
                            rEffectComp.sEffectNode = DB.getPath(v);
                            nMatch = kEffectComp;
                            if nActive == 1 or bActive then
                                table.insert(results, rEffectComp);
                            end
                        end
                    end
                end -- END EFFECT COMPONENT LOOP

                -- Remove one shot effects
                if nMatch > 0 then
                    if nActive == 2 then
                        DB.setValue(v, 'isactive', 'number', 1);
                    else
                        local sApply = DB.getValue(v, 'apply', '');
                        if sApply == 'action' then
                            EffectManager.notifyExpire(v, 0);
                        elseif sApply == 'roll' then
                            EffectManager.notifyExpire(v, 0, true);
                        elseif sApply == 'single' or tEffectCompParams.bOneShot then
                            EffectManager.notifyExpire(v, nMatch, true);
                        elseif not tEffectCompParams.bNoDUSE and sApply == 'duse' then
                            BCEManager.modifyEffect(DB.getPath(v), 'Deactivate');
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP

    return results;
end
-- luacheck: pop

-- KEL Adding tags and IFTAG to
function kelHasEffectCondition(rActor, sEffect, rEffectSpell)
    return kelHasEffect(rActor, sEffect, nil, false, true, rEffectSpell);
end
-- luacheck: push ignore 561
-- KEL add counter to hasEffect needed for dis/adv
function kelHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets, rEffectSpell)
    if not sEffect or not rActor then
        return false, 0;
    end
    local sLowerEffect = sEffect:lower();
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffect);

    -- Iterate through each effect
    local aMatch = {};
    local aEffects;
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sLowerEffect);
    else
        aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
    end
    for _, v in pairs(aEffects) do
        local nActive = DB.getValue(v, 'isactive', 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
                            (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
        -- COMPATIBILITY FOR ADVANCED EFFECTS
        -- to add support for AE in other extensions, make this change
        -- original line: if nActive ~= 0 then
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or (bAdvancedEffects and
            ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or AdvancedEffects.isValidCheckEffect(rActor, v))) then
            -- END COMPATIBILITY FOR ADVANCED EFFECTS

            -- Parse each effect label
            local sLabel = DB.getValue(v, 'label', '');
            local bTargeted = EffectManager.isTargetedEffect(v);
            -- KEL making conditions work with IFT etc.
            local bIFT = false;
            local aEffectComps = EffectManager.parseEffect(sLabel);

            -- Iterate through each effect component looking for a type match
            local nMatch = 0;
            for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                local rEffectComp = EffectManager35E.parseEffectComp(sEffectComp);
                -- Check conditionals
                -- KEL Adding TAG for SIMMUNE
                if rEffectComp.type == 'IF' then
                    if not EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder, rTarget, false, rEffectSpell) then
                        break
                    end
                elseif rEffectComp.type == 'NIF' then
                    if EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder, rTarget, false, rEffectSpell) then
                        break
                    end
                elseif rEffectComp.type == 'IFT' then
                    if not rTarget then
                        break
                    end
                    if not EffectManager35E.checkConditional(rTarget, v, rEffectComp.remainder, rActor, false, rEffectSpell) then
                        break
                    end
                    bIFT = true;
                elseif rEffectComp.type == 'NIFT' then
                    if rActor.aTargets and not rTarget then
                        -- if ( #rActor.aTargets[1] > 0 ) and not rTarget then
                        break
                        -- end
                    end
                    if EffectManager35E.checkConditional(rTarget, v, rEffectComp.remainder, rActor, false, rEffectSpell) then
                        break
                    end
                    if rTarget then
                        bIFT = true;
                    end
                elseif rEffectComp.type == 'IFTAG' then
                    if not rEffectSpell then
                        break
                    elseif not EffectManager35E.checkTagConditional(rEffectComp.remainder, rEffectSpell) then
                        break
                    end
                elseif rEffectComp.type == 'NIFTAG' then
                    if EffectManager35E.checkTagConditional(rEffectComp.remainder, rEffectSpell) then
                        break
                    end

                    -- Check for match
                elseif rEffectComp.original:lower() == sLowerEffect then
                    if bTargeted and not bIgnoreEffectTargets then
                        if EffectManager.isEffectTarget(v, rTarget) then
                            nMatch = kEffectComp;
                        end
                    elseif bTargetedOnly and bIFT then
                        nMatch = kEffectComp;
                    elseif not bTargetedOnly then
                        nMatch = kEffectComp;
                    end
                end

            end

            -- If matched, then remove one-off effects
            if nMatch > 0 then
                if nActive == 2 then
                    DB.setValue(v, 'isactive', 'number', 1);
                else
                    table.insert(aMatch, v);
                    local sApply = DB.getValue(v, 'apply', '');
                    if sApply == 'action' then
                        EffectManager.notifyExpire(v, 0);
                    elseif sApply == 'roll' then
                        EffectManager.notifyExpire(v, 0, true);
                    elseif sApply == 'single' or tEffectCompParams.bOneShot then
                        EffectManager.notifyExpire(v, nMatch, true);
                    elseif not tEffectCompParams.bNoDUSE and sApply == 'duse' then
                        BCEManager.modifyEffect(DB.getPath(v), 'Deactivate');
                    end
                end
            end
        end
    end

    if #aMatch > 0 then
        return true, #aMatch;
    end
    return false, 0;
end
-- luacheck: pop
-------------------KELRUGEM END----------------------
