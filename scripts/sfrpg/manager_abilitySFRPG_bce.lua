--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
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
