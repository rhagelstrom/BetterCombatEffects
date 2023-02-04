--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local bAdvancedEffects = nil;

local getEffectsByType = nil;
local hasEffect = nil;
local hasEffectCondition = nil;

function onInit()
    EffectManagerBCE.setCustomPreAddEffect(addEffectPre5E)

    bAdvancedEffects = BCEManager.hasExtension("FG-PFRPG-Advanced-Effects");

    getEffectsByType = EffectManager35E.getEffectsByType;
    hasEffect = EffectManager35E.hasEffect;
    hasEffectCondition = EffectManager35E.hasEffectCondition;

    EffectManager35E.getEffectsByType = customGetEffectsByType;
    EffectManager35E.hasEffect = customHasEffect;
    EffectManager35E.hasEffectCondition = customHasEffectCondition;
end

function onClose()
    EffectManager35E.getEffectsByType = getEffectsByType;
    EffectManager35E.hasEffect = hasEffect;
    EffectManager35E.hasEffectCondition = hasEffectCondition;

    EffectManagerBCE.removeCustomPreAddEffect(addEffectPre35E);
end

function addEffectPre35E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    BCEManager.chat("addEffectPre35E : ");
    local rActor = ActorManager.resolveActor(nodeCT);
    local rSource;
    if not rNewEffect.sSource or rNewEffect.sSource == "" then
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

    if not rNewEffect.sName:upper():find("FROMAURA;") then
        rNewEffect = moveModtoMod(rNewEffect); -- Eventually we can get rid of this. Used to replace old format with New
        rNewEffect = replaceSaveDC(rNewEffect, rSource);

        local aOriginalComps = EffectManager.parseEffect(rNewEffect.sName);

        rNewEffect.sName = EffectManager35E.evalEffect(rSource, rNewEffect.sName);

        local aNewComps = EffectManager.parseEffect(rNewEffect.sName);
        aNewComps[1] = aOriginalComps[1];
        rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewComps);
    end

    return false
end

function customGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly) -- luacheck: ignore (cyclomatic complexity)
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
    local aEffects = {};
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
    else
        aEffects = DB.getChildren(ActorManager.getCTNode(rActor), "effects");
    end

    -- Iterate through effects
    for _, v in pairs(aEffects) do
        local nActive = DB.getValue(v, 'isactive', 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
                            (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

        -- Check effect is from used weapon.
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or
            (bAdvancedEffects and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
            AdvancedEffects.isValidCheckEffect(rActor, v))) then
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
                                        local sInsert = StringManager.trim(vPhraseOR:sub(nTempIndexAND,
                                            nStartAND - nTempIndexAND))
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
                            elseif rEffectComp.type ~= "" and not tEffectCompParams.bIgnoreOtherFilter then
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
                                BCEManager.chat("Match:", rEffectComp)
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
                                BCEManager.chat("Other Filter:", aEffectOtherFilter)
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
                            rEffectComp.sEffectNode = v.getPath();
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
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP

    return results
end

---	This function returns false if the effect is tied to an item and the item is not being used.
--	luacheck: globals isValidCheckEffect
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
                sItemPath = nodeItem.getPath()
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

function customHasEffectCondition(rActor, sEffect)
    return EffectManager35E.hasEffect(rActor, sEffect, nil, false, true);
end

--	replace 3.5E EffectManager35E manager_effect_35E.lua hasEffect() with this
function customHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    if not sEffect or not rActor then
        return false
    end
    local sLowerEffect = sEffect:lower()
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffect);
    -- Iterate through each effect
    local aMatch = {}
    local aEffects = {};
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
    else
        aEffects = DB.getChildren(ActorManager.getCTNode(rActor), "effects");
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
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or
            (bAdvancedEffects and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
            AdvancedEffects.isValidCheckEffect(rActor, v))) then
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