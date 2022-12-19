--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local bMadNomadCharSheetEffectDisplay = false

function onInit()
    bMadNomadCharSheetEffectDisplay = BCEManager.hasExtension("MNM Charsheet Effects Display");
end

function onClose()
end

-- Any effect that modifies ability score and is coded with -X
-- has the -X replaced with the targets ability score and then calculated
function replaceAbilityScores(rNewEffect, rActor)
    BCEManager.chat("replaceAbilityScores : ");
    -- check contains -X to see if this is interesting enough to continue
    if rNewEffect.sName:match("%-X") then
        local tEffectComps = EffectManager.parseEffect(rNewEffect.sName);
        for _, sEffectComp in ipairs(tEffectComps) do
            local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
            local nAbility = 0;
            if rEffectComp.type == "STR" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "STRMNM") then
                nAbility = RulesetActorManager.getAbilityScore(rActor, "strength");
            elseif rEffectComp.type == "DEX" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "DEXMNM") then
                nAbility = RulesetActorManager.getAbilityScore(rActor, "dexterity");
            elseif rEffectComp.type == "CON" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "CONMNM") then
                nAbility = RulesetActorManager.getAbilityScore(rActor, "constitution");
            elseif rEffectComp.type == "INT" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "INTMNM") then
                nAbility = RulesetActorManager.getAbilityScore(rActor, "intelligence");
            elseif rEffectComp.type == "WIS" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "WISMNM") then
                nAbility = RulesetActorManager.getAbilityScore(rActor, "wisdom");
            elseif rEffectComp.type == "CHA" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "CHAMNM") then
                nAbility = RulesetActorManager.getAbilityScore(rActor, "charisma");
            end

            if (rEffectComp.remainder[1]:match("%-X")) then
                local sMod = rEffectComp.remainder[1]:gsub("%-X", "");
                local nMod = tonumber(sMod);
                if nMod then
                    if (nMod > nAbility) then
                        nAbility = nMod - nAbility;
                    else
                        nAbility = 0;
                    end
                    -- Exception for Mad Nomads effects display extension
                    local sReplace = rEffectComp.type .. ":" .. tostring(nAbility);
                    local sMatch = rEffectComp.type .. ":%s-%d+%-X";
                    rNewEffect.sName = rNewEffect.sName:gsub(sMatch, sReplace);
                end
            end
        end
    end
end
