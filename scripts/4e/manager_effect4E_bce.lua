--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local applyOngoingDamageBCE = nil
local applyOngoingRegenBCE = nil
local getEffectsByType = nil

function onInit()
    EffectsManagerBCE.setCustomPreAddEffect(addEffectPre4E);
    ActionsManager.registerResultHandler("attack", onAttack4E);

    getEffectsByType = EffectManager4E.getEffectsByType;
    applyOngoingDamageBCE = EffectManagerDnDBCE.applyOngoingDamage;
    applyOngoingRegenBCE = EffectManagerDnDBCE.applyOngoingRegen;

    EffectManager4E.getEffectsByType = customGetEffectsByType;
    EffectManagerDnDBCE.applyOngoingDamage = applyOngoingDamage;
    EffectManagerDnDBCE.applyOngoingRegen = applyOngoingRegen;

    EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck);
end

function onClose()
    EffectManager4E.getEffectsByType = getEffectsByType;

    EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre4E);
    EffectManagerDnDBCE.applyOngoingDamage = applyOngoingDamageBCE
    EffectManagerDnDBCE.applyOngoingRegen = applyOngoingRegenBCE
end

function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
    local sDuplicateMsg = nil;
    sDuplicateMsg = EffectManager4E.onEffectAddIgnoreCheck(nodeCT, rEffect);
    if sDuplicateMsg and rEffect.sName:match("STACK") and sDuplicateMsg:match("ALREADY EXISTS") then
        sDuplicateMsg = nil;
    end
    return sDuplicateMsg;
end

function onAttack4E(rSource, rTarget, rRoll)
    local tMatch = {};

    -- Only process these if on the source node
    tMatch = EffectManager4E.getEffectsByType(rSource, "ATKDS");
    for _, tEffect in pairs(tMatch) do
        BCEManager.modifyEffect(tEffect.sEffectNode, "Deactivate")
    end
    ActionAttack.onAttack(rSource, rTarget, rRoll)
end

-- 4E is different enough that we need need to handle ongoing damage here
function applyOngoingDamage(rSource, rTarget, rEffectComp, bHalf, sLabel)
    local rAction = {}
    local aClause = {}
    rAction.clauses = {}

    aClause.basedice = rEffectComp.dice;
    aClause.dicestr = StringManager.convertDiceToString(rEffectComp.dice, rEffectComp.mod, true);
    aClause.mod = rEffectComp.mod
    aClause.basemult = 0
    aClause.stat = {}
    aClause.dmgtype = string.lower(table.concat(rEffectComp.remainder, ","))
    aClause.critdicestr = ""

    table.insert(rAction.clauses, aClause)
    if not sLabel then
        sLabel = "Ongoing Effect"
    end
    rAction.name = sLabel

    local rRoll = ActionDamage.getRoll(rTarget, rAction)
    if bHalf then
        rRoll.sDesc = rRoll.sDesc .. " [HALF]"
    end
    ActionsManager.actionDirect(rSource, "damage", {rRoll}, {{rTarget}})
end

-- 4E is different enough that we need need to handle ongoing regen here
function applyOngoingRegen(rSource, rTarget, rEffectComp, bTemp)
    local rAction = {}
    local aClause = {}
    rAction.clauses = {}

    aClause.dice = rEffectComp.dice;
    aClause.dicestr = StringManager.convertDiceToString(rEffectComp.dice, rEffectComp.mod, true);
    aClause.mod = rEffectComp.mod
    aClause.stat = {}
    aClause.basemult = 0
    aClause.cost = 0

    if bTemp == true then
        rAction.name = "Ongoing Temporary Hitpoints"
        aClause.subtype = "temp"
    else
        rAction.name = "Ongoing Regeneration"
    end
    table.insert(rAction.clauses, aClause)
    local rRoll = ActionHeal.getRoll(rTarget, rAction)
    ActionsManager.actionDirect(rSource, "heal", {rRoll}, {{rTarget}})
end

function addEffectPre4E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    local rActor = ActorManager.resolveActor(nodeCT)
    local rSource = nil
    if not rNewEffect.sSource or rNewEffect.sSource == "" then
        rSource = rActor
    else
        local nodeSource = DB.findNode(rNewEffect.sSource)
        rSource = ActorManager.resolveActor(nodeSource)
    end
    rNewEffect.sName = EffectManager4E.evalEffect(rSource, rNewEffect.sName)

    return false
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
    if aFilter then
        for _, v in pairs(aFilter) do
            if type(v) ~= "string" then
                table.insert(aOtherFilter, v);
            elseif StringManager.contains(DataCommon.rangetypes, v) then
                table.insert(aRangeFilter, v);
            elseif not tEffectCompParams.bIgnoreOtherFilter then
                table.insert(aOtherFilter, v);
            end
        end
    end

    -- Determine effect type targeting
    local bTargetSupport = StringManager.isWord(sEffectType, DataCommon.targetableeffectcomps);

    local aEffects = {};
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
    else
        aEffects = DB.getChildren(ActorManager.getCTNode(rActor), "effects");
    end

    -- Iterate through effects
    for _, v in pairs(aEffects) do
        -- Check active
        local nActive = DB.getValue(v, "isactive", 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
                            (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
        if (bActive or nActive ~= 0) then
            local sLabel = DB.getValue(v, "label", "");
            local sApply = DB.getValue(v, "apply", "");

            -- Check targeting
            local bTargeted = EffectManager.isTargetedEffect(v);
            if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
                local aEffectComps = EffectManager.parseEffect(sLabel);

                -- Look for type/subtype match
                local nMatch = 0;
                for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
                    -- Check for follw on effects and ignore the rest
                    if StringManager.contains({"AFTER", "FAIL"}, rEffectComp.type) then
                        break

                        -- Handle conditionals
                    elseif rEffectComp.type == "IF" then
                        if not EffectManager4E.checkConditional(rActor, v, rEffectComp) then
                            break
                        end
                    elseif rEffectComp.type == "IFT" then
                        if not rFilterActor then
                            break
                        end
                        if not EffectManager4E.checkConditional(rFilterActor, v, rEffectComp, rActor) then
                            break
                        end
                        bTargeted = true;

                        -- Compare other attributes
                    else
                        -- Strip energy/bonus types for subtype comparison
                        local aEffectRangeFilter = {};
                        local aEffectOtherFilter = {};
                        for _, v2 in pairs(rEffectComp.remainder) do
                            if StringManager.contains(DataCommon.dmgtypes, v2) or
                                StringManager.contains(DataCommon.bonustypes, v2) or v2 == "all" then
                                -- Skip
                            elseif StringManager.contains(DataCommon.rangetypes, v2) then
                                table.insert(aEffectRangeFilter, v2);
                            elseif not tEffectCompParams.bIgnoreOtherFilter then
                                table.insert(aEffectOtherFilter, v2);
                            end
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
                                    if type(v2) == "table" then
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
                        end

                        -- Match!
                        if comp_match then
                            nMatch = kEffectComp;
                            if nActive == 1 or bActive then
                                rEffectComp.node = v;
                                table.insert(results, rEffectComp);
                            end
                        end
                    end
                end -- END EFFECT COMPONENT LOOP

                -- Remove one shot effects
                if nMatch > 0 then
                    if nActive == 2 then
                        DB.setValue(v, "isactive", "number", 1);
                    else
                        if sApply == "action" then
                            EffectManager.notifyExpire(v, 0);
                        elseif sApply == "roll" then
                            EffectManager.notifyExpire(v, 0, true);
                        elseif sApply == "single" or tEffectCompParams.bOneShot then
                            EffectManager.notifyExpire(v, nMatch, true);
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP
    return results;
end
