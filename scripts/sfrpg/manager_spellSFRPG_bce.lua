--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
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
