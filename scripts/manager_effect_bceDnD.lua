--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local RulesetActorManager = nil
local applyDamage = nil
local messageDamage = nil
local bMadNomadCharSheetEffectDisplay = false
local handleApplyDamage = nil
local notifyApplyDamage = nil

function setProcessEffectApplyDamage(ProcessEffectApplyDamage)
	fProcessEffectApplyDamage = ProcessEffectApplyDamage
end

function customRest(nodeActor, bLong, bMilestone)
	local rSource = ActorManager.resolveActor(nodeActor)

	local aTags = {"RESTS"}
	if bLong == true then
		table.insert(aTags, "RESTL")
		if User.getRulesetName() == "5E" then
			table.insert(aTags, "SAVERESTL")
		end
	end

	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "RESTL" or tEffect.sTag == "RESTS" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		elseif tEffect.sTag == "SAVERESTL" then
			EffectsManagerBCE5E.saveEffect(rSource, rSource, tEffect)
		end
	end
end

function onEffectRollHandler(rSource, rTarget, rRoll)
	if not Session.IsHost then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectclient"))
		return
	end
	local nodeSource = ActorManager.getCTNode(rSource)
	local sEffect

	if rRoll.subtype and rRoll.subtype == "DUR" and rRoll.nodeEffectCT and type(DB.findNode(rRoll.nodeEffectCT)) == "databasenode" then
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
		EffectsManagerBCE.updateEffect(nodeSource,nodeCT, rRoll.sEffect)
		return
	end

	for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
		sEffect = DB.getValue(nodeEffect, "label", "")
		if sEffect == rRoll.sEffect then
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

function addEffectPost(sUser, sIdentity, nodeCT, rNewEffect, nodeEeffect)
	if (nodeCT == nil) then
		return true
	end
	local rTarget = ActorManager.resolveActor(nodeCT)
	local rSource
	if rNewEffect.sSource == "" then
		rSource = rTarget
	else
		rSource = ActorManager.resolveActor(rNewEffect.sSource)
	end

	local aTags = {"REGENA", "TREGENA", "DMGA", "DUR"}
	local tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "REGENA" and tEffect.rEffectComp.type == "REGENA" then
			applyOngoingRegen(rSource, rTarget, tEffect.rEffectComp, false)
		elseif tEffect.sTag == "TREGENA" and tEffect.rEffectComp.type == "TREGENA" then
			applyOngoingRegen(rSource, rTarget, tEffect.rEffectComp, true)
		elseif tEffect.sTag == "DMGA" and tEffect.rEffectComp.type == "DMGA" then
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
	local aTags = {"TREGENS"}

	-- Only process these if on the source node
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource, rSource)
	for _,tEffect in pairs(tMatch) do
		applyOngoingRegen(rSource, rSource, tEffect.rEffectComp, true)
	end

	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	aTags = {"SDMGOS", "SREGENS", "STREGENS"}
	for _, nodeCT in pairs(ctEntries) do
		local rActor = ActorManager.resolveActor(nodeCT)
		if rActor ~= rSource then
			tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rSource, rSource)
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
	local aTags = {"DMGOE", "REGENE", "TREGENE"}

	-- Only process these if on the source node
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
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
			tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rSource, rSource)
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

function customApplyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
	local nodeSource
	local nodeTarget
	if rTarget and rTarget.sCreatureNode then
		nodeTarget = ActorManager.getCTNode(rTarget.sCreatureNode)
	end
	if rSource and rSource.sCreatureNode then
		nodeSource = ActorManager.getCTNode(rSource.sCreatureNode)
	end
	-- save off temp hp and wounds before damage
	local nTempHPPrev, nWoundsPrev = getTempHPAndWounds(rTarget)
	-- Play nice with others
	-- Do damage first then modify any effects
	applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)

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
	local nTempHP
	nTempHP, nWounds = getTempHPAndWounds(rTarget)

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

	local tMatch
	local aTags = {"DMGAT", "DMGDT", "DMGRT"}
	--We need to do the activate, deactivate and remove first as a single action in order to get the rest
	-- of the tags to be applied as expected

	local rDamageOutput = ActionDamage.decodeDamageText(nTotal, sDamage)

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nil, rDamageOutput)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "DMGAT" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Activate")
		elseif tEffect.sTag == "DMGDT" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Deactivate")
		elseif tEffect.sTag == "DMGRT" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		end
	end

	if (fProcessEffectApplyDamage ~= nil) then
		fProcessEffectApplyDamage(rSource,rTarget)
	end

	aTags = {"TDMGADDT", "TDMGADDS"}

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
	for _,tEffect in pairs(tMatch) do
		rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
		if rEffect ~= {} then
			rEffect.sSource = DB.getValue(nodeEffect,"source_name", rTarget.sCTNode)
			rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)

			if tEffect.sTag == "TDMGADDT" and nodeTarget ~= nil then
				EffectManager.addEffect("", "", nodeTarget, rEffect, true)
			elseif tEffect.sTag == "TDMGADDS" and nodeSource ~= nil then
				EffectManager.addEffect("", "", nodeSource, rEffect, true)
			end
		end
	end

	aTags = {"SDMGADDT","SDMGADDS"}
	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rTarget, rSource)
	for _,tEffect in pairs(tMatch) do
		rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
		if rEffect ~= {} then
			rEffect.sSource = DB.getValue(nodeEffect,"source_name", rSource.sCTNode)
			rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
			if tEffect.sTag == "SDMGADDT" and nodeTarget ~= nil then
				EffectManager.addEffect("", "", nodeTarget, rEffect, true)
			elseif tEffect.sTag == "SDMGADDS" and nodeSource ~= nil then
				EffectManager.addEffect("", "", nodeSource, rEffect, true)
			end
		end
	end
end

function endEffectsOnDead(nodeEffect, sTarget)
	local sEffect = DB.getValue(nodeEffect, "label", "")

	if (sEffect:match("%(E%)") and sTarget ==  DB.getValue(nodeEffect,"source_name", "")) then
		EffectsManagerBCE.modifyEffect(nodeEffect, "Remove")
	end
end

-- This function is disabled but left here incase someone wants it for
--another ruleset
function processAbsorb(rSource, rTarget, rRoll)
	local tMatch
	local aTags = {"ABSORB"}
	local bHalf = false
	local nDMGAmount = 0
	local sDMGType

	local aDMGTypes = EffectsManagerBCE.getDamageTypes(rRoll)

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nil, aDMGTypes)
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

--Dead code. Here for Absorb if it is needed for some reason
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
	local rRoll
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

function customConvertStringToDice(s)
	local tDice = {};
	local nMod = 0;

	local tTerms = DiceManager.convertDiceStringToTerms(s);
	for _,vTerm in ipairs(tTerms) do
		if StringManager.isNumberString(vTerm) then
			nMod = nMod + (tonumber(vTerm) or 0);
		else
			local nDieCount, sDieType = DiceManager.parseDiceTerm(vTerm);
			if sDieType then
				for i = 1, nDieCount do
					table.insert(tDice, sDieType)
				end
			-- next two lines enable "-X" ability replacement
			elseif vTerm and vTerm == "-X" then
				nMod = 0;
			end
		end
	end

	return tDice, nMod;
end

function isDie(sEffect)
	local rRoll = {}
	local tEffectComps = EffectManager.parseEffect(sEffect)
	for _,sEffectComp in ipairs(tEffectComps) do
		local aWords = StringManager.parseWords(sEffectComp, "%.%[%]%(%):")
		if #aWords > 0 then
			local sType = aWords[1]:match("^([^:]+):")
			-- Only roll dice for ability score mods
			if sType and (sType == "STR" or sType == "DEX" or sType == "CON" or
						sType == "INT" or sType == "WIS" or sType == "CHA" or sType == "DMGR") then
				local sValueCheck
				local sTypeRemainder = aWords[1]:sub(#sType + 2)
				if sTypeRemainder == "" then
					sValueCheck = aWords[2] or ""
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

-- only for Advanced Effects
-- ##WARNING CONFLICT POTENTIAL
function customHandleApplyDamage(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	if rTarget then
		rTarget.nOrder = msgOOB.nTargetOrder;
	end
	if msgOOB.itemPath then
		rSource.itemPath = msgOOB.itemPath
	end

	local nTotal = tonumber(msgOOB.nTotal) or 0;
	customApplyDamage(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), msgOOB.sDamage, nTotal);
end

-- only for Advanced Effects
-- ##WARNING CONFLICT POTENTIAL
function customNotifyApplyDamage(rSource, rTarget, bSecret, sDesc, nTotal)
	if not rTarget then
		return;
	end

	local msgOOB = {};
	msgOOB.type = ActionDamage.OOB_MSGTYPE_APPLYDMG;

	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	if rSource and rSource.itemPath then
		msgOOB.itemPath = rSource.itemPath
	end

	msgOOB.nTotal = nTotal;
	msgOOB.sDamage = sDesc;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	msgOOB.nTargetOrder = rTarget.nOrder;

	Comm.deliverOOBMessage(msgOOB, "");
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
		end
		if User.getRulesetName() == "4E" then
			RulesetActorManager = ActorManager4E
		end
		if User.getRulesetName() == "3.5E" or User.getRulesetName() == "PFRPG" then
			RulesetActorManager = ActorManager35E
		end

		-- BCE DND TAGS
		EffectsManagerBCE.registerBCETag("DMGAT", EffectsManagerBCE.aBCEActivateOptions)

		EffectsManagerBCE.registerBCETag("DMGRT", EffectsManagerBCE.aBCEDeactivateOptions)
		EffectsManagerBCE.registerBCETag("DMGDT", EffectsManagerBCE.aBCEDeactivateOptions)

		EffectsManagerBCE.registerBCETag("DMGOE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("RESTL", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("RESTS", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("TDMGADDS", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("TDMGADDT", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("REGENE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("TREGENS", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("TREGENE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SDMGADDT", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SDMGADDS", EffectsManagerBCE.aBCEDefaultOptionsAE)
		--EffectsManagerBCE.registerBCETag("ABSORB", EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("REGENA", EffectsManagerBCE.aBCEOneShotOptions)
		EffectsManagerBCE.registerBCETag("TREGENA", EffectsManagerBCE.aBCEOneShotOptions)
		EffectsManagerBCE.registerBCETag("DMGA", EffectsManagerBCE.aBCEOneShotOptions)
		EffectsManagerBCE.registerBCETag("DUR", EffectsManagerBCE.aBCEOneShotOptions)

		EffectsManagerBCE.registerBCETag("STREGENS", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("STREGENE", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SREGENS", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SREGENE", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SDMGOS", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SDMGOE", EffectsManagerBCE.aBCESourceMattersOptions)

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEndDND)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectStart)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost)

		-- save off the originals so we play nice with others
		--Comment out because only needed for absorb
	--	messageDamage = ActionDamage.messageDamage
	--	ActionDamage.messageDamage = customMessageDamage
		applyDamage = ActionDamage.applyDamage
		ActionDamage.applyDamage = customApplyDamage

		convertStringToDice = DiceManager.convertStringToDice
		DiceManager.convertStringToDice = customConvertStringToDice

		ActionsManager.registerResultHandler("effectbce", onEffectRollHandler)

		local aExtensions = Extension.getExtensions()
		for _,sExtension in ipairs(aExtensions) do
			tExtension = Extension.getExtensionInfo(sExtension)
			if (tExtension.name == "MNM Charsheet Effects Display") then
				bMadNomadCharSheetEffectDisplay = true
			elseif (tExtension.name == "5E - Advanced Effects") then
				bAdvanceEffects = true
				notifyApplyDamage = ActionDamage.notifyApplyDamage
				handleApplyDamage = ActionDamage.handleApplyDamage
				ActionDamage.notifyApplyDamage = customNotifyApplyDamage
				ActionDamage.handleApplyDamage = customHandleApplyDamage
				OOBManager.registerOOBMsgHandler(ActionDamage.OOB_MSGTYPE_APPLYDMG, customHandleApplyDamage);
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


		ActionDamage.applyDamage = applyDamage
		if bAdvanceEffects then
			ActionDamage.notifyApplyDamage = notifyApplyDamage
			ActionDamage.handleApplyDamage = handleApplyDamage
		end
		ActionsManager.unregisterResultHandler("effectbce")

		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEndDND)

		EffectsManagerBCE.removeCustomPreAddEffect(addEffectStart)
	end
end