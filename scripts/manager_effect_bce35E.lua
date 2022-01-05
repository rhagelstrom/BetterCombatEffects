--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local rest = nil
local charRest = nil

function onInit()
	if User.getRulesetName() == "3.5E" or  User.getRulesetName() == "PFRPG" then 
	
		rest = CombatManager2.rest
		CombatManager2.rest = customRest
		charRest = CharManager.rest
		CharManager.rest = customCharRest

		EffectsManagerBCEG.registerBCETag("SAVEA", EffectsManagerBCEG.aBCEOneShotOptions)

		EffectsManagerBCEG.registerBCETag("SAVES", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SAVEE", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SAVEADD", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SAVEADDP", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SAVEDMG", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SAVEONDMG", EffectsManagerBCEG.aBCEDefaultOptions)


		EffectsManagerBCEG.setCustomProcessTurnStart(processEffectTurnStart35E)
		EffectsManagerBCEG.setCustomProcessTurnEnd(processEffectTurnEnd35E)
		EffectsManagerBCEG.setCustomPreAddEffect(addEffectPre35E)
		EffectsManagerBCEG.setCustomPostAddEffect(addEffectPost35E)
		EffectsManagerBCEGDND.setProcessEffectOnDamage(EffectsManagerBCEG5E.onDamage)

		ActionsManager.registerResultHandler("savebce", onSaveRollHandler35E)
		ActionsManager.registerModHandler("savebce", onModSaveHandler)

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)
	
	end
end

function onClose()
	if User.getRulesetName() == "3.5E" or  User.getRulesetName() == "PFRPG" then 
		CombatManager2.rest = rest
		CharManager.rest = charRest
		ActionsManager.unregisterResultHandler("savebce")
		ActionsManager.unregisterModHandler("savebce")
		EffectsManagerBCEG.removeCustomProcessTurnStart(processEffectTurnStart35E)
		EffectsManagerBCEG.removeCustomProcessTurnEnd(processEffectTurnEnd35E)
		EffectsManagerBCEG.removeCustomPreAddEffect(addEffectPre35E)
		EffectsManagerBCEG.removeCustomPostAddEffect(addEffectPost35E)

	end
end

-- This is likely where we will conflict with any other extensions
function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
	local sDuplicateMsg = nil
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return sDuplicateMsg
	end
	if  not rEffect.sName:match("STACK") then
		for k, nodeEffect in pairs(nodeEffectsList.getChildren()) do
			if (DB.getValue(nodeEffect, "label", "") == rEffect.sName) and
					(DB.getValue(nodeEffect, "init", 0) == rEffect.nInit) and
					(DB.getValue(nodeEffect, "duration", 0) == rEffect.nDuration) and
					(DB.getValue(nodeEffect,"source_name", "") == rEffect.sSource) then
				sDuplicateMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rEffect.sName, Interface.getString("effect_status_exists"))
				break
			end
		end
	end
	return sDuplicateMsg
end

function customCharRest(nodeChar)

	EffectsManagerBCEGDND.customRest(nodeChar, true, nil)
	charRest(nodeChar)
end

function customRest(bShort)
    local bLong = not bShort
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		local sClass, sRecord = DB.getValue(v, "link", "", "");
		if sClass == "charsheet" and sRecord ~= "" then
			local nodePC = DB.findNode(sRecord);
			if nodePC then
				EffectsManagerBCEGDND.customRest(nodePC, bLong, nil)
			end
		end
	end
	rest(bShort)
end

function replaceSaveDC(rNewEffect, rActor)
	-- TODO
end

function processEffectTurnStart35E(sourceNodeCT, nodeCT, nodeEffect)
    return EffectsManagerBCEG5E.processEffectTurnStart5E(sourceNodeCT, nodeCT, nodeEffect)
end

function processEffectTurnEnd35E(sourceNodeCT, nodeCT, nodeEffect)
    return EffectsManagerBCEG5E.processEffectTurnEnd5E(sourceNodeCT, nodeCT, nodeEffect)
end

function addEffectPre35E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	local rSource = nil
	if rNewEffect.sSource ~= nil and rNewEffect.sSource ~= "" then
		local nodeSource = DB.findNode(rNewEffect.sSource)
		rSource = ActorManager.resolveActor(nodeSource)
	else
		rSource = rActor
	end
	rNewEffect.sName = EffectManager35E.evalEffect(rSource, rNewEffect.sName)
	EffectsManagerBCEG5E.replaceSaveDC(rNewEffect, rSource)
	return true
end

function addEffectPost35E(sUser, sIdentity, nodeCT, rNewEffect)
    return EffectsManagerBCEG5E.addEffectPost5E(sUser, sIdentity, nodeCT, rNewEffect)
end

function onSaveRollHandler35E(rSource, rTarget, rRoll)
	return EffectsManagerBCEG5E.onSaveRollHandler5E(rSource, rTarget, rRoll)
end

function saveEffect(nodeEffect, nodeTarget, sSaveBCE) -- Effect, Node which this effect is on, BCE String
    return EffectsManagerBCEG5E.saveEffect(nodeEffect, nodeTarget, sSaveBCE)
end

-- Needed for ongoing save. Have to flip source/target to get the correct mods
function onModSaveHandler(rSource, rTarget, rRoll)
	ActionSave.modSave(rTarget, rSource, rRoll);
end