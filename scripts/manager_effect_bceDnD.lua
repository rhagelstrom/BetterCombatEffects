--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local RulesetEffectManager = nil
local RulesetActorManager = nil
local onDamage = nil
local messageDamage = nil
local fProcessEffectOnDamage = nil
local bMadNomadCharSheetEffectDisplay = false

function setProcessEffectOnDamage(ProcessEffectOnDamage)
	fProcessEffectOnDamage = ProcessEffectOnDamage
end

function customRest(nodeActor, bLong, bMilestone)
--	local nodeCT = ActorManager.getCTNode(nodeActor)
	local rSource = ActorManager.resolveActor(nodeActor)
	local tMatch = {}

	local aTags = {"RESTS"}
	if bLong == true then
		table.insert(aTags, "RESTL")
		if User.getRulesetName() == "5E" then
			table.insert(aTags, "SAVERESTL")
		end
	end

	tMatch = EffectsManagerBCEG.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "RESTL" or tEffect.sTag == "RESTS" then
			EffectsManagerBCEG.modifyEffect(tEffect.nodeCT, "Remove")
		elseif tEffect.sTag == "SAVERESTL" then
			EffectsManagerBCEG5E.saveEffect(rSource, rSource, tEffect)
		end
	end
end

function onEffectRollHandler(rSource, rTarget, rRoll)
	if not Session.IsHost then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectclient"))
		return
	end
	local nodeSource = ActorManager.getCTNode(rSource)	
	local sEffect = ""
	local sEffectOriginal = ""

	if rRoll.subtype and rRoll.subtype == "DUR" and type(DB.findNode(rRoll.nodeEffectCT)) == "databasenode" then
		local nResult = tonumber(ActionsManager.total(rRoll))
		if rRoll.sUnits == "minute" then
			nResult = nResult * 10
		elseif rRoll.sUnits == "hour" then
			nResult = nResult * 10 * 60
		elseif rRoll.sUnits == "day" then
			nResult = nResult * 10 * 60 * 24
		end
		
		local nodeCT = DB.findNode(rRoll.nodeEffectCT)
		DB.setValue(nodeCT, "duration", "number", nResult)
		EffectsManagerBCEG.updateEffect(nodeSource,nodeCT, rRoll.sEffect)
		return
	end

	for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
		sEffect = DB.getValue(nodeEffect, "label", "")
		if sEffect == rRoll.sEffect then
			sEffectOriginal = sEffect
			local nResult = tonumber(ActionsManager.total(rRoll))
			local sResult = tostring(nResult)
			local sValue = rRoll.sValue
			local sReverseValue = string.reverse(sValue)
			---Needed to get creative with patern matching - to correctly process
			-- if the negative is to total, or do we have a negative modifier
			if sValue:match("%+%d+") then
				sValue = sValue:gsub("%+%d+", "") .. "%+%d+"
			elseif  (sReverseValue:match("%d+%-") and rRoll.nMod ~= 0) then
				sReverseValue = sReverseValue:gsub("%d+%-", "", 1)
				sValue = "%-?" .. string.reverse(sReverseValue) .. "%-*%d?"
			elseif (sReverseValue:match("%d+%-") and rRoll.nMod == 0) then
				sValue = "%-*" .. sValue:gsub("%-", "")
			end
			sEffect = sEffect:gsub(sValue, sResult)
			if Session.IsHost then
				DB.setValue(nodeEffect, "label", "string", sEffect)
			end
			break
		end
	end
end

function addEffectPost(sUser, sIdentity, nodeCT, rNewEffect)
	local rTarget = ActorManager.resolveActor(nodeCT)
	local rSource = {}
	if rNewEffect.sSource == "" then
		rSource = rTarget
	else
		rSource = ActorManager.resolveActor(rNewEffect.sSource)
	end
	local tMatch = {}
	local aTags = {"REGENA", "TREGENA", "DMGA", "DUR"}

	tMatch = EffectsManagerBCEG.getEffects(rTarget, aTags, rTarget)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "REGENA" then
				applyOngoingRegen(rSource, rTarget, tEffect.rEffectComp, false)
		elseif tEffect.sTag == "TREGENA" then
			applyOngoingRegen(rSource, rTarget, tEffect.rEffectComp, true)
		elseif tEffect.sTag == "DMGA" then
			applyOngoingDamage(rSource, rTarget, tEffect.rEffectComp)
		elseif tEffect.sTag == "DUR" and type(tEffect.nodeCT) == "databasenode" then
			local sLabel = DB.getValue(tEffect.nodeCT, "label", "")
			local rRoll = {}
			rRoll.sType = "effectbce"
			rRoll.sDesc = "[EFFECT " .. sLabel .. "] "
			rRoll.aDice = tEffect.rEffectComp.dice
			rRoll.nMod = tonumber(tEffect.rEffectComp.mod)
			rRoll.sEffect = sLabel
			rRoll.subtype = "DUR"
			rRoll.rActor = rTarget
			rRoll.sUnits = rNewEffect.sUnits

			rRoll.nodeEffectCT = tEffect.nodeCT.getPath()
			if tEffect.nGMOnly == 1 then
				rRoll.bSecret = true
			else
				rRoll.bSecret = false
			end
			ActionsManager.performAction(nil, rTarget, rRoll)		
		end
	end
	return true
end

function applyOngoingDamage(rSource, rTarget, rEffectComp, bHalf)
	local rAction = {}
	local aClause = {}
	rAction.clauses = {}
	
	aClause.dice  = rEffectComp.dice;
	aClause.modifier = rEffectComp.mod
	aClause.dmgtype = string.lower(table.concat(rEffectComp.remainder, ","))
	table.insert(rAction.clauses, aClause)

	rAction.label = "Ongoing Effect"
	
	local rRoll = ActionDamage.getRoll(rTarget, rAction)
	if  bHalf then
		rRoll.sDesc = rRoll.sDesc .. " [HALF]"
	end
	ActionsManager.actionDirect(rSource, "damage", {rRoll}, {{rTarget}})
end

function applyOngoingRegen(rSource, rTarget, rEffectComp, bTemp)
	local rAction = {}
	local aClause = {}
	rAction.clauses = {}

	aClause.dice  = rEffectComp.dice;
	aClause.modifier = rEffectComp.mod
	table.insert(rAction.clauses, aClause)

	if bTemp == true then
		rAction.label = "Ongoing Temporary Hitpoints"
		rAction.subtype = "temp"
	else
		rAction.label = "Ongoing Regeneration"
	end

	local rRoll = ActionHeal.getRoll(rTarget, rAction)
	ActionsManager.actionDirect(rSource, "heal", {rRoll}, {{rTarget}})
end

function processEffectTurnStartDND(rSource)
	local tMatch = {}
	local aTags = {"TREGENS"}

	-- Only process these if on the source node
	tMatch = EffectsManagerBCEG.getEffects(rSource, aTags, rSource, rSource)
	for _,tEffect in pairs(tMatch) do
		applyOngoingRegen(rSource, rSource, tEffect.rEffectComp, true)
	end

	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	aTags = {"SDMGOS", "SREGENS", "STREGENS"}
	for _, nodeCT in pairs(ctEntries) do
		local rActor = ActorManager.resolveActor(nodeCT)
		if rActor ~= rSource then
			tMatch = EffectsManagerBCEG.getEffects(rActor, aTags, rSource, rSource)
			for _,tEffect in pairs(tMatch) do
				if tEffect.sTag == "SDMGOS" then
					applyOngoingDamage(rSource, rActor, tEffect.rEffectComp)
				elseif tEffect.sTag == "SREGENS" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, false)
				elseif tEffect.sTag == "STREGENS" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, true)
				end
			end
		end
	end
	return true
end

function processEffectTurnEndDND(rSource)
  	local tMatch = {}
	local aTags = {"DMGOE", "REGENE", "TREGENE"}

	-- Only process these if on the source node
	tMatch = EffectsManagerBCEG.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "DMGOE" then
				applyOngoingDamage(rSource, rSource, tEffect.rEffectComp)
		elseif tEffect.sTag == "REGENE" then
			applyOngoingRegen(rSource, rSource, tEffect.rEffectComp, false)
		elseif tEffect.sTag == "TREGENE" then
			applyOngoingRegen(rSource, rSource, tEffect.rEffectComp, true)
		end
	end

	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	aTags = {"SDMGOE", "SREGENE", "STREGENE"}
	for _, nodeCT in pairs(ctEntries) do
		local rActor = ActorManager.resolveActor(nodeCT)
		if rActor ~= rSource then
			tMatch = EffectsManagerBCEG.getEffects(rActor, aTags, rSource, rSource)
			for _,tEffect in pairs(tMatch) do
				if tEffect.sTag == "SDMGOE" then
					applyOngoingDamage(rSource, rActor, tEffect.rEffectComp)
				elseif tEffect.sTag == "SREGENE" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, false)
				elseif tEffect.sTag == "STREGENE" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, true)
				end
			end
		end
	end
	return true
end

function customOnDamage(rSource, rTarget, rRoll)
	if not rTarget or not rSource or not rRoll  then
		return onDamage(rSource, rTarget, rRoll)
	end

	local bDead = false
	local nodeTarget = ActorManager.getCTNode(rTarget.sCreatureNode)
	local nodeSource = ActorManager.getCTNode(rSource.sCreatureNode)

	-- save off temp hp and wounds before damage
	local nTempHPPrev, nWoundsPrev = getTempHPAndWounds(rTarget)

	-- Play nice with others
	-- Do damage first then modify any effects
	onDamage(rSource, rTarget, rRoll)

	local sTargetNodeType, targetNode = ActorManager.getTypeAndNode(rTarget)
	local nTotalHP, nWounds
	if sTargetNodeType == "pc" then
		nTotalHP = DB.getValue(targetNode, "hp.total", 0)
		nWounds = DB.getValue(targetNode, "hp.wounds", 0)
	else
		nTotalHP = DB.getValue(targetNode, "hptotal", 0)
		nWounds = DB.getValue(targetNode, "wounds", 0)
	end
	if nTotalHP == nWounds then
		bDead = true
	end
	
	--Dropping this because Blistful Ignorance does this better
	--and there is less risk of conflict if this isn't a thing in BCE
	--processAbsorb(rSource, rTarget, rRoll)

	-- get temp hp and wounds after damage
	local nTempHP, nWounds = getTempHPAndWounds(rTarget)

	if OptionsManager.isOption("TEMP_IS_DAMAGE", "on") then
		-- If no damage was applied then return
		if nWoundsPrev >= nWounds and nTempHPPrev <= nTempHP then
			return
		end
	-- return if no damage was applied theen return
	elseif nWoundsPrev >= nWounds then
		return
	end

	
		--if the target is dead, process all effects with (E)
	if(bDead == true) then
		local sTarget =ActorManager.getCTNodeName(rTarget)
		CombatManager.callForEachCombatantEffect(endEffectsOnDead, sTarget)
	end
	
	local tMatch = {}
	local aTags = {"DMGAT", "DMGDT", "DMGRT"}
	--We need to do the activate, deactivate and remove first as a single action in order to get the rest
	-- of the tags to be applied as expected

	local aDMGTypes = EffectsManagerBCEG.getDamageTypes(rRoll)
	tMatch = EffectsManagerBCEG.getEffects(rTarget, aTags, rTarget, nil, nil, aDMGTypes)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "DMGAT" then
			EffectsManagerBCEG.modifyEffect(tEffect.nodeCT, "Activate")
		elseif tEffect.sTag == "DMGDT" then
			EffectsManagerBCEG.modifyEffect(tEffect.nodeCT, "Deactivate")
		elseif tEffect.sTag == "DMGRT" then
			EffectsManagerBCEG.modifyEffect(tEffect.nodeCT, "Remove")
		end
	end

	if (fProcessEffectOnDamage ~= nil) then
		fProcessEffectOnDamage(rSource,rTarget,rRoll)
	end

	aTags = {"TDMGADDT", "TDMGADDS"}
	
	tMatch = EffectsManagerBCEG.getEffects(rTarget, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		rEffect = EffectsManagerBCEG.matchEffect(tEffect.rEffectComp.remainder[1])
		if rEffect ~= {} then
			rEffect.sSource = DB.getValue(nodeEffect,"source_name", rTarget.sCTNode)
			rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
			
			if tEffect.sTag == "TDMGADDT" then
				EffectManager.addEffect("", "", nodeTarget, rEffect, true)
			elseif tEffect.sTag == "TDMGADDS" then
				EffectManager.addEffect("", "", nodeSource, rEffect, true)
			end
		end
	end

	aTags = {"SDMGADDT","SDMGADDS"}
	
	tMatch = EffectsManagerBCEG.getEffects(rSource, aTags, rTarget, rSource)
	for _,tEffect in pairs(tMatch) do
		rEffect = EffectsManagerBCEG.matchEffect(tEffect.rEffectComp.remainder[1])
		if rEffect ~= {} then
			rEffect.sSource = DB.getValue(nodeEffect,"source_name", rSource.sCTNode)
			rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
			if tEffect.sTag == "SDMGADDT" then
				EffectManager.addEffect("", "", nodeTarget, rEffect, true)
			elseif tEffect.sTag == "SDMGADDS" then
				EffectManager.addEffect("", "", nodeSource, rEffect, true)
			end
		end
	end
end

function endEffectsOnDead(nodeEffect, sTarget)
	local sEffect = DB.getValue(nodeEffect, "label", "")

	if (sEffect:match("%(E%)") and sTarget ==  DB.getValue(nodeEffect,"source_name", "")) then
		EffectsManagerBCEG.modifyEffect(nodeEffect, "Remove")
	end
end

-- This function is disabled but left here incase someone wants it for
--another ruleset
function processAbsorb(rSource, rTarget, rRoll)
	local tMatch = {}
	local aTags = {"ABSORB"}
	local bHalf = false
	local nDMGAmount = 0
	local sDMGType
	
	local aDMGTypes = EffectsManagerBCEG.getDamageTypes(rRoll)

	tMatch = EffectsManagerBCEG.getEffects(rTarget, aTags, rTarget, nil, nil, aDMGTypes)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "ABSORB" then
			for _,sRemainder in ipairs(tEffect.rEffectComp.remainder) do
				if sRemainder == "(H)" then
					bHalf = true
				end
				-- If we match any of our damage types we absorb it
				for _,aDMGClause in ipairs(aDMGTypes) do
					if StringManager.contains(aDMGClause.aDMG, sRemainder) then
						nDMGAmount = aDMGClause.nTotal
						sDMGType = sRemainder
					end
				end
			end
			if nDMGAmount > 0 then
				local sLabel =  "[ABSORBED: " .. sDMGType .. "]"
				if bHalf then
					nDMGAmount= math.floor(nDMGAmount/2)
				end
				ActionDamage.applyDamage(rSource, rTarget, tEffect.nGMOnly, "[HEAL]" .. sLabel, nDMGAmount)
			end
		end
	end
end

function customMessageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)

	local sAbsorb = sDamageDesc:match("%[ABSORBED:%s*%l*]")
	if sAbsorb ~= nil then
		sExtraResult = sAbsorb .. sExtraResult
	end
	return messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
end

function addEffectStart(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	replaceAbilityScores(rNewEffect, rActor)
	local rRoll = {}
	rRoll = isDie(rNewEffect.sName)
	if next(rRoll) ~= nil and next(rRoll.aDice) ~= nil then
		rRoll.rActor = rActor
		rRoll.subtype = "DUR"
		if rNewEffect.nGMOnly  then
			rRoll.bSecret = true
		else
			rRoll.bSecret = false
		end
		ActionsManager.performAction(nil, rActor, rRoll)
	end
	return true
end

-- Any effect that modifies ability score and is coded with -X
-- has the -X replaced with the targets ability score and then calculated
function replaceAbilityScores(rNewEffect, rActor)
	-- check contains -X to see if this is interesting enough to continue
	if rNewEffect.sName:match("%-X") then
		local tEffectComps = EffectManager.parseEffect(rNewEffect.sName)
		for _,sEffectComp in ipairs(tEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			local nAbility = 0

			if rEffectComp.type == "STR" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "STRMNM") then			
				nAbility = RulesetActorManager.getAbilityScore(rActor, "strength")
			elseif rEffectComp.type  == "DEX"  or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "DEXMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "dexterity")
			elseif rEffectComp.type  == "CON" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "CONMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "constitution")
			elseif rEffectComp.type  == "INT" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "INTMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "intelligence")
			elseif rEffectComp.type  == "WIS" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "WISMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "wisdom")
			elseif rEffectComp.type  == "CHA" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "CHAMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "charisma")
			end

			if(rEffectComp.remainder[1]:match("%-X")) then
				local sMod = rEffectComp.remainder[1]:gsub("%-X", "")
				local nMod = tonumber(sMod)
				if nMod ~= nil then
					if(nMod > nAbility) then
						nAbility = nMod - nAbility
					else
						nAbility = 0
					end
					--Exception for Mad Nomads effects display extension
					local sReplace = rEffectComp.type .. ":" ..tostring(nAbility)
					local sMatch =  rEffectComp.type ..":%s-%d+%-X"
					rNewEffect.sName = rNewEffect.sName:gsub(sMatch, sReplace)
				end
			end
		end
	end
end

function isDie(sEffect)
	local rRoll = {}
	local tEffectComps = EffectManager.parseEffect(sEffect)
	local nMatch = 0
	for kEffectComp,sEffectComp in ipairs(tEffectComps) do
		local aWords = StringManager.parseWords(sEffectComp, "%.%[%]%(%):")
		local bNegative = 0
		if #aWords > 0 then
			sType = aWords[1]:match("^([^:]+):")
			-- Only roll dice for ability score mods
			if sType and (sType == "STR" or sType == "DEX" or sType == "CON" or sType == "INT" or sType == "WIS" or sType == "CHA" or sType == "DMGR") then
				local nRemainderIndex = 2
				local sValueCheck = ""
				local sTypeRemainder = aWords[1]:sub(#sType + 2)
				if sTypeRemainder == "" then
					sValueCheck = aWords[2] or ""
					nRemainderIndex = nRemainderIndex + 1
				else
					sValueCheck = sTypeRemainder
				end
				-- Check to see if negative
				if sValueCheck:match("%-^[d%.%dF%+%-]+$") then
					sValueCheck = sValueCheck:gsub("%-", "", 1)
				end
				if StringManager.isDiceString(sValueCheck) then		
					local aDice, nMod = StringManager.convertStringToDice(sValueCheck)
					rRoll.sType = "effectbce"
					rRoll.sDesc = "[EFFECT " .. sEffect .. "] "
					rRoll.aDice = aDice
					rRoll.nMod = nMod
					rRoll.sEffect = sEffect
					rRoll.sValue = sValueCheck
				end
			end
		end
	end
	return rRoll
end

function getTempHPAndWounds(rTarget)
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget)
	local nTempHP = 0
	local nWounds = 0

	if not nodeTarget then
		return nTempHP, nWounds
	end
	
	if sTargetNodeType == "pc" then
		nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0)
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
	elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
		nTempHP = DB.getValue(nodeTarget, "hptemp", 0)
		nWounds = DB.getValue(nodeTarget, "wounds", 0)
	end
	return nTempHP, nWounds
end

function onInit()
	if  User.getRulesetName() == "5E"  or 
		User.getRulesetName() == "4E"  or
		User.getRulesetName() == "3.5E"  or
--		User.getRulesetName() == "2E"  or
		User.getRulesetName() == "PFRPG" then

		if Session.IsHost then
			OptionsManager.registerOption2("TEMP_IS_DAMAGE", false, "option_Better_Combat_Effects_Gold", 
			"option_Temp_Is_Damage", "option_entry_cycler", 
			{ labels = "option_val_off", values = "off",
				baselabel = "option_val_on", baseval = "on", default = "on" })  
		end

		if User.getRulesetName() == "5E" then
			RulesetActorManager = ActorManager5E
			RulesetEffectManager = EffectManager5E
		end
		if User.getRulesetName() == "4E" then
			RulesetActorManager = ActorManager4E
			RulesetEffectManager = EffectManager4E
		end
		if User.getRulesetName() == "3.5E" or User.getRulesetName() == "PFRPG" then
			RulesetActorManager = ActorManager35E
			RulesetEffectManager = EffectManager35E
		end

		-- BCE DND TAGS
		EffectsManagerBCEG.registerBCETag("DMGAT", EffectsManagerBCEG.aBCEActivateOptions)
			
		EffectsManagerBCEG.registerBCETag("DMGRT", EffectsManagerBCEG.aBCERemoveOptions)

		EffectsManagerBCEG.registerBCETag("DMGDT", EffectsManagerBCEG.aBCEDeactivateOptions)
		
		EffectsManagerBCEG.registerBCETag("DMGOE", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("RESTL", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("RESTS", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("TDMGADDS", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("TDMGADDT", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("REGENE", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("TREGENS", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("TREGENE", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SDMGADDT", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("SDMGADDS", EffectsManagerBCEG.aBCEDefaultOptions)
		EffectsManagerBCEG.registerBCETag("ABSORB", EffectsManagerBCEG.aBCEDefaultOptions)

		EffectsManagerBCEG.registerBCETag("REGENA", EffectsManagerBCEG.aBCEOneShotOptions)
		EffectsManagerBCEG.registerBCETag("TREGENA", EffectsManagerBCEG.aBCEOneShotOptions)
		EffectsManagerBCEG.registerBCETag("DMGA", EffectsManagerBCEG.aBCEOneShotOptions)
		EffectsManagerBCEG.registerBCETag("DUR", EffectsManagerBCEG.aBCEOneShotOptions)

		EffectsManagerBCEG.registerBCETag("STREGENS", EffectsManagerBCEG.aBCESourceMattersOptions)
		EffectsManagerBCEG.registerBCETag("STREGENE", EffectsManagerBCEG.aBCESourceMattersOptions)
		EffectsManagerBCEG.registerBCETag("SREGENS", EffectsManagerBCEG.aBCESourceMattersOptions)
		EffectsManagerBCEG.registerBCETag("SREGENE", EffectsManagerBCEG.aBCESourceMattersOptions)
		EffectsManagerBCEG.registerBCETag("SDMGOS", EffectsManagerBCEG.aBCESourceMattersOptions)
		EffectsManagerBCEG.registerBCETag("SDMGOE", EffectsManagerBCEG.aBCESourceMattersOptions)
	
		EffectsManagerBCEG.setCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCEG.setCustomProcessTurnEnd(processEffectTurnEndDND)
		EffectsManagerBCEG.setCustomPreAddEffect(addEffectStart)
		EffectsManagerBCEG.setCustomPostAddEffect(addEffectPost)
		
		-- save off the originals so we play nice with others
		messageDamage = ActionDamage.messageDamage
		ActionDamage.messageDamage = customMessageDamage
		onDamage = ActionDamage.onDamage
		ActionDamage.onDamage = customOnDamage
		ActionsManager.registerResultHandler("damage", customOnDamage)
		ActionsManager.registerResultHandler("effectbce", onEffectRollHandler)

		aExtensions = Extension.getExtensions()
		for _,sExtension in ipairs(aExtensions) do
			tExtension = Extension.getExtensionInfo(sExtension)
			if (tExtension.name == "MNM Charsheet Effects Display") then
				bMadNomadCharSheetEffectDisplay = true
			end
		end
	end
end


function onClose()
	if  User.getRulesetName() == "5E"  or 
		User.getRulesetName() == "4E"  or
		User.getRulesetName() == "3.5E"  or
--		User.getRulesetName() == "2E"  or
		User.getRulesetName() == "PFRPG" then
		
		ActionDamage.messageDamage = messageDamage
		ActionDamage.onDamage = onDamage
		ActionsManager.unregisterResultHandler("damage")
		ActionsManager.unregisterResultHandler("effectbce")

		EffectsManagerBCEG.removeCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCEG.removeCustomProcessTurnEnd(processEffectTurnEndDND)

		EffectsManagerBCEG.removeCustomPreAddEffect(addEffectStart)
	end
end