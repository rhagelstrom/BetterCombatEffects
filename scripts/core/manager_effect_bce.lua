--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
-- luacheck: globals EffectManagerBCE
------------------ ORIGINALS ------------------
local addEffect = nil;
------------------ END ORIGINALS ------------------
--
-- CONSOLIDATED EFFECT QUERY HELPERS
-- 		NOTE: PRELIMINARY FOR VISION SUPPORT
--		NOTE 2: NEEDS CONDITIONAL SUPPORT FOR GENERAL PURPOSE USE
--
-- EFFECT TYPE PARAMETERS
-- 		bIgnoreExpire = true/false (default = false)
--		bIgnoreTarget = true/false (default = false)
--		bIgnoreDisabledCheck = true/false (default = false)
--      bIgnoreOtherFilter = true/false (default = false)
-- 		bOneShot = true/false (default = false)
-- 		bDamageFilter = true/false (default = false)
-- 		bConditionFilter = true/false (default = false)

local _tEffectCompTypes = {};

------------------ CUSTOM BCE FUNTION HOOKS ------------------
local aCustomMatchEffectHandlers = {};
local aCustomPreAddEffectHandlers = {};
local aCustomPostAddEffectHandlers = {};

local getEffectsByType = nil;
------------------ END CUSTOM BCE FUNTION HOOKS ------------------

function onInit()
    addEffect = EffectManager.addEffect;
    getEffectsByType = EffectManager.getEffectsByType;

    EffectManager.addEffect = EffectManagerBCE.customAddEffectPre;
    EffectManager.getEffectsByType = customGetEffectsByType;

    if Session.IsHost then
        EffectManagerBCE.initEffectHandlers();
    end
end

function onClose()
    EffectManager.addEffect = addEffect;
    EffectManager.getEffectsByType = getEffectsByType;
    if Session.IsHost then
        EffectManagerBCE.deleteEffectHandlers();
    end
end

------------------ OVERRIDES ------------------
function customGetEffectsByType(rActor, sEffectCompType, rFilterActor, bTargetedOnly)
    if not rActor then
        return {};
    end
    local tResults = {};
    local tEffectCompParams = EffectManagerBCE.getEffectCompType(sEffectCompType);

    -- Iterate through effects
    local aEffects;
    if TurboManager then
        aEffects = TurboManager.getMatchedEffects(rActor, sEffectCompType);
    else
        aEffects = DB.getChildren(ActorManager.getCTNode(rActor), 'effects');
    end

    for _, v in pairs(aEffects) do
        -- Check active
        local nActive = DB.getValue(v, 'isactive', 0);
        local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or (not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
                            (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
        if bActive or nActive ~= 0 then
            -- If effect type we are looking for supports targets, then check targeting
            local bTargetMatch;
            if tEffectCompParams.bIgnoreTarget then
                bTargetMatch = true;
            else
                local bTargeted = EffectManager.isTargetedEffect(v);
                if bTargeted then
                    bTargetMatch = EffectManager.isEffectTarget(v, rFilterActor);
                else
                    bTargetMatch = not bTargetedOnly;
                end
            end

            if bTargetMatch then
                local sLabel = DB.getValue(v, 'label', '');
                local aEffectComps = EffectManager.parseEffect(sLabel);

                -- Look for type/subtype match
                local nMatch = 0;
                for kEffectComp, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
                    if rEffectComp.type == sEffectCompType or rEffectComp.original == sEffectCompType then
                        nMatch = kEffectComp;
                        rEffectComp.sEffectNode = v.getPath();
                        if nActive == 1 or (tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) then
                            table.insert(tResults, rEffectComp);
                        end
                    end
                end -- END EFFECT COMPONENT LOOP

                -- Remove one shot effects
                if (nMatch > 0) and not tEffectCompParams.bIgnoreExpire then
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
                        end
                    end
                end
            end -- END TARGET CHECK
        end -- END ACTIVE CHECK
    end -- END EFFECT LOOP

    -- RESULTS
    return tResults;
end

function customAddEffectPre(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    BCEManager.chat('Add Effect Pre: ', rNewEffect.sName);
    if not nodeCT or not rNewEffect or not rNewEffect.sName then
        return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    end
    if EffectManagerBCE.onCustomPreAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg) then
        return true;
    end
    addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    local nodeEffect;
    for _, v in pairs(DB.getChildren(nodeCT, 'effects')) do
        if (DB.getValue(v, 'label', '') == rNewEffect.sName) and (DB.getValue(v, 'init', 0) == rNewEffect.nInit) and
            (DB.getValue(v, 'duration', 0) == rNewEffect.nDuration) and (DB.getValue(v, 'source_name', '') == rNewEffect.sSource) then
            nodeEffect = v;
            DB.addHandler(nodeEffect.getPath(), 'onDelete', expireAdd);
            EffectManagerBCE.onCustomPostAddEffect(nodeCT, nodeEffect);
            break
        end
    end
end
------------------ END OVERRIDES ------------------
--
-- CONSOLIDATED EFFECT QUERY HELPERS
-- 		NOTE: PRELIMINARY FOR VISION SUPPORT
--		NOTE 2: NEEDS CONDITIONAL SUPPORT FOR GENERAL PURPOSE USE
--
-- EFFECT TYPE PARAMETERS
-- 		bIgnoreExpire = true/false (default = false)
--		bIgnoreTarget = true/false (default = false)
--		bIgnoreDisabledCheck = true/false (default = false)
-- 		bIgnoreOtherFilter = true/false (default = false)
-- 		bOneShot = true/false (default = false)
--      bDamageFilter = true/false (default = false)
--      bConditionFilter = true/false (default = false)

function registerEffectCompType(sEffectCompType, tParams)
    _tEffectCompTypes[sEffectCompType] = tParams;
end

function getEffectCompType(sEffectCompType)
    local aReturn = {};
    if _tEffectCompTypes[sEffectCompType] then
        aReturn = _tEffectCompTypes[sEffectCompType];
    end

    return aReturn;
end

-- accepts database path or databasenode
function getLabelShort(nodeEffect)
    if type(nodeEffect) == 'string' then
        nodeEffect = DB.findNode(nodeEffect);
    end
    local sLabel = DB.getValue(nodeEffect, 'label', '');
    local tParseEffect = EffectManager.parseEffect(sLabel);
    return StringManager.trim(tParseEffect[1]);
end

function initEffectHandlers()
    local ctEntries = CombatManager.getCombatantNodes();
    for _, nodeCT in pairs(ctEntries) do
        for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
            DB.addHandler(nodeEffect.getPath(), 'onDelete', expireAdd);
        end
        DB.addHandler(nodeCT.getPath() .. '.effects.*.label', 'onAdd', expireAddHelper);
    end
end

function deleteEffectHandlers()
    local ctEntries = CombatManager.getCombatantNodes();
    for _, nodeCT in pairs(ctEntries) do
        for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
            DB.removeHandler(nodeEffect.getPath(), 'onDelete', expireAdd);
        end
        DB.removeHandler(nodeCT.getPath() .. '.effects.*.label', 'onAdd', expireAdd);
    end
end

function expireAddHelper(nodeLabel)
    DB.removeHandler(nodeLabel.getPath(), 'onAdd', expireAddHelper);
    DB.addHandler(DB.getChild(nodeLabel, '..').getPath(), 'onDelete', expireAdd);
end

function expireAdd(nodeEffect)
    BCEManager.chat('expireAdd: ');
    local sLabel = DB.getValue(nodeEffect, 'label', '', '');
    if sLabel:match('EXPIREADD') then
        local sActor = DB.getChild(nodeEffect, '...').getPath();
        local nodeCT = DB.findNode(sActor);
        local sSource = DB.getValue(nodeEffect, 'source_name', '');
        local sourceNode = nodeCT;
        if sSource ~= '' then
            sourceNode = DB.findNode(sSource);
        end
        local aEffectComps = EffectManager.parseEffect(sLabel);
        for _, sEffectComp in ipairs(aEffectComps) do
            local tEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
            if tEffectComp.type == 'EXPIREADD' then
                BCEManager.notifyAddEffect(nodeCT, sourceNode, StringManager.combine(' ', unpack(tEffectComp.remainder)));
                break
            end
        end
    end
    DB.removeHandler(nodeEffect.getPath(), 'onDelete', expireAdd);
end

------------------ CUSTOM BCE FUNTION HOOKS ------------------
function setCustomMatchEffect(f)
    table.insert(aCustomMatchEffectHandlers, f);
end

function removeCustomMatchEffect(f)
    for kCustomMatchEffect, fCustomMatchEffect in ipairs(aCustomMatchEffectHandlers) do
        if fCustomMatchEffect == f then
            table.remove(aCustomMatchEffectHandlers, kCustomMatchEffect);
            return false; -- success
        end
    end
    return true;
end

function onCustomMatchEffect(sEffect)
    for _, fMatchEffect in ipairs(aCustomMatchEffectHandlers) do
        if fMatchEffect(sEffect) == true then
            return true;
        end
    end
    return false; -- success
end

function setCustomPreAddEffect(f)
    table.insert(aCustomPreAddEffectHandlers, f);
end

function removeCustomPreAddEffect(f)
    for kCustomPreAddEffect, fCustomPreAddEffect in ipairs(aCustomPreAddEffectHandlers) do
        if fCustomPreAddEffect == f then
            table.remove(aCustomPreAddEffectHandlers, kCustomPreAddEffect);
            return false; -- success
        end
    end
    return true;
end

function onCustomPreAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    -- do this backwards from order added. Need to account for string changes in the effect
    -- from things like [STR] before we do any dice roll handlers
    for i = #aCustomPreAddEffectHandlers, 1, -1 do
        if aCustomPreAddEffectHandlers[i](sUser, sIdentity, nodeCT, rNewEffect, bShowMsg) == true then
            return true;
        end
    end
    return false; -- success
end

function setCustomPostAddEffect(f)
    table.insert(aCustomPostAddEffectHandlers, f);
end

function removeCustomPostAddEffect(f)
    for kCustomPostAddEffect, fCustomPostAddEffect in ipairs(aCustomPostAddEffectHandlers) do
        if fCustomPostAddEffect == f then
            table.remove(aCustomPostAddEffectHandlers, kCustomPostAddEffect);
            return false; -- success
        end
    end
    return true;
end

function onCustomPostAddEffect(nodeActor, nodeEffect)
    for _, fPostAddEffect in ipairs(aCustomPostAddEffectHandlers) do
        fPostAddEffect(nodeActor, nodeEffect);
    end
end
------------------ CUSTOM BCE FUNTION HOOKS ------------------
