--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local outputResult = nil;
local bAdvancedEffects = nil;
local performMultiAction = nil;

function onInit()
    bAdvancedEffects = BCEManager.hasExtension("AdvancedEffects") or
                           BCEManager.hasExtension("FG-PFRPG-Advanced-Effects");

    outputResult = ActionsManager.outputResult;
    ActionsManager.outputResult = customOutputResult;

    if bAdvancedEffects then
        performMultiAction = ActionsManager.performMultiAction;
        ActionsManager.performMultiAction = customPerformMultiAction;
    end

end

function onClose()
    ActionsManager.outputResult = outputResult;
    if bAdvancedEffects then
        ActionsManager.performMultiAction = performMultiAction;
    end
end

function customOutputResult(bTower, rSource, rTarget, rMessageGM, rMessagePlayer)
    BCEManager.chat("customOutputResult : ");
    if rMessageGM.text:gmatch("%w+")() == "Save" then
        rMessageGM.icon = "bce_save";
    end
    if rMessagePlayer.text:gmatch("%w+")() == "Save" then
        rMessagePlayer.icon = "bce_save";
    end
    outputResult(bTower, rSource, rTarget, rMessageGM, rMessagePlayer);
end

-- Advanced Effects
function customPerformMultiAction(draginfo, rActor, sType, rRolls)
    BCEManager.chat("customPerformMultiAction : ");
    if rActor then
        rRolls[1].itemPath = rActor.itemPath;
        rRolls[1].ammoPath = rActor.ammoPath;
    end
    return performMultiAction(draginfo, rActor, sType, rRolls);
end
-- End Advanced Effects
