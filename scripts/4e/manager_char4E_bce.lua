--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
--
-- luacheck: globals CharManager4EBCE BCEManager
-- luacheck: globals onInit onClose customGetEffectStructures moddedOnPowerAbilityAction
local getEffectStructures = nil;
local onPowerAbilityAction = nil;

function onInit()
    getEffectStructures = CharManager.getEffectStructures;
    onPowerAbilityAction = CharManager.onPowerAbilityAction;

    CharManager.onPowerAbilityAction = moddedOnPowerAbilityAction;
    CharManager.getEffectStructures = customGetEffectStructures;
end

function onClose()
    CharManager.getEffectStructures = getEffectStructures;
    CharManager.onPowerAbilityAction = onPowerAbilityAction;
end

function customGetEffectStructures(nodeAbility)
    local rActor, rEffect = getEffectStructures(nodeAbility);
    rEffect.sChangeState = DB.getValue(nodeAbility, 'changestate', '');
    return rActor, rEffect;
end

function moddedOnPowerAbilityAction(draginfo, nodeAbility, subtype)
    local sAbilityType = DB.getValue(nodeAbility, 'type', '');
    if sAbilityType == 'attack' then
        if subtype == 'damage' then
            local rActor, rAction, rFocus = CharManager.getAdvancedRollStructures('damage', nodeAbility,
                                                                                  CharManager.getPowerFocus(nodeAbility));
            ActionDamage.performRoll(draginfo, rActor, rAction, rFocus);
            return true;
        end
        local rActor, rAction, rFocus = CharManager.getAdvancedRollStructures('attack', nodeAbility,
                                                                              CharManager.getPowerFocus(nodeAbility));
        ActionAttack.performRoll(draginfo, rActor, rAction, rFocus);
        return true;
    elseif sAbilityType == 'heal' then
        local rActor, rAction, rFocus = CharManager.getAdvancedRollStructures('heal', nodeAbility, nil);
        ActionHeal.performRoll(draginfo, rActor, rAction, rFocus);
        return true;
    elseif sAbilityType == 'effect' then
        local rActor, rEffect = CharManager.getEffectStructures(nodeAbility);
        return ActionEffect.performRoll(draginfo, rActor, rEffect);
    end
    return false;
end
