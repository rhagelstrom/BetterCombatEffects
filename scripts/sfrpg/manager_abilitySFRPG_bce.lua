--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals AbilityManagerSFRPGBCE BCEManager
-- luacheck: globals onInit onClose customGetAbilityAction
local getAbilityAction = nil;

function onInit()
    getAbilityAction = AbilityManager.getAbilityAction;
    AbilityManager.getAbilityAction = customGetAbilityAction;
end

function onClose()
    AbilityManager.getAbilityAction = getAbilityAction;
end

function customGetAbilityAction(rActor, nodeAction, sSubRoll)
    local rAction = getAbilityAction(rActor, nodeAction, sSubRoll);
    if rAction and rAction.type == 'effect' then
        rAction.sChangeState = DB.getValue(nodeAction, 'changestate', '');
    end
    return rAction;
end
