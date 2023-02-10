--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local bAdvancedEffects = nil;
local bUntrueEffects = nil;

local getEffectsByType = nil;
local hasEffect = nil;
local hasEffectCondition = nil;

function onInit()
    OptionsManager.registerOption2('ALLOW_DUPLICATE_EFFECT', false, 'option_Better_Combat_Effects', 'option_Allow_Duplicate', 'option_entry_cycler',
                                   {labels = 'option_val_off', values = 'off', baselabel = 'option_val_on', baseval = 'on', default = 'on'});

    OptionsManager.registerOption2('CONSIDER_DUPLICATE_DURATION', false, 'option_Better_Combat_Effects', 'option_Consider_Duplicate_Duration',
                                   'option_entry_cycler',
                                   {labels = 'option_val_on', values = 'on', baselabel = 'option_val_off', baseval = 'off', default = 'off'});

    OptionsManager.registerOption2('RESTRICT_CONCENTRATION', false, 'option_Better_Combat_Effects', 'option_Concentrate_Restrict', 'option_entry_cycler',
                                   {labels = 'option_val_on', values = 'on', baselabel = 'option_val_off', baseval = 'off', default = 'off'});

    OptionsManager.registerOption2('AUTOPARSE_EFFECTS', false, 'option_Better_Combat_Effects', 'option_Autoparse_Effects', 'option_entry_cycler',
                                   {labels = 'option_val_on', values = 'on', baselabel = 'option_val_off', baseval = 'off', default = 'off'});

    EffectManagerBCE.setCustomPreAddEffect(EffectManager5EBCE.addEffectPre5E)
    EffectManager.setCustomOnEffectAddIgnoreCheck(EffectManager5EBCE.customOnEffectAddIgnoreCheck)

    -- bExpandedNPC = BCEManager.hasExtension( "5E - Expanded NPCs")
    bAdvancedEffects = BCEManager.hasExtension('AdvancedEffects');
    bUntrueEffects = BCEManager.hasExtension('IF_NOT_untrue_effects_berwind');

    getEffectsByType = EffectManager5E.getEffectsByType;
    hasEffect = EffectManager5E.hasEffect;
    hasEffectCondition = EffectManager5E.hasEffectCondition;

    EffectManager5E.getEffectsByType = customGetEffectsByType;
    EffectManager5E.hasEffect = customHasEffect;
    EffectManager5E.hasEffectCondition = customHasEffectCondition;
end

function onClose()
    EffectManager5E.getEffectsByType = getEffectsByType;
    EffectManager5E.hasEffect = hasEffect;
    EffectManager5E.hasEffectCondition = hasEffectCondition;

    EffectManagerBCE.removeCustomPreAddEffect(EffectManager5EBCE.addEffectPre5E);
    EffectManagerBCE.removeCustomPostAddEffect(EffectManager5EBCE.addEffectPost5E);
end

function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
    BCEManager.chat('customOnEffectAddIgnoreCheck : ');
    local sDuplicateMsg = EffectManager5E.onEffectAddIgnoreCheck(nodeCT, rEffect);
    local bIgnoreDuration = OptionsManager.isOption('CONSIDER_DUPLICATE_DURATION', 'off');
    if OptionsManager.isOption('ALLOW_DUPLICATE_EFFECT', 'off') and not rEffect.sName:match('STACK') then
        for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
            if (DB.getValue(nodeEffect, 'label', '') == rEffect.sName) and (DB.getValue(nodeEffect, 'init', 0) == rEffect.nInit) and
                (bIgnoreDuration or (DB.getValue(nodeEffect, 'duration', 0) == rEffect.nDuration)) and
                (DB.getValue(nodeEffect, 'source_name', '') == rEffect.sSource) then

                sDuplicateMsg = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), rEffect.sName,
                                              Interface.getString('effect_status_exists'));
                break
            end
        end
    end
    return sDuplicateMsg;
end

function addEffectPre5E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    BCEManager.chat('addEffectPre5E : ');
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

        rNewEffect.sName = EffectManager5E.evalEffect(rSource, rNewEffect.sName);

        local aNewComps = EffectManager.parseEffect(rNewEffect.sName);
        aNewComps[1] = aOriginalComps[1];
        rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewComps);
    end

    if OptionsManager.isOption('RESTRICT_CONCENTRATION', 'on') then
        local nDuration = rNewEffect.nDuration;
        if rNewEffect.sUnits == 'minute' then
            nDuration = nDuration * 10;
        end
        EffectManager5EBCE.dropConcentration(rNewEffect, nDuration);
    end

    return false;
end

-- 5E Only - Check if this effect has concentration and drop all previous effects of concentration from the source
-- TODO: This is really old code and written when I was green. I should take another look at if this whole thing is actually needed
function dropConcentration(rNewEffect, nDuration)
    BCEManager.chat('dropConcentration : ');
    if (rNewEffect.sName:match('%(C%)')) then
        local nodeCT = CombatManager.getActiveCT();
        local sSourceName = rNewEffect.sSource;
        if sSourceName == '' then
            sSourceName = ActorManager.getCTPathFromActorNode(nodeCT);
        end
        local sSource;
        local ctEntries = CombatManager.getSortedCombatantList();
        local tEffectComps = EffectManager.parseEffect(rNewEffect.sName);
        local sNewEffectTag = tEffectComps[1];
        for _, nodeCTConcentration in pairs(ctEntries) do
            if nodeCT == nodeCTConcentration then
                sSource = '';
            else
                sSource = sSourceName;
            end
            for _, nodeEffect in pairs(DB.getChildren(nodeCTConcentration, 'effects')) do
                local sEffect = DB.getValue(nodeEffect, 'label', '');
                tEffectComps = EffectManager.parseEffect(sEffect);
                local sEffectTag = tEffectComps[1];
                if (sEffect:match('%(C%)') and (DB.getValue(nodeEffect, 'source_name', '') == sSource)) and (sEffectTag ~= sNewEffectTag) or
                    ((sEffectTag == sNewEffectTag and (DB.getValue(nodeEffect, 'duration', 0) ~= nDuration))) then
                    BCEManager.modifyEffect(nodeEffect, 'Remove', sEffect);
                end
            end
        end
    end
end

function customGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
    if not rActor then
        return {};
    end
    local results = {};
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffectType);
    -- Set up filters
    local aRangeFilter = {};
    local aOtherFilter = {};
    local aConditionFilter = {};
    local aDamageFilter = {};
    if aFilter then
        for _, v in pairs(aFilter) do
            if type(v) ~= 'string' then
                table.insert(aOtherFilter, v);
            elseif StringManager.contains(DataCommon.rangetypes, v) then
                table.insert(aRangeFilter, v);
            elseif StringManager.contains(DataCommon.conditions, v) then
                table.insert(aConditionFilter, v);
            elseif StringManager.contains(DataCommon.dmgtypes, v) or v == 'all' then
                table.insert(aDamageFilter, v);
            elseif not tEffectCompParams.bIgnoreOtherFilter then
                table.insert(aOtherFilter, v);
            end
        end
    end

    local aEffects = {};
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
    else
        aEffects = DB.getChildren(ActorManager.getCTNode(rActor), 'effects');
    end

    -- Iterate through effects
    for _, v in pairs(aEffects) do
        -- Check active
        local nActive = DB.getValue(v, 'isactive', 0);
        -- BCEManager.chat(v)
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or
            (bAdvancedEffects and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or EffectManagerADND.isValidCheckEffect(rActor, v))) then
            local sLabel = DB.getValue(v, 'label', '');
            local sApply = DB.getValue(v, 'apply', '');
            -- IF COMPONENT WE ARE LOOKING FOR SUPPORTS TARGETS, THEN CHECK AGAINST OUR TARGET
            local bTargeted = EffectManager.isTargetedEffect(v);
            if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
                local aEffectComps = EffectManager.parseEffect(sLabel);

                -- Look for type/subtype match
                local nMatch = 0;
                for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
                    -- Handle conditionals
                    if rEffectComp.type == 'IF' then
                        if not EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
                            break
                        end
                    elseif bUntrueEffects and rEffectComp.type == 'IFN' then
                        if EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
                            break
                        end
                    elseif rEffectComp.type == 'IFT' then
                        if not rFilterActor then
                            break
                        end
                        if not EffectManager5E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
                            break
                        end
                        bTargeted = true;
                    elseif bUntrueEffects and rEffectComp.type == 'IFTN' then
                        if --[[OptionsManager.isOption('NO_TARGET', 'off') and]] not rFilterActor then
                            break
                        end
                        if EffectManager5E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
                            break
                        end
                        bTargeted = true;

                        -- Compare other attributes
                    else
                        -- Strip energy/bonus types for subtype comparison
                        local aEffectRangeFilter = {};
                        local aEffectOtherFilter = {};
                        local aEffectConditionFilter = {};
                        local aEffectDamageFilter = {};
                        local j = 1;
                        while rEffectComp.remainder[j] and rEffectComp.type == sEffectType do
                            local s = rEffectComp.remainder[j];
                            if #s > 0 and ((s:sub(1, 1) == '!') or (s:sub(1, 1) == '~')) then
                                s = s:sub(2);
                            end
                            if StringManager.contains(DataCommon.bonustypes, s) or StringManager.contains(DataCommon.connectors, s) then
                                -- SKIP
                            elseif StringManager.contains(DataCommon.conditions, s) then
                                table.insert(aEffectConditionFilter, s);
                            elseif StringManager.contains(DataCommon.dmgtypes, s) or s == 'all' then
                                table.insert(aEffectDamageFilter, s);
                            elseif StringManager.contains(DataCommon.rangetypes, s) then
                                table.insert(aEffectRangeFilter, s);
                            elseif not tEffectCompParams.bIgnoreOtherFilter then
                                table.insert(aEffectOtherFilter, s:lower());
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
                                BCEManager.chat('Match')
                            end

                            -- Check filters
                            if #aEffectRangeFilter > 0 then
                                BCEManager.chat('Range Filter:', #aEffectRangeFilter)
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
                                BCEManager.chat('Other Filter:', aEffectOtherFilter)

                                local bOtherMatch = false;
                                for _, v2 in pairs(aOtherFilter) do
                                    if type(v2) == 'table' then
                                        local bOtherTableMatch = true;
                                        for k3, v3 in pairs(v2) do
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
                            if tEffectCompParams.bConditionFilter and #aEffectConditionFilter > 0 then
                                BCEManager.chat('Condition Filter:', #aEffectConditionFilter)
                                local bConditionMatch = false;
                                for _, v2 in pairs(aConditionFilter) do
                                    if StringManager.contains(aEffectConditionFilter, v2) then
                                        bConditionMatch = true;
                                        break
                                    end
                                end
                                if not bConditionMatch then
                                    comp_match = false;
                                end
                            end
                            if tEffectCompParams.bDamageFilter and #aEffectDamageFilter > 0 then
                                BCEManager.chat('Damage Filter:', #aEffectDamageFilter)
                                local bDamageMatch = false;
                                for _, v2 in pairs(aDamageFilter) do
                                    if StringManager.contains(aEffectDamageFilter, v2) then
                                        bDamageMatch = true;
                                        break
                                    end
                                end
                                if not bDamageMatch then
                                    comp_match = false;
                                end
                            end
                        end

                        -- Match!
                        -- Debug.chat(rEffectComp ,sEffectType , comp_match, bTargetedOnly, bTargeted)

                        if comp_match then
                            nMatch = kEffectComp;
                            rEffectComp.sEffectNode = v.getPath();
                            BCEManager.chat('Add: ', rEffectComp, sEffectType)

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
                        if sApply == 'action' then
                            EffectManager.notifyExpire(v, 0);
                        elseif sApply == 'roll' then
                            EffectManager.notifyExpire(v, 0, true);
                        elseif sApply == 'single' or tEffectCompParams.bOneShot then
                            EffectManager.notifyExpire(v, nMatch, true);
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP

    -- RESULTS
    return results;
end

function customHasEffectCondition(rActor, sEffect)
    return EffectManager5E.hasEffect(rActor, sEffect, nil, false, true);
end

function customHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    if not sEffect or not rActor then
        return false;
    end
    local sLowerEffect = sEffect:lower();
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffect);
    -- Set up filters
    -- Iterate through each effect
    local aMatch = {};
    local aEffects = {};
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffect);
    else
        aEffects = DB.getChildren(ActorManager.getCTNode(rActor), 'effects');
    end
    for _, v in pairs(aEffects) do
        local nActive = DB.getValue(v, 'isactive', 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
        if (not bAdvancedEffects and (nActive ~= 0 or bActive)) or
            (bAdvancedEffects and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or EffectManagerADND.isValidCheckEffect(rActor, v))) then
            -- Parse each effect label
            local sLabel = DB.getValue(v, 'label', '');
            local bTargeted = EffectManager.isTargetedEffect(v);
            local aEffectComps = EffectManager.parseEffect(sLabel);

            -- Iterate through each effect component looking for a type match
            local nMatch = 0;
            for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
                -- Handle conditionals
                if rEffectComp.type == 'IF' then
                    if not EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
                        break
                    end
                elseif bUntrueEffects and rEffectComp.type == 'IFN' then
                    if EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
                        break
                    end
                elseif rEffectComp.type == 'IFT' then
                    if not rTarget then
                        break
                    end
                    if not EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
                        break
                    end
                elseif bUntrueEffects and rEffectComp.type == 'IFTN' then
                    if OptionsManager.isOption('NO_TARGET', 'off') and not rTarget then
                        break
                    end
                    if EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
                        break
                    end

                    -- Check for match
                elseif rEffectComp.original:lower() == sLowerEffect then
                    if bTargeted and not bIgnoreEffectTargets then
                        if EffectManager.isEffectTarget(v, rTarget) then
                            nMatch = kEffectComp;
                        end
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
                    end
                end
            end
        end
    end

    if #aMatch > 0 then
        return true;
    end
    return false;
end

