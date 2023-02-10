--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local getDamageAdjust = nil;
applyDamage = nil;

function onInit()
    getDamageAdjust = ActionDamage.getDamageAdjust;
    applyDamage = ActionDamage.applyDamage;
    ActionDamage.getDamageAdjust = customGetDamageAdjust;
    ActionDamage.applyDamage = customApplyDamage;
end

function onClose()
    ActionDamage.getDamageAdjust = getDamageAdjust;
    ActionDamage.applyDamage = applyDamage;
end

function customApplyDamage(rSource, rTarget, rRoll, ...)
    ActionDamageDnDBCE.applyDamageBCE(rSource, rTarget, rRoll, ...)
end

function customGetDamageAdjust(rSource, rTarget, nDamage, rDamageOutput, ...)
    BCEManager.chat('customGetDamageAdjust : ');
    local nReduce = 0;
    local aReduce = getReductionType(rSource, rTarget, 'DMGR', rDamageOutput);

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
    for _, v in pairs(tEffects) do
        local rReduction = {};

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
