--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals SpellManagerSFRPGBCE BCEManager
-- luacheck: globals onInit onClose customGetSpellAction
local getSpellAction = nil;

function onInit()
    getSpellAction = SpellManager.getSpellAction;
    SpellManager.getSpellAction = customGetSpellAction;
end

function onClose()
    SpellManager.getSpellAction = getSpellAction;
end

function customGetSpellAction(rActor, nodeAction, sSubRoll)
    BCEManager.chat('customGetSpellAction : ');
    local rAction = getSpellAction(rActor, nodeAction, sSubRoll);
    if rAction and rAction.type == 'effect' then
        rAction.sChangeState = DB.getValue(nodeAction, 'changestate', '');
    end
    return rAction;
end
