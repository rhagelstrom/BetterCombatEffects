--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local RulesetEffectManager = nil;
local applyDamage = nil;

local fProcessEffectOnDamage;

function onInit()
    -- bAdvancedEffects = BCEManager.hasExtension("AdvancedEffects") or BCEManager.hasExtension("FG-PFRPG-Advanced-Effects");

    RulesetEffectManager = BCEManager.getRulesetEffectManager();

    applyDamage = ActionDamage.applyDamage;
    ActionDamage.applyDamage = customApplyDamage;

    OptionsManager.registerOption2("TEMP_IS_DAMAGE", false, "option_Better_Combat_Effects", "option_Temp_Is_Damage",
        "option_entry_cycler", {
            labels = "option_val_off",
            values = "off",
            baselabel = "option_val_on",
            baseval = "on",
            default = "on"
        });
end

function onClose()
    if Session.IsHost then
        ActionDamage.applyDamage = applyDamage;
    end
end

function onTabletopInit()
    EffectManagerBCE.registerEffectCompType("DMGAT", {
        bIgnoreDisabledCheck = true
    });
    EffectManagerBCE.registerEffectCompType("TDMGADDT", {
        bIgnoreOtherFilter = true
    });
    EffectManagerBCE.registerEffectCompType("TDMGADDS", {
        bIgnoreOtherFilter = true
    });
    EffectManagerBCE.registerEffectCompType("SDMGADDT", {
        bIgnoreOtherFilter = true
    });
    EffectManagerBCE.registerEffectCompType("SDMGADDS", {
        bIgnoreOtherFilter = true
    });
end

function setProcessEffectOnDamage(ProcessEffectOnDamage)
    fProcessEffectOnDamage = ProcessEffectOnDamage
end

-- 3.5E  function applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)
-- 5E   function customApplyDamage(rSource, rTarget, rRoll, ...)
function customApplyDamage(rSource, rTarget, rRoll, ...)
    BCEManager.chat("customApplyDamage : ");
    if rRoll.sType ~= "damage" then
        return applyDamage(rSource, rTarget, rRoll, ...);
    end
    local nodeTarget = ActorManager.getCTNode(rTarget);
    local nodeSource = ActorManager.getCTNode(rSource);
    if User.getRulesetName() == "5E" then
        -- Get the advanced effects info we snuck on the roll from the client
        rSource.itemPath = rRoll.itemPath;
        rSource.ammoPath = rRoll.ammoPath;
        rRoll.itemPath = nil;
        rRoll.ammoPath = nil;
    end
    -- save off temp hp and wounds before damage
    local nTempHPPrev, nWoundsPrev = ActionDamageDnDBCE.getTempHPAndWounds(rTarget);
    applyDamage(rSource, rTarget, rRoll, ...);

    -- get temp hp and wounds after damage
    local nTempHP, nWounds = ActionDamageDnDBCE.getTempHPAndWounds(rTarget);

    if OptionsManager.isOption("TEMP_IS_DAMAGE", "on") then
        -- If no damage was applied then return
        if nWoundsPrev >= nWounds and nTempHPPrev <= nTempHP then
            return;
        end
        -- return if no damage was applied then return
    elseif nWoundsPrev >= nWounds then
        return;
    end

    local aTags = {"DMGAT", "DMGDT", "DMGRT"};
    -- We need to do the activate, deactivate and remove first as a single action in order to get the rest
    -- of the tags to be applied as expected
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag, nil, rSource);
        for _, tEffect in pairs(tMatch) do
            if sTag == "DMGAT" then
                BCEManager.chat("ACTIVATE: ");
                BCEManager.modifyEffect(tEffect.sEffectNode, "Activate");
            elseif sTag == "DMGDT" then
                BCEManager.chat("DEACTIVATE: ");
                BCEManager.modifyEffect(tEffect.sEffectNode, "Deactivate");
            elseif sTag == "DMGRT" then
                BCEManager.chat("REMOVE: ");
                BCEManager.modifyEffect(tEffect.sEffectNode, "Remove");
            end
        end
    end
    if (fProcessEffectOnDamage) then
        fProcessEffectOnDamage(rSource, rTarget, rRoll, ...);
    end

    aTags = {"TDMGADDT", "TDMGADDS"};
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rTarget, sTag, nil, rSource);
        for _, tEffect in pairs(tMatch) do
            local rEffect = BCEManager.matchEffect(tEffect.remainder[1]);
            if next(rEffect) then
                -- rEffect.sSource = DB.getValue(nodeTarget,"source_name", rTarget.sCTNode);
                rEffect.sSource = nodeTarget.getPath();
                rEffect.nInit = DB.getValue(nodeTarget, "initresult", 0);
                if sTag == "TDMGADDT" then
                    BCEManager.chat("TDMGADDT: ");
                    BCEManager.notifyAddEffect(nodeTarget, rEffect, tEffect.remainder[1]);
                elseif sTag == "TDMGADDS" then
                    BCEManager.chat("TDMGADDs: ");
                    BCEManager.notifyAddEffect(nodeSource, rEffect, tEffect.remainder[1]);
                end
            end
        end
    end
    aTags = {"SDMGADDT", "SDMGADDS"};
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag, nil, rTarget);
        for _, tEffect in pairs(tMatch) do
            local rEffect = BCEManager.matchEffect(tEffect.remainder[1]);
            if next(rEffect) then
                rEffect.sSource = nodeSource.getPath();
                rEffect.nInit = DB.getValue(nodeSource, "initresult", 0);
                if sTag == "SDMGADDT" then
                    BCEManager.chat("SDMGADDT: ");

                    BCEManager.notifyAddEffect(nodeTarget, rEffect, tEffect.remainder[1]);
                elseif sTag == "SDMGADDS" then
                    BCEManager.chat("SDMGADDS: ");
                    BCEManager.notifyAddEffect(nodeSource, rEffect, tEffect.remainder[1]);
                end
            end
        end
    end
end

function getTempHPAndWounds(rTarget)
    BCEManager.chat("getTempHPAndWounds : ");
    local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
    local nTempHP = 0;
    local nWounds = 0;

    if not nodeTarget then
        return nTempHP, nWounds;
    end

    if sTargetNodeType == "pc" then
        nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0);
        nWounds = DB.getValue(nodeTarget, "hp.wounds", 0);
    elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
        nTempHP = DB.getValue(nodeTarget, "hptemp", 0);
        nWounds = DB.getValue(nodeTarget, "wounds", 0);
    end
    return nTempHP, nWounds;
end
