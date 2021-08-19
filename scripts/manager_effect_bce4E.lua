--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local applyOngoingDamageBCE = nil
local applyOngoingRegenBCE = nil

function onInit()
	if User.getRulesetName() == "4E" then 
		rest = CharManager.rest
		CharManager.rest = customRest

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart4E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd4E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre4E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost4E)
		ActionsManager.registerResultHandler("attack", onAttack4E)

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)
		applyOngoingDamageBCE = EffectsManagerBCEDND.applyOngoingDamage
		EffectsManagerBCEDND.applyOngoingDamage = applyOngoingDamage
		applyOngoingRegenBCE = EffectsManagerBCEDND.applyOngoingRegen
		EffectsManagerBCEDND.applyOngoingRegen = applyOngoingRegen

		EffectsManagerBCE.setCustomProcessEffect(processEffect)
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
		EffectsManagerBCEDND.applyOngoingRegen = applyOngoingRegenBCE
		EffectsManagerBCE.removeCustomProcessEffect(processEffect)
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

function onAttack4E(rSource, rTarget, rRoll)
	local nodeSource = CombatManager.getCTFromNode(rSource.sCTNode)
	if nodeSource ~= nil then
		for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
			local sEffectSource = DB.getValue(nodeEffect, "source_name", "")	
			if EffectsManagerBCE.processEffect(rSource ,nodeEffect, "ATKDS", rTarget) and sEffectSource == rTarget.sCTNode then	
				EffectsManagerBCE.modifyEffect(nodeEffect, "Deactivate")
			end
		end
	end
	if AmmunitionManager then
		AmmunitionManager.onAttack_4e(rSource, rTarget, rRoll)
	else
		ActionAttack.onAttack(rSource, rTarget, rRoll)
	end
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
			local nodeActor = ActorManager.getCTNode(rTarget)
			if EffectManager.isTargetedEffect(nodeEffect) then
				local aTargets = EffectManager.getEffectTargets(nodeEffect)
				for _,nodeTarget in ipairs(aTargets) do
					EffectManager4E.applyOngoingDamageAdjustment(nodeTarget, nodeEffect, rEffectComp)
				end
			else
				EffectManager4E.applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp)
			end
		end
	end
end

-- 4E is different enough that we need need to handle ongoing damage here
function applyOngoingRegen(rSource, rTarget, nodeEffect, bAdd)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local rAction = {}
	rAction.label =  ""
	rAction.clauses = {}
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if (rEffectComp.type == "REGENA" and bAdd == true) or ( bAdd == false and (rEffectComp.type == "REGENE" or rEffectComp.type == "SREGENS" or rEffectComp.type == "SREGENE")) then
			rEffectComp.type = "REGEN"
			local nodeActor = ActorManager.getCTNode(rTarget)
			if EffectManager.isTargetedEffect(nodeEffect) then
				local aTargets = EffectManager.getEffectTargets(nodeEffect)
				for _,nodeTarget in ipairs(aTargets) do
					EffectManager4E.applyOngoingDamageAdjustment(nodeTarget, nodeEffect, rEffectComp)
				end
			else
				EffectManager4E.applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp)
			end
		end
	end
end


--Do sanity checks to see if we should process this effect any further
-- 4E handles conditionals different so it easier just to do all this here
function processEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	-- is there a conditional that prevents us from processing
	local aEffectComps = EffectManager.parseEffect(sEffect)
	for _,sEffectComp in ipairs(aEffectComps) do -- Check conditionals
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "IF" then
			if not EffectManager4E.checkConditional(rSource, nodeEffect, rEffectComp, rTarget) then
				return false
			end
		elseif rEffectComp.type == "IFT" then
			if not EffectManager4E.checkConditional(rSource, nodeEffect, rEffectComp, rTarget) then
				return false
			end
		end
	end	
	return true -- Everything looks good to continue processing
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
	local rActor = ActorManager.resolveActor(nodeCT)
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		if (DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) then
			local nodeSource = nodeCT
			if rNewEffect.sSource ~= nil then
				nodeSource = DB.findNode(rNewEffect.sSource)
			end
			local rSource = ActorManager.resolveActor(nodeSource)
			local rTarget = rActor
			if EffectsManagerBCE.processEffect(rSource, nodeEffect, "REGENA", rTarget) then
				EffectsManagerBCEDND.applyOngoingRegen(rSource, rTarget, nodeEffect, true)
			end
		end
	end
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