--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local RulesetActorManager = nil
local RulesetEffectManager =  nil
local applyDamage = nil
local messageDamage = nil
local checkConditional = nil

local convertStringToDice = nil
local fProcessEffectOnDamage = nil
local bMadNomadCharSheetEffectDisplay = false
local outputResult = nil
local onDamage = nil

function setProcessEffectOnDamage(ProcessEffectOnDamage)
	fProcessEffectOnDamage = ProcessEffectOnDamage
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
			DB.setValue(nodeEffect, "label", "string", sEffect)
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
	local tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		local tParseEffect = EffectManager.parseEffect(tEffect.sLabel)
		local sLabel = StringManager.trim(tParseEffect[1])
		if tEffect.sTag == "REGENA" and tEffect.rEffectComp.type == "REGENA" then
			applyOngoingRegen(rSource, rTarget, tEffect.rEffectComp, false, sLabel)
		elseif tEffect.sTag == "TREGENA" and tEffect.rEffectComp.type == "TREGENA" then
			applyOngoingRegen(rSource, rTarget, tEffect.rEffectComp, true, sLabel)
		elseif tEffect.sTag == "DMGA" and tEffect.rEffectComp.type == "DMGA" then
			applyOngoingDamage(rSource, rTarget, tEffect.rEffectComp, false, sLabel)
		elseif tEffect.sTag == "DUR" and type(tEffect.nodeCT) == "databasenode" then
			sLabel = DB.getValue(tEffect.nodeCT, "label", "")
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

function applyOngoingDamage(rSource, rTarget, rEffectComp, bHalf, sLabel)
	local rAction = {}
	local aClause = {}
	rAction.clauses = {}

	aClause.dice  = rEffectComp.dice;
	aClause.modifier = rEffectComp.mod
	aClause.dmgtype = string.lower(table.concat(rEffectComp.remainder, ","))
	table.insert(rAction.clauses, aClause)
	if not sLabel then
		sLabel = "Ongoing Effect"
	end
	rAction.label = sLabel

	local rRoll = ActionDamage.getRoll(rTarget, rAction)
	if  bHalf then
		rRoll.sDesc = rRoll.sDesc .. " [HALF]"
	end
	ActionsManager.actionDirect(rSource, "damage", {rRoll}, {{rTarget}})
end

function applyOngoingRegen(rSource, rTarget, rEffectComp, bTemp, sLabel)
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
				local tParseEffect = EffectManager.parseEffect(tEffect.sLabel)
				local sLabel = StringManager.trim(tParseEffect[1])
				if tEffect.sTag == "SDMGOS" then
					applyOngoingDamage(rSource, rActor, tEffect.rEffectComp, false, sLabel)
				elseif tEffect.sTag == "SREGENS" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, false, sLabel)
				elseif tEffect.sTag == "STREGENS" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, true, sLabel)
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
		local tParseEffect = EffectManager.parseEffect(tEffect.sLabel)
		local sLabel = StringManager.trim(tParseEffect[1])
		if tEffect.sTag == "DMGOE" then
			applyOngoingDamage(rSource, rSource, tEffect.rEffectComp, false, sLabel)
		elseif tEffect.sTag == "REGENE" then
			applyOngoingRegen(rSource, rSource, tEffect.rEffectComp, false, sLabel)
		elseif tEffect.sTag == "TREGENE" then
			applyOngoingRegen(rSource, rSource, tEffect.rEffectComp, true, sLabel)
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
				local tParseEffect = EffectManager.parseEffect(tEffect.sLabel)
				local sLabel = StringManager.trim(tParseEffect[1])
				if tEffect.sTag == "SDMGOE" then
					applyOngoingDamage(rSource, rActor, tEffect.rEffectComp, false, sLabel)
				elseif tEffect.sTag == "SREGENE" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, false, sLabel)
				elseif tEffect.sTag == "STREGENE" then
					applyOngoingRegen(rSource, rActor, tEffect.rEffectComp, true, sLabel)
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

	local nodeTarget = ActorManager.getCTNode(rTarget)
	local nodeSource = ActorManager.getCTNode(rSource)

	-- save off temp hp and wounds before damage
	local nTempHPPrev, nWoundsPrev = getTempHPAndWounds(rTarget)
	-- Play nice with others
	-- Do damage first then modify any effects
	onDamage(rSource, rTarget, rRoll)

	--Dropping this because Blistful Ignorance does this better
	--and there is less risk of conflict if this isn't a thing in BCE
	--processAbsorb(rSource, rTarget, rRoll)

	local nTempHP, nWounds, nTotalHP = getTempHPAndWounds(rTarget)
	-- on a client it seems the DB isn't updated fast enough for the wounds to register
	-- maybe handle this with some sort of callback?
	if Session.IsHost then
		if OptionsManager.isOption("TEMP_IS_DAMAGE", "on") then
			-- If no damage was applied then return
			if nWoundsPrev >= nWounds and nTempHPPrev <= nTempHP then
				return
			end
		-- return if no damage was applied theen return
		elseif nWoundsPrev >= nWounds then
				return
		end
		if nTotalHP == nWounds then
			CombatManager.callForEachCombatant(endEffectsOnDead, nodeTarget)
		end
	end

	local tMatch
	local aTags = {"DMGAT", "DMGDT", "DMGRT"}
	--We need to do the activate, deactivate and remove first as a single action in order to get the rest
	-- of the tags to be applied as expected

	local aDMGTypes = EffectsManagerBCE.getDamageTypes(rRoll)
	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nil, aDMGTypes)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "DMGAT" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Activate")
		elseif tEffect.sTag == "DMGDT" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Deactivate")
		elseif tEffect.sTag == "DMGRT" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		end
	end

	if (fProcessEffectOnDamage) then
		fProcessEffectOnDamage(rSource,rTarget,rRoll)
	end

	aTags = {"TDMGADDT", "TDMGADDS"}
	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
		if next(rEffect) then
			rEffect.sSource = DB.getValue(nodeTarget,"source_name", rTarget.sCTNode)
			rEffect.nInit  = DB.getValue(nodeTarget, "initresult", 0)

			if tEffect.sTag == "TDMGADDT" then
				EffectsManagerBCE.notifyAddEffect(nodeTarget, rEffect,tEffect.rEffectComp.remainder[1])
			elseif tEffect.sTag == "TDMGADDS" then
				EffectsManagerBCE.notifyAddEffect(nodeSource, rEffect,tEffect.rEffectComp.remainder[1])
			end
		end
	end

	aTags = {"SDMGADDT","SDMGADDS"}
	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rTarget, rSource)
	for _,tEffect in pairs(tMatch) do
		local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
		if next(rEffect) then
			rEffect.sSource = DB.getValue(nodeSource,"source_name", rSource.sCTNode)
			rEffect.nInit  = DB.getValue(nodeSource, "initresult", 0)
			if tEffect.sTag == "SDMGADDT"   then
				EffectsManagerBCE.notifyAddEffect(nodeTarget, rEffect,tEffect.rEffectComp.remainder[1])
			elseif tEffect.sTag == "SDMGADDS" then
				EffectsManagerBCE.notifyAddEffect(nodeSource, rEffect,tEffect.rEffectComp.remainder[1])
			end
		end
	end
end

function endEffectsOnDead(node, nodeTarget)
	for _,nodeEffect in pairs(DB.getChildren(node, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")

		if (sEffect:match("%(E%)") and (node == nodeTarget or ActorManager.getCTNodeName(nodeTarget) == DB.getValue(nodeEffect,"source_name", ""))) then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove")
		end
	end

end

-- Dead Code. This function is disabled but left here incase someone wants it for
--another ruleset
-- function processAbsorb(rSource, rTarget, rRoll)
-- 	local tMatch
-- 	local aTags = {"ABSORB"}
-- 	local bHalf = false
-- 	local nDMGAmount = 0
-- 	local sDMGType

-- 	local aDMGTypes = EffectsManagerBCE.getDamageTypes(rRoll)

-- 	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nil, aDMGTypes)
-- 	for _,tEffect in pairs(tMatch) do
-- 		if tEffect.sTag == "ABSORB" then
-- 			for _,sRemainder in ipairs(tEffect.rEffectComp.remainder) do
-- 				if sRemainder == "(H)" then
-- 					bHalf = true
-- 				end
-- 				-- If we match any of our damage types we absorb it
-- 				for _,aDMGClause in ipairs(aDMGTypes) do
-- 					if StringManager.contains(aDMGClause.aDMG, sRemainder) then
-- 						nDMGAmount = aDMGClause.nTotal
-- 						sDMGType = sRemainder
-- 					end
-- 				end
-- 			end
-- 			if nDMGAmount > 0 then
-- 				local sLabel =  "[ABSORBED: " .. sDMGType .. "]"
-- 				if bHalf then
-- 					nDMGAmount= math.floor(nDMGAmount/2)
-- 				end
-- 				ActionDamage.applyDamage(rSource, rTarget, tEffect.nGMOnly, "[HEAL]" .. sLabel, nDMGAmount)
-- 			end
-- 		end
-- 	end
-- end

--Dead code. Here for Absorb if it is needed for some reason
-- function customMessageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)

-- 	local sAbsorb = sDamageDesc:match("%[ABSORBED:%s*%l*]")
-- 	if sAbsorb ~= nil then
-- 		sExtraResult = sAbsorb .. sExtraResult
-- 	end
-- 	return messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
-- end

function addEffectStart(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	replaceAbilityScores(rNewEffect, rActor)
	local rRoll
	rRoll = isDie(rNewEffect.sName)
	if next(rRoll) and next(rRoll.aDice) then
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
				if nMod then
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
function customOutputResult(bTower, rSource, rTarget, rMessageGM, rMessagePlayer)
	if rMessageGM.text:gmatch("%w+")() == "Save" then
		rMessageGM.icon = "bce_save"
	end
	if rMessagePlayer.text:gmatch("%w+")() == "Save" then
		rMessagePlayer.icon = "bce_save"
	end
	outputResult(bTower, rSource, rTarget, rMessageGM, rMessagePlayer)
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
	local nTotalHP = 0

	if not nodeTarget then
		return nTempHP, nWounds, nTotalHP
	end

	if sTargetNodeType == "pc" then
		nTotalHP = DB.getValue(nodeTarget, "hp.total", 0)
		nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0)
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
	elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
		nTotalHP = DB.getValue(nodeTarget, "hptotal", 0)
		nTempHP = DB.getValue(nodeTarget, "hptemp", 0)
		nWounds = DB.getValue(nodeTarget, "wounds", 0)
	end
	return nTempHP, nWounds, nTotalHP
end

-----Conditional Operators--------
function customCheckConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	local bReturn = checkConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)

	if bReturn then
		for _,v in ipairs(aConditions) do
			local sLower = v:lower();
			local sTempHP = (sLower == "temphp" or sLower:match("^temphp%s*%(([^)]+)%)$"));
			local sRange =  sLower:match("^range%s*%(([^)]+)%)$");
			local sWounds = sLower:match("^wounds%s*%(([^)]+)%)$");

			if sTempHP then
				if not EffectsManagerBCEDND.hasTempHP(rActor, sTempHP) then
					bReturn = false;
					break;
				end
			end
			if sLower == "healthy" or sLower == "light" or sLower == "moderate" or sLower == "heavy" or sLower == "critical" then
				if not EffectsManagerBCEDND.isWounded(rActor, sLower) then
					bReturn = false;
					break;
				end
			end
			if sLower == "dying" then
				if ActorHealthManager.isDyingOrDead(rActor) then
					bReturn = false;
					break;
				end
			end
			if sWounds then
				if not EffectsManagerBCEDND.isWoundsPercent(rActor, sWounds) then
					bReturn = false;
					break;
				end
			end
			if sRange then
				if not EffectsManagerBCEDND.isRange(rActor, sRange, rTarget) then
					bReturn = false;
					break;
				end
			end
		end
	end
	return bReturn;
end

function hasTempHP(rActor, sTemp)
	local bReturn = false;
	local nTempHP = 0;
	local nThreshold = nil
	local sOperator = ""
	local sThreshold = ""
	if sTemp ~= true and sTemp ~= "temphp" and sTemp ~= "" then
		sOperator, sThreshold = EffectsManagerBCEDND.parseOperator(sTemp);
		nThreshold = tonumber(sThreshold);
	end
	local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if sNodeType == "pc" then
		nTempHP = DB.getValue(nodeActor, "hp.temporary", 0);
	else
		nTempHP = DB.getValue(nodeActor, "hptemp", 0);
	end
	if nThreshold and sOperator ~= "" then
		if sOperator == ">=" and nTempHP >= nThreshold then
			bReturn = true;
		elseif sOperator == ">=" and nTempHP >= nThreshold then
			bReturn = true;
		elseif sOperator == ">" and nTempHP > nThreshold then
			bReturn = true;
		elseif sOperator == "<" and nTempHP < nThreshold then
			bReturn = true;
		elseif sOperator == "=" and nTempHP == nThreshold then
			bReturn = true;
		end
	elseif not nThreshold and nTempHP > 0 then
		bReturn = true
	end
	return  bReturn;
end

function isWounded(rActor, sOperator)
	local bReturn = false;
	local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
	if sOperator == "healthy" and nPercentWounded == 0 then
		bReturn = true;
	elseif sOperator == "light" and nPercentWounded > 0 and nPercentWounded < .25 then
		bReturn = true;
	elseif sOperator == "moderate" and nPercentWounded >= .25 and nPercentWounded < .50 then
		bReturn = true;
	elseif sOperator == "heavy" and nPercentWounded >= .50 and nPercentWounded < .75 then
		bReturn = true;
	elseif sOperator == "critical" and nPercentWounded > .75 and nPercentWounded < 1 then
		bReturn = true;
	end
	return bReturn;
end

function isWoundsPercent(rActor, sClause)
	local bReturn = false;
	if sClause and sClause ~= "" then
		local sOperator, sPercent = EffectsManagerBCEDND.parseOperator(sClause);
		local nThreshold = tonumber(sPercent);
		if nThreshold and sOperator ~= "" then
			local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
			if sOperator == ">=" and nPercentWounded >= nThreshold then
				bReturn = true;
			elseif sOperator == ">=" and nPercentWounded >= nThreshold then
				bReturn = true;
			elseif sOperator == ">" and nPercentWounded > nThreshold then
				bReturn = true;
			elseif sOperator == "<" and nPercentWounded < nThreshold then
				bReturn = true;
			elseif sOperator == "=" and nPercentWounded == nThreshold then
				bReturn = true;
			end
		end
	end
	return bReturn;
end

function isRange(rActor, sRange, rActorIgnore)
	local bReturn = false;
	local nodeCTActorIgnore = nil;
	local tRange = EffectsManagerBCEDND.parseRange(sRange);
	local nodeCTActor = ActorManager.getCTNode(rActor);
	local tokenActor = CombatManager.getTokenFromCT(nodeCTActor);
	local aSearchTokens = {};
	if tRange.nRange and tokenActor then
		aSearchTokens = Token.getTokensWithinDistance(tokenActor, tRange.nRange);
	end
	if rActorIgnore then
		nodeCTActorIgnore = ActorManager.getCTNode(rActorIgnore);
		tRange.sFaction =  CombatManager.getFactionFromCT(nodeCTActorIgnore);
	else
		tRange.sFaction = CombatManager.getFactionFromCT(nodeCTActor);
	end
	for _, tokenCT in pairs(aSearchTokens) do
		local nodeCT = CombatManager.getCTFromToken(tokenCT);
		if nodeCT and (nodeCTActor ~= nodeCT) and (nodeCTActorIgnore ~= nodeCT) and EffectsManagerBCEDND.filterRange(nodeCT, tRange) then
			local rActorCT = ActorManager.resolveActor(nodeCT);
			if not (EffectManager.hasCondition(rActorCT, "Stunned" or EffectManager.hasCondition(rActorCT, "Unconscious"))
					or EffectManager.hasCondition(rActorCT, "Paralyzed") or EffectManager.hasCondition(rActorCT, "Incapacitated")
					or EffectManager.hasCondition(rActorCT, "Petrified")) then
				bReturn = true;
				break;
			end
		end
	end
	return bReturn;
end

function parseOperator(sInput)
	local sOperator = "";
	local aClause = StringManager.splitByPattern(sInput, "%s*,%s*", true);
	for i, sWord in pairs(aClause) do
		if sWord == ">" or sWord == "<" or sWord == "<=" or sWord == ">=" or sWord == "=" then
			sOperator = sWord;
			table.remove(aClause, i);
			break;
		end
	end
	return sOperator, StringManager.combine(",",unpack(aClause));
end

function parseRange(sRange)
	local tRange = {nRange = nil, aFaction = {}, aNamed = {}, aType = {}};
	local aRange = StringManager.splitByPattern(sRange, "%s*,%s*", true);

	for _, sWord in pairs(aRange) do
		local sCleanWord = sWord;
		if StringManager.startsWith(sWord, "!") then
			sCleanWord = sWord:sub(2);
		end
		local nRange = tonumber(sWord);
		if nRange then
			tRange.nRange = nRange;
		elseif sCleanWord == "friend" or sCleanWord == "foe" or sCleanWord == "neutral" or sCleanWord == "ally" or sCleanWord == "enemy" then
			table.insert(tRange.aFaction, sWord);
		elseif StringManager.contains(DataCommon.creaturetype, sCleanWord) or StringManager.contains(DataCommon.creaturesubtype, sCleanWord) then
			table.insert(tRange.aType, sWord);
		else
			table.insert(tRange.aNamed, sWord);
		end
	end
	return tRange;
end

function filterRange(nodeCT, tRange)
	if next(tRange.aFaction) and not EffectsManagerBCEDND.filterFaction(nodeCT, tRange) then
		return false;
	end
	if next(tRange.aNamed) and not EffectsManagerBCEDND.filterCreatureName(nodeCT, tRange) then
		return false;
	end
	if next(tRange.aType) and not EffectsManagerBCEDND.filterCreatureType(nodeCT, tRange) then
		return false;
	end
	return true;
end

function filterFaction(nodeCT, tRange)
	local bReturn = false;
	local sFaction = CombatManager.getFactionFromCT(nodeCT);
	for _, sFactionFilter in pairs(tRange.aFaction) do
		local bInvert = false;
		if StringManager.startsWith(sFactionFilter, "!") then
			sFactionFilter = sFactionFilter:sub(2);
			bInvert = true;
		end
		if bInvert then
			if sFactionFilter == "enemy" and sFaction == tRange.sFaction then
				bReturn = true;
				break;
			elseif sFactionFilter == "ally" and ((sFaction == "foe" and tRange.sFaction == "friend") or (sFaction == "friend" and tRange.sFaction == "foe")) then
				bReturn = true;
				break;
			elseif (sFactionFilter ~= "ally" and sFactionFilter ~= "enemy") and sFaction ~= sFactionFilter  then
				bReturn = true;
				break;
			end
		else
			if sFactionFilter == "ally" and sFaction == tRange.sFaction then
				bReturn = true;
				break;
			elseif sFactionFilter == "enemy" and ((sFaction == "foe" and tRange.sFaction == "friend") or (sFaction == "friend" and tRange.sFaction == "foe")) then
				bReturn = true;
				break;
			elseif (sFaction == sFactionFilter) then
				bReturn = true;
				break;
			end
		end
	end
	return bReturn;
end

function filterCreatureName(nodeCT, tRange)
	local bReturn = false;
	if next(tRange.aNamed) then
		local rActorCT = ActorManager.resolveActor(nodeCT);
		local sNameLower = rActorCT.sName:lower();
		for _, sName in pairs(tRange.aNamed) do
			local bInvert = false;
			if StringManager.startsWith(sName, "!") then
				sName = sName:sub(2);
				bInvert = true;
			end
			if bInvert and  not sNameLower:match(sName) then
				bReturn = true;
				break;
			elseif not bInvert and sNameLower:match(sName) then
			 	bReturn = true;
			 	break;
			end
		end
	end
	return bReturn;
end

function filterCreatureType(nodeCT, tRange)
	local bReturn = false;
	if next(tRange.aType) then
		local rActorCT = ActorManager.resolveActor(nodeCT);
		for _, sType in pairs(tRange.aType) do
			local bInvert = false;
			if StringManager.startsWith(sType, "!") then
				sType = sType:sub(2);
				bInvert = true;
			end
			if bInvert and not ActorCommonManager.isCreatureTypeDnD(rActorCT, sType) then
				bReturn = true;
				break;
			elseif not bInvert and ActorCommonManager.isCreatureTypeDnD(rActorCT, sType) then
			 	bReturn = true;
			 	break;
			end
		end
	end
	return bReturn;
end

-- End Conditional Operators

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
			RulesetEffectManager =  EffectManager5E
			RulesetActorManager = ActorManager5E
		elseif User.getRulesetName() == "4E" then
			RulesetEffectManager =  EffectManager4E
			RulesetActorManager = ActorManager4E
		elseif User.getRulesetName() == "3.5E" or User.getRulesetName() == "PFRPG" then
			RulesetEffectManager =  EffectManager35E
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

		checkConditional = RulesetEffectManager.checkConditional;
		RulesetEffectManager.checkConditional = customCheckConditional;

		ActionsManager.registerResultHandler("damage", customOnDamage);
		onDamage = ActionDamage.onDamage
		ActionDamage.onDamage = customOnDamage

		convertStringToDice = DiceManager.convertStringToDice
		DiceManager.convertStringToDice = customConvertStringToDice

		ActionsManager.registerResultHandler("effectbce", onEffectRollHandler)
		outputResult = ActionsManager.outputResult
		ActionsManager.outputResult = customOutputResult

		bMadNomadCharSheetEffectDisplay = EffectsManagerBCE.hasExtension("MNM Charsheet Effects Display")
	end
end


function onClose()

	if  User.getRulesetName() == "5E"  or
		User.getRulesetName() == "4E"  or
		User.getRulesetName() == "3.5E"  or
--		User.getRulesetName() == "2E"  or
		User.getRulesetName() == "PFRPG" then

		RulesetEffectManager.checkConditional = checkConditional;
		ActionDamage.onDamage = onDamage
		ActionsManager.unregisterResultHandler("effectbce")
		DiceManager.convertStringToDice = convertStringToDice
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEndDND)

		EffectsManagerBCE.removeCustomPreAddEffect(addEffectStart)
	end
end