--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local applyOngoingDamageBCE = nil
local applyOngoingRegenBCE = nil
local getDamageAdjust = nil

function onInit()
	if User.getRulesetName() == "4E" then 
		rest = CharManager.rest
		CharManager.rest = customRest

		getDamageAdjust = ActionDamage.getDamageAdjust
		ActionDamage.getDamageAdjust = customGetDamageAdjust

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
		ActionDamage.getDamageAdjust = getDamageAdjust
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


function checkNumericalReductionType(aReduction, aDmgType, nLimit)
	local nAdjust = 0;
	
	for _,sDmgType in pairs(aDmgType) do
		if nLimit then
			local nSpecificAdjust = checkNumericalReductionTypeHelper(aReduction[sDmgType], aDmgType, nLimit);
			nAdjust = nAdjust + nSpecificAdjust;
			local nGlobalAdjust = checkNumericalReductionTypeHelper(aReduction["all"], aDmgType, nLimit - nSpecificAdjust);
			nAdjust = nAdjust + nGlobalAdjust;
		else
			nAdjust = nAdjust + checkNumericalReductionTypeHelper(aReduction[sDmgType], aDmgType);
			nAdjust = nAdjust + checkNumericalReductionTypeHelper(aReduction["all"], aDmgType);
		end
	end
	
	return nAdjust;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
	if not rMatch or (rMatch.mod == 0) then
		return 0;
	end

	local bMatch = false;
	if #rMatch.aNegatives > 0 then
		local bMatchNegative = false;
		for _,vNeg in pairs(rMatch.aNegatives) do
			if StringManager.contains(aDmgType, vNeg) then
				bMatchNegative = true;
				break;
			end
		end
		if not bMatchNegative then
			bMatch = true;
		end
	else
		bMatch = true;
	end
	
	local nAdjust = 0;
	if bMatch then
		nAdjust = rMatch.mod - (rMatch.nApplied or 0);
		if nLimit then
			nAdjust = math.min(nAdjust, nLimit);
		end
		rMatch.nApplied = (rMatch.nApplied or 0) + nAdjust;
	end
	
	return nAdjust;
end

function getReductionType(rSource, rTarget, sEffectType, rDamageOutput)
	local aEffects = EffectManager4E.getEffectsByType(rTarget, sEffectType, rDamageOutput.tDamageFilter, rSource)
	local aFinal = {};
	for _,v in pairs(aEffects) do
		local rReduction = {};
		
		rReduction.mod = v.mod;
		rReduction.aNegatives = {};
		for _,vType in pairs(v.remainder) do
			if #vType > 1 and ((vType:sub(1,1) == "!") or (vType:sub(1,1) == "~")) then
				if StringManager.contains(DataCommon.dmgtypes, vType:sub(2)) then
					table.insert(rReduction.aNegatives, vType:sub(2));
				end
			end
		end

		for _,vType in pairs(v.remainder) do
			if vType ~= "untyped" and vType ~= "" and vType:sub(1,1) ~= "!" and vType:sub(1,1) ~= "~" then
				if StringManager.contains(DataCommon.dmgtypes, vType) or vType == "all" then
					aFinal[vType] = rReduction;
				end
			end
		end
	end
	
	return aFinal;
end

function customGetDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	local nDamageAdjust = 0
	local nReduce = 0
	local bVulnerable, bResist, nHalf
	local aReduce = getReductionType(rSource, rTarget, "DMGR", rDamageOutput)

	for k, v in pairs(rDamageOutput.aDamageTypes) do
		-- Get individual damage types for each damage clause
		local aSrcDmgClauseTypes = {}
		local aTemp = StringManager.split(k, ",", true)
		for _,vType in ipairs(aTemp) do
			if vType ~= "untyped" and vType ~= "" then
				table.insert(aSrcDmgClauseTypes, vType)
			end
		end
		local nLocalReduce = checkNumericalReductionType(aReduce, aSrcDmgClauseTypes, v)

		--We need to do this nonsense because we need to reduce damagee before resist calculation
		if nLocalReduce > 0 then
			rDamageOutput.aDamageTypes[k] = rDamageOutput.aDamageTypes[k] - nLocalReduce
			nDamage = nDamage - nLocalReduce
		end
		nReduce = nReduce + nLocalReduce
	end
	if (nReduce > 0) then
		table.insert(rDamageOutput.tNotifications, "[REDUCED]");
	end
	nDamageAdjust, bVulnerable, bResist, nHalf = getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	nDamageAdjust = nDamageAdjust - nReduce
	return nDamageAdjust, bVulnerable, bResist, nHalf
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
	ActionAttack.onAttack(rSource, rTarget, rRoll)
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
	local rActor = ActorManager.resolveActor(nodeCT)
	local rSource = nil
	if rNewEffect.sSource == nil or rNewEffect.sSource == "" then
		rSource = rActor
	else
		local nodeSource = DB.findNode(rNewEffect.sSource)
		rSource = ActorManager.resolveActor(nodeSource)
	end
	rNewEffect.sName = EffectManager4E.evalEffect(rSource, rNewEffect.sName)

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