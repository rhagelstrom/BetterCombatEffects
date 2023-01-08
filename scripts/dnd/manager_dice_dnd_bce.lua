--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local convertStringToDice = nil;

function onInit()
    convertStringToDice = DiceManager.convertStringToDice;
    DiceManager.convertStringToDice = customConvertStringToDice;
end

function onClose()
    DiceManager.convertStringToDice = convertStringToDice;
end

function customConvertStringToDice(s)
    BCEManager.chat("customConvertStringToDice : ");
    local tDice = {};
    local nMod = 0;
    local tTerms = DiceManager.convertDiceStringToTerms(s);
    for _, vTerm in ipairs(tTerms) do
        if StringManager.isNumberString(vTerm) then
            nMod = nMod + (tonumber(vTerm) or 0);
        else
            local nDieCount, sDieType = DiceManager.parseDiceTerm(vTerm);
            if sDieType then
                for i = 1, nDieCount do
                    table.insert(tDice, sDieType);
                end
                -- next two lines enable "-X" ability replacement
            elseif vTerm and vTerm == "-X" then
                nMod = 0;
            end
        end
    end
    return tDice, nMod;
end

-- TODO This probably needs some love or removal
function isDie(sEffect)
    BCEManager.chat("isDie : ");
    local rRoll = {};
    local tEffectComps = EffectManager.parseEffect(sEffect);
    for _, sEffectComp in ipairs(tEffectComps) do
        local aWords = StringManager.parseWords(sEffectComp, "%.%[%]%(%):");
        if #aWords > 0 then
            local sType = aWords[1]:match("^([^:]+):");
            -- Only roll dice for ability score mods
            if sType and
                (sType == "STR" or sType == "DEX" or sType == "CON" or sType == "INT" or sType == "WIS" or sType ==
                    "CHA" or sType == "DMGR") then
                local sValueCheck;
                local sTypeRemainder = aWords[1]:sub(#sType + 2);
                if sTypeRemainder == "" then
                    sValueCheck = aWords[2] or "";
                else
                    sValueCheck = sTypeRemainder;
                end
                -- Check to see if negative
                if sValueCheck:match("%-^[d%.%dF%+%-]+$") then
                    sValueCheck = sValueCheck:gsub("%-", "", 1);
                end
                if StringManager.isDiceString(sValueCheck) then
                    local aDice, nMod = StringManager.convertStringToDice(sValueCheck);
                    rRoll.sType = "effectbce";
                    rRoll.sDesc = "[EFFECT " .. sEffect .. "] ";
                    rRoll.aDice = aDice;
                    rRoll.sSubType = sType;
                    rRoll.nMod = nMod;
                    rRoll.sEffect = sEffect;
                    rRoll.sValue = sValueCheck;
                end
            end
        end
    end
    return rRoll
end
