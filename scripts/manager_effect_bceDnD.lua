--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local RulesetEffectManager = nil
local RulesetActorManager = nil
local onDamage = nil
local fProcessEffectOnDamage = nil
local bMadNomadCharSheetEffectDisplay = false

function setProcessEffectOnDamage(ProcessEffectOnDamage)
	fProcessEffectOnDamage = ProcessEffectOnDamage
end

function customRest(nodeActor, bLong, bMilestone)
	local nodeCT = ActorManager.getCTNode(nodeActor)
	local rSource = ActorManager.resolveActor(nodeActor)
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		if EffectsManagerBCE.processEffect(rSource,nodeEffect,"RESTS") or (bLong == true and EffectsManagerBCE.processEffect(rSource,nodeEffect,"RESTL")) then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove", sEffect)
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


function applyOngoingDamage(rSource, rTarget, nodeEffect, bHalf, bAdd)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local rAction = {}
	rAction.label =  ""
	rAction.clauses = {}
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = RulesetEffectManager.parseEffectComp(sEffectComp)
		if (rEffectComp.type == "DMGA" and bAdd == true) or ( bAdd == false and (rEffectComp.type == "SAVEDMG" or rEffectComp.type == "DMGOE" or rEffectComp.type == "SDMGOE" or rEffectComp.type == "SDMGOS")) then	
			local aClause = {}
			local rDmgInfo = RulesetEffectManager.parseEffectComp(rEffectComp.original)
			aClause.dice = rDmgInfo.dice;
			aClause.modifier = rDmgInfo.mod
			aClause.dmgtype = string.lower(table.concat(rDmgInfo.remainder, ","))
			table.insert(rAction.clauses, aClause)
		elseif rEffectComp.type == "" and rAction.label == "" then
			rAction.label = sEffectComp
		end
	end
	if rAction.label == "" then
		rAction.label = "Ongoing Effect"
	end
	if next(rAction.clauses) ~= nil then
		local rRoll = ActionDamage.getRoll(rTarget, rAction)
		if bHalf == true then
			rRoll.sDesc = rRoll.sDesc .. " [HALF]"
		end
		ActionsManager.actionDirect(rSource, "damage", {rRoll}, {{rTarget}})
		--if EffectManager.isTargetedEffect(nodeEffect) then
		--	local aTargets = EffectManager.getEffectTargets(nodeEffect)
		--	ActionsManager.actionRoll(rSource, {aTargets}, {rRoll})
		--else
		--	ActionsManager.actionRoll(rSource, {{rTarget}}, {rRoll})
		--end
	end	
end

function applyOngoingRegen(rSource, rTarget, nodeEffect, bAdd)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local rAction = {}
	rAction.label =  ""
	rAction.clauses = {}
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = RulesetEffectManager.parseEffectComp(sEffectComp)
		if (rEffectComp.type == "REGENA" and bAdd == true) or ( bAdd == false and (rEffectComp.type == "REGENE" or rEffectComp.type == "SREGENS" or rEffectComp.type == "SREGENE")) then	
			local aClause = {}
			local rDmgInfo = RulesetEffectManager.parseEffectComp(rEffectComp.original)
			aClause.dice = rDmgInfo.dice;
			aClause.modifier = rDmgInfo.mod
			aClause.dmgtype = string.lower(table.concat(rDmgInfo.remainder, ","))
			table.insert(rAction.clauses, aClause)
		elseif rEffectComp.type == "" and rAction.label == "" then
			rAction.label = sEffectComp
		end
	end
	if rAction.label == "" then
		rAction.label = "Ongoing Regeneration"
	end
	if next(rAction.clauses) ~= nil then
		local rRoll = ActionHeal.getRoll(rTarget, rAction)
		ActionsManager.actionDirect(rSource, "heal", {rRoll}, {{rTarget}})
	end	
end


function processEffectTurnStartDND(sourceNodeCT, nodeCT, nodeEffect)
	local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
	local rSourceEffect = ActorManager.resolveActor(sEffectSource)
	local sSourceName = sourceNodeCT.getNodeName()
	if rSourceEffect == nil then
		rSourceEffect = rSource
	end
	if sEffectSource ~= nil  and (sSourceName == sEffectSource or (sEffectSource == "" and nodeCT == sourceNodeCT)) then
		local rTargetEffect = ActorManager.resolveActor(nodeEffect.getParent().getParent().getPath())
		if EffectsManagerBCE.processEffect(rTargetEffect,nodeEffect,"SDMGOS", rSourceEffect) then
			local rTargetEffect = ActorManager.resolveActor(nodeEffect.getParent().getParent().getPath())
			applyOngoingDamage(rSourceEffect, rTargetEffect, nodeEffect, false,false)
		end
		if EffectsManagerBCE.processEffect(rTargetEffect,nodeEffect,"SREGENS", rSourceEffect) then
			local rTargetEffect = ActorManager.resolveActor(nodeEffect.getParent().getParent().getPath())
			applyOngoingRegen(rSourceEffect, rTargetEffect, nodeEffect, false)
		end    
	end
	return true
end

function processEffectTurnEndDND(sourceNodeCT, nodeCT, nodeEffect)
	local rSource = ActorManager.resolveActor(sourceNodeCT)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
	local sSourceName = sourceNodeCT.getNodeName()
	local rSourceEffect = ActorManager.resolveActor(sEffectSource)
	if rSourceEffect == nil then
		rSourceEffect = rSource
	end
	if nodeCT == sourceNodeCT then
		if EffectsManagerBCE.processEffect(rSource,nodeEffect,"DMGOE") and not sEffect:match("SDMGOE") then
				applyOngoingDamage(rSourceEffect, rSource, nodeEffect, false, false)
		end
		if EffectsManagerBCE.processEffect(rSource,nodeEffect,"REGENE") and not sEffect:match("SREGENE") then
			applyOngoingRegen(rSourceEffect, rSource, nodeEffect, false)
		end
	end

	if sEffectSource ~= nil   and (sSourceName == sEffectSource or (sEffectSource == "" and nodeCT == sourceNodeCT))  then
		local rTargetEffect = ActorManager.resolveActor(nodeEffect.getParent().getParent().getPath())
		if EffectsManagerBCE.processEffect(rTargetEffect,nodeEffect,"SDMGOE", rSourceEffect) then
			applyOngoingDamage(rSourceEffect, rTargetEffect, nodeEffect, false, false)
		end   
		if EffectsManagerBCE.processEffect(rTargetEffect,nodeEffect,"SREGENE", rSourceEffect) then
			applyOngoingRegen(rSourceEffect, rTargetEffect, nodeEffect, false)
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

	-- get temp hp and wounds after damage
	local nTempHP, nWounds = getTempHPAndWounds(rTarget)
	
	if OptionsManager.isOption("TEMP_IS_DAMAGE", "on") then
		-- If no damage was applied then return
		if nWoundsPrev >= nWounds and nTempHPPrev <= nTempHP then
			return
		end
		else
			if nWoundsPrev >= nWounds then
				return
		end
	end
	-- Loop through effects on the target of the damage
	for _,nodeEffect in pairs(DB.getChildren(nodeTarget, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
	
		if EffectsManagerBCE.processEffect(rTarget,nodeEffect,"DMGRT", rSource) then	
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove")
			break
		end
		if (fProcessEffectOnDamage ~= nil) then
			fProcessEffectOnDamage(rSource,rTarget, nodeEffect)
		end
		if EffectsManagerBCE.processEffect(rTarget,nodeEffect,"DMGAT", rSource, true) then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Activate")		
		end
		if EffectsManagerBCE.processEffect(rTarget,nodeEffect,"DMGDT", rSource) then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Deactivate")
		end
		if sEffect:match("TDMGADDT") or sEffect:match("TDMGADDS") then
			local rEffect = EffectsManagerBCE.matchEffect(sEffect)
			if rEffect.sName ~= nil then
				-- Set the node that applied the effect
				rEffect.sSource = ActorManager.getCTNodeName(rTarget)
				rEffect.nInit  = DB.getValue(nodeTarget, "initresult", 0)
				if EffectsManagerBCE.processEffect(rSource,nodeEffect,"TDMGADDT", rTarget) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), rEffect, true)
				end
				if EffectsManagerBCE.processEffect(rSource,nodeEffect,"TDMGADDS", rTarget) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rSource), rEffect, true)
				end
			end
		end
	end
	-- Loop though the effects on the source of the damage
	for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		if sEffect:match("SDMGADDT") or sEffect:match("SDMGADDS") then
			local rEffect = EffectsManagerBCE.matchEffect(sEffect)
			if rEffect ~= nil and rEffect.sName ~= nil then
				rEffect.sSource = ActorManager.getCTNodeName(sSource)
				rEffect.nInit  = DB.getValue(nodeSource, "initresult", 0)
				if EffectsManagerBCE.processEffect(rTarget,nodeEffect,"SDMGADDT", rSource) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), rEffect, true)
				end
				if EffectsManagerBCE.processEffect(rTarget,nodeEffect,"SDMGADDS", rSource) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rSource), rEffect, true)
				end
			end
		end
	end
end

function addEffectStart(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	replaceAbilityScores(rNewEffect, rActor)
	replaceAbilityModifier(rNewEffect, rActor)
	local rRoll = {}
	rRoll = isDie(rNewEffect.sName)
	if next(rRoll) ~= nil and next(rRoll.aDice) ~= nil then
		rRoll.rActor = rActor
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
		local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
		for _,sEffectComp in ipairs(aEffectComps) do
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

function replaceAbilityModifier(rNewEffect, rActor)
	if rNewEffect.sName:match("%[STR]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[STR]", tostring(RulesetActorManager.getAbilityBonus(rActor, "strength")))
	elseif rNewEffect.sName:match("%[DEX]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[DEX]", tostring(RulesetActorManager.getAbilityBonus(rActor, "dexterity")))
	elseif rNewEffect.sName:match("%[CON]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[CON]", tostring(RulesetActorManager.getAbilityBonus(rActor, "constitution")))
	elseif rNewEffect.sName:match("%[WIS]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[WIS]", tostring(RulesetActorManager.getAbilityBonus(rActor, "wisdom")))
	elseif rNewEffect.sName:match("%[INT]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[INT]", tostring(RulesetActorManager.getAbilityBonus(rActor, "intelligence")))
	elseif rNewEffect.sName:match("%[CHA]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[CHA]", tostring(RulesetActorManager.getAbilityBonus(rActor, "charisma")))
	end
end

function isDie(sEffect)
	local rRoll = {}
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local nMatch = 0
	for kEffectComp,sEffectComp in ipairs(aEffectComps) do
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
	elseif sTargetNodeType == "ct" then
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
			OptionsManager.registerOption2("TEMP_IS_DAMAGE", false, "option_Better_Combat_Effects", 
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

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEndDND)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectStart)
		
		-- save off the originals so we play nice with others
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

		ActionDamage.onDamage = onDamage
		ActionsManager.unregisterResultHandler("damage")
		ActionsManager.unregisterResultHandler("effectbce")

		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStartDND)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEndDND)

		EffectsManagerBCE.removeCustomPreAddEffect(addEffectStart)
	end
end