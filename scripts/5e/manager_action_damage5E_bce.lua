--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals ActionDamage5EBCE BCEManager ActionDamageDnDBCE
-- luacheck: globals onInit onClose customApplyDamage customGetDamageAdjust getReductionType applyDamage
-- luacheck: globals reductionHelper
local getDamageAdjust = nil;
local applyDamageOriginal = nil;

function onInit()
    getDamageAdjust = ActionDamage.getDamageAdjust;
    applyDamageOriginal = ActionDamage.applyDamage;
    ActionDamage.getDamageAdjust = customGetDamageAdjust;
    ActionDamage.applyDamage = customApplyDamage;
end

function onClose()
    ActionDamage.getDamageAdjust = getDamageAdjust;
    ActionDamage.applyDamage = applyDamageOriginal;
end

function customApplyDamage(rSource, rTarget, rRoll, ...)
    ActionDamageDnDBCE.applyDamageBCE(rSource, rTarget, rRoll, ...);
end

function applyDamage(rSource, rTarget, rRoll, ...)
    applyDamageOriginal(rSource, rTarget, rRoll, ...);
end

function customGetDamageAdjust(rSource, rTarget, nDamage, rDamageOutput, ...)
    BCEManager.chat('customGetDamageAdjust : ');
    local nReduce = 0;
    local aReduce = ActionDamage5EBCE.getReductionType(rSource, rTarget, 'DMGR', rDamageOutput);
    for k, v in pairs(rDamageOutput.aDamageTypes) do
        -- Get individual damage types for each damage clause
        local aSrcDmgClauseTypes = {};
        local aTemp = StringManager.split(k, ',', true);
        for _, vType in ipairs(aTemp) do
            if vType ~= 'untyped' and vType ~= '' then
                table.insert(aSrcDmgClauseTypes, vType);
            end
        end
        local nLocalReduce = ActionDamage.checkNumericalReductionType(aReduce, aSrcDmgClauseTypes, v);
        -- We need to do this nonsense because we need to reduce damage before resist calculation
        if nLocalReduce > 0 then
            rDamageOutput.aDamageTypes[k] = rDamageOutput.aDamageTypes[k] - nLocalReduce;
            nDamage = nDamage - nLocalReduce;
        end
        nReduce = nReduce + nLocalReduce;
    end
    if (nReduce > 0) then
        table.insert(rDamageOutput.tNotifications, '[REDUCED]');
    end
    local results = {getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput, ...)};
    -- By default FG returns the following values with anything else being another extension
    -- 1 nDamageAdjust
    -- 2 bVulnerable
    -- 3 bResist
    results[1] = results[1] - nReduce;
    return unpack(results);
end

function getReductionType(rSource, rTarget, sEffectType, rDamageOutput)
    BCEManager.chat('getReductionType : ');
    local tEffects = EffectManager5E.getEffectsByType(rTarget, sEffectType, rDamageOutput.aDamageFilter, rSource);
    local aFinal = {};
    local aDamageTypes = UtilityManager.copyDeep(rDamageOutput.aDamageTypes);
    local nTotalDamage = rDamageOutput.nVal;
    for _, tEffect in pairs(tEffects) do
        local rReduction = {};
        if tEffect.mod < 1 and tEffect.mod > 0 then
            local nReduce = math.floor(tEffect.mod * nTotalDamage);
            for _, sDescriptor in ipairs(tEffect.remainder) do
                if aDamageTypes[sDescriptor] then
                    nReduce = math.floor(tEffect.mod * aDamageTypes[sDescriptor]);
                    break
                end
            end
            tEffect.mod = nReduce;
        end
        rReduction.mod = tEffect.mod;
        rReduction.aNegatives = {};
        if not next(tEffect.remainder) then
            table.insert(tEffect.remainder, 'all');
        end

        for _, vType in pairs(tEffect.remainder) do
            if #vType > 1 and ((vType:sub(1, 1) == '!') or (vType:sub(1, 1) == '~')) then
                if StringManager.contains(DataCommon.dmgtypes, vType:sub(2)) then
                    table.insert(rReduction.aNegatives, vType:sub(2));
                end
            end
        end
        for _, vType in pairs(tEffect.remainder) do
            if vType ~= 'untyped' and vType ~= '' and vType:sub(1, 1) ~= '!' and vType:sub(1, 1) ~= '~' then
                if StringManager.contains(DataCommon.dmgtypes, vType) or vType == 'all' then
                    if aFinal[vType] then
                        rReduction.mod = rReduction.mod + aFinal[vType].mod;
                    end
                    aFinal[vType] = rReduction;
                end
            end
        end

        local aFinalCopy = UtilityManager.copyDeep(aFinal);
        nTotalDamage = ActionDamage5EBCE.reductionHelper(aDamageTypes, aFinalCopy, nTotalDamage)
    end
    return aFinal;
end

-- Needed to get the stacking of DMGR correct.
function reductionHelper(aDamageTypes, aFinalCopy, nTotalDamage)
    for sDamageKey, _ in pairs(aDamageTypes) do
        for sFinalKey, _ in pairs(aFinalCopy) do
            if sFinalKey == 'all' then
                local nDamagetoReduce = aFinalCopy[sFinalKey].mod;
                local bDone = false;
                while not bDone do
                    bDone = true;
                    for sDecrementKey, nDamage in pairs(aDamageTypes) do
                        if nDamage ~= 0 then
                            aDamageTypes[sDecrementKey] = aDamageTypes[sDecrementKey] - 1;
                            aFinalCopy[sFinalKey].mod = aFinalCopy[sFinalKey].mod - 1;
                            nTotalDamage = math.max(nTotalDamage - 1, 0);
                            nDamagetoReduce = math.max(nDamagetoReduce - 1, 0);
                            if nDamagetoReduce ~= 0 then
                                bDone = false;
                            end
                        end
                        if aFinalCopy[sFinalKey].mod == 0 then
                            break
                        end
                    end
                end
            elseif sFinalKey == sDamageKey then
                aDamageTypes[sDamageKey] = math.max(aDamageTypes[sDamageKey] - aFinalCopy[sFinalKey].mod, 0);
                nTotalDamage = math.max(nTotalDamage - aFinalCopy[sFinalKey].mod, 0);
            end
            if aFinalCopy[sFinalKey].mod == 0 then
                break
            end
        end
    end
    return nTotalDamage;
end
