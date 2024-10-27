--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
--
-- luacheck: globals ActionDamage4EBCE BCEManager ActionDamageDnDBCE
-- luacheck: globals onInit onClose customApplyDamage applyDamage customGetDamageAdjust checkNumericalReductionType
-- luacheck: globals checkNumericalReductionTypeHelper getReductionType reductionHelper
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

-- 4E   function applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, sFocusBaseDice)
function customApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, sFocusBaseDice, ...)
    local rRoll = {};
    rRoll.sType = sRollType;
    rRoll.sDesc = sDamage;
    rRoll.nTotal = nTotal;
    rRoll.bSecret = bSecret;
    rRoll.sFocusBaseDice = sFocusBaseDice;
    ActionDamageDnDBCE.applyDamageBCE(rSource, rTarget, rRoll, ...);
end

function applyDamage(rSource, rTarget, rRoll, ...)
    applyDamageOriginal(rSource, rTarget, rRoll.bSecret, rRoll.sType, rRoll.sDesc, rRoll.nTotal, rRoll.sFocusBaseDice, ...);
end

function customGetDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
    local nDamageAdjust;
    local nReduce = 0;
    local bVulnerable, bResist, nHalf;
    local aReduce = ActionDamage4EBCE.getReductionType(rSource, rTarget, 'DMGR', rDamageOutput);

    for k, v in pairs(rDamageOutput.aDamageTypes) do
        -- Get individual damage types for each damage clause
        local aSrcDmgClauseTypes = {};
        local aTemp = StringManager.split(k, ',', true);
        for _, vType in ipairs(aTemp) do
            if vType ~= 'untyped' and vType ~= '' then
                table.insert(aSrcDmgClauseTypes, vType);
            end
        end
        local nLocalReduce = ActionDamage4EBCE.checkNumericalReductionType(aReduce, aSrcDmgClauseTypes, v);

        -- We need to do this nonsense because we need to reduce damagee before resist calculation
        if nLocalReduce > 0 then
            rDamageOutput.aDamageTypes[k] = rDamageOutput.aDamageTypes[k] - nLocalReduce;
            nDamage = nDamage - nLocalReduce;
        end
        nReduce = nReduce + nLocalReduce;
    end
    if (nReduce > 0) then
        table.insert(rDamageOutput.tNotifications, '[REDUCED:' .. tostring(nReduce) ..']');
    end
    nDamageAdjust, bVulnerable, bResist, nHalf = getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput);
    nDamageAdjust = nDamageAdjust - nReduce;
    return nDamageAdjust, bVulnerable, bResist, nHalf;
end

function checkNumericalReductionType(aReduction, aDmgType, nLimit)
    local nAdjust = 0;

    for _, sDmgType in pairs(aDmgType) do
        if nLimit then
            local nSpecificAdjust = ActionDamage4EBCE.checkNumericalReductionTypeHelper(aReduction[sDmgType], aDmgType, nLimit);
            nAdjust = nAdjust + nSpecificAdjust;
            local nGlobalAdjust = ActionDamage4EBCE.checkNumericalReductionTypeHelper(aReduction['all'], aDmgType,
                                                                                      nLimit - nSpecificAdjust);
            nAdjust = nAdjust + nGlobalAdjust;
        else
            nAdjust = nAdjust + ActionDamage4EBCE.checkNumericalReductionTypeHelper(aReduction[sDmgType], aDmgType);
            nAdjust = nAdjust + ActionDamage4EBCE.checkNumericalReductionTypeHelper(aReduction['all'], aDmgType);
        end
    end

    return nAdjust;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
    if not rMatch or (rMatch.mod == 0) then
        return 0;
    end

    local bMatch = false;
    if #rMatch.aNegatives > 0 then
        local bMatchNegative = false;
        for _, vNeg in pairs(rMatch.aNegatives) do
            if StringManager.contains(aDmgType, vNeg) then
                bMatchNegative = true;
                break
            end
        end
        if not bMatchNegative then
            bMatch = true;
        end
    else
        bMatch = true;
    end

    local nAdjust = 0;
    if bMatch then
        nAdjust = rMatch.mod - (rMatch.nApplied or 0);
        if nLimit then
            nAdjust = math.min(nAdjust, nLimit);
        end
        rMatch.nApplied = (rMatch.nApplied or 0) + nAdjust;
    end

    return nAdjust;
end

function getReductionType(rSource, rTarget, sEffectType, rDamageOutput)
    local tEffects = EffectManager4E.getEffectsByType(rTarget, sEffectType, rDamageOutput.tDamageFilter, rSource)
    local aFinal = {};
    local aDamageTypes = UtilityManager.copyDeep(rDamageOutput.aDamageTypes);
    local nTotalDamage = rDamageOutput.nVal;
    for _, tEffect in pairs(tEffects) do
        local rReduction = {};
        if tEffect.mod < 1 and tEffect.mod > 0 then
            local nReduce = math.floor(tEffect.mod * nTotalDamage);
            for _, sDescriptor in ipairs(tEffect.remainder) do
                if rDamageOutput.aDamageTypes[sDescriptor] then
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
        nTotalDamage = ActionDamage4EBCE.reductionHelper(aDamageTypes, aFinalCopy, nTotalDamage)
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
