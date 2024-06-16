--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals ActionDamage4EBCE BCEManager ActionDamageDnDBCE
-- luacheck: globals onInit onClose customApplyDamage applyDamage customGetDamageAdjust checkNumericalReductionType
-- luacheck: globals checkNumericalReductionTypeHelper getReductionType
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
        table.insert(rDamageOutput.tNotifications, '[REDUCED]');
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
    for _, v in pairs(tEffects) do
        local rReduction = {};
        if v.mod < 1 and v.mod > 0 then
            v.mod = math.max(v.mod * rDamageOutput.nVal)
        end
        rReduction.mod = v.mod;
        rReduction.aNegatives = {};
        for _, vType in pairs(v.remainder) do
            if #vType > 1 and ((vType:sub(1, 1) == '!') or (vType:sub(1, 1) == '~')) then
                if StringManager.contains(DataCommon.dmgtypes, vType:sub(2)) then
                    table.insert(rReduction.aNegatives, vType:sub(2));
                end
            end
        end

        for _, vType in pairs(v.remainder) do
            if vType ~= 'untyped' and vType ~= '' and vType:sub(1, 1) ~= '!' and vType:sub(1, 1) ~= '~' then
                if StringManager.contains(DataCommon.dmgtypes, vType) or vType == 'all' then
                    if aFinal[vType] then
                        rReduction.mod = rReduction.mod + aFinal[vType].mod;
                    end
                    aFinal[vType] = rReduction;
                end
            end
        end
    end
    return aFinal;
end
