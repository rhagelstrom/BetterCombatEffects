--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local applyOngoingDamageBCE = nil

function onInit()
	if User.getRulesetName() == "4E" then 
		rest = CharManager.rest
		CharManager.rest = customRest

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart4E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd4E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre4E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost4E)

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)
		applyOngoingDamageBCE = EffectsManagerBCEDND.applyOngoingDamage
		EffectsManagerBCEDND.applyOngoingDamage = applyOngoingDamage

        --No save support yet for 4E or is it really not that useful?
--		ActionsManager.registerResultHandler("savebce", onSaveRollHandler35E)
--		ActionsManager.registerModHandler("savebce", onModSaveHandler)
	
	end
end

function onClose()
	if User.getRulesetName() == "4E" then 
		CharManager.rest = rest
--		ActionsManager.unregisterResultHandler("savebce")
--		ActionsManager.unregisterModHandler("savebce")
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart4E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd4E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre4E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost4E)
		EffectsManagerBCEDND.applyOngoingDamage = applyOngoingDamageBCE

	end
end

function customRest(nodeActor, bLong, bMilestone)
	EffectsManagerBCEDND.customRest(nodeActor,  bLong, nil)
	rest(nodeActor, bLong, bMilestone)
end

function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
	local sDuplicateMsg = nil; 
	sDuplicateMsg = EffectManager4E.onEffectAddIgnoreCheck(nodeCT, rEffect)
	if sDuplicateMsg ~= nil and rEffect.sName:match("STACK") and sDuplicateMsg:match("ALREADY EXISTS") then
		sDuplicateMsg = nil
	end
	return sDuplicateMsg
end

-- 4E is different enough that we need need to handle ongoing damage here
function applyOngoingDamage(rSource, rTarget, nodeEffect, bHalf)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local rAction = {}
	rAction.label =  ""
	rAction.clauses = {}
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if  rEffectComp.type == "DMGOE" or rEffectComp.type == "SDMGOE" or rEffectComp.type == "SDMGOS" then
			local nodeActor = ActorManager.getCTNode(rSource)		
			EffectManager4E.applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp);
		end
	end
end

function processEffectTurnStart4E(sourceNodeCT, nodeCT, nodeEffect)
    return true
end

function processEffectTurnEnd4E(sourceNodeCT, nodeCT, nodeEffect)
    return true
end

function addEffectPre4E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    return true
end

function addEffectPost4E(sUser, sIdentity, nodeCT, rNewEffect)
    return true
end

function onSaveRollHandler4E(rSource, rTarget, rRoll)
    --placeholder
    return true
end

function saveEffect(nodeEffect, nodeTarget, sSaveBCE)
    --placeholder
    return true
end

-- Needed for ongoing save. Have to flip source/target to get the correct mods
--function onModSaveHandler(rSource, rTarget, rRoll)
--	ActionSave.modSave(rTarget, rSource, rRoll);
--end