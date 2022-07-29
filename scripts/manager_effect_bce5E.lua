--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local getDamageAdjust = nil
local parseEffects = nil
local evalAction = nil
local performMultiAction = nil
local bAdvancedEffects = nil
local resetHealth = nil
local onSave = nil
local bExpandedNPC = nil

function onInit()
	if User.getRulesetName() == "5E" then
		if Session.IsHost then
			OptionsManager.registerOption2("ALLOW_DUPLICATE_EFFECT", false, "option_Better_Combat_Effects",
			"option_Allow_Duplicate", "option_entry_cycler",
			{ labels = "option_val_off", values = "off",
				baselabel = "option_val_on", baseval = "on", default = "on" });

			OptionsManager.registerOption2("CONSIDER_DUPLICATE_DURATION", false, "option_Better_Combat_Effects",
			"option_Consider_Duplicate_Duration", "option_entry_cycler",
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" });

			OptionsManager.registerOption2("RESTRICT_CONCENTRATION", false, "option_Better_Combat_Effects",
			"option_Concentrate_Restrict", "option_entry_cycler",
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" });

			OptionsManager.registerOption2("AUTOPARSE_EFFECTS", false, "option_Better_Combat_Effects",
			"option_Autoparse_Effects", "option_entry_cycler",
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" });

		end

		--5E/3.5E BCE Tags
		EffectsManagerBCE.registerBCETag("SAVEA", EffectsManagerBCE.aBCEOneShotOptions)

		EffectsManagerBCE.registerBCETag("SAVES", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEADD", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVEADDP", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVEDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEONDMG", EffectsManagerBCE.aBCEDefaultOptionsAE)

		ActionsManager.registerResultHandler("save", onSaveRollHandler5E)
		--4E/5E
		EffectsManagerBCE.registerBCETag("DMGR",EffectsManagerBCE.aBCEDefaultOptions)

		resetHealth = CombatManager2.resetHealth
		CombatManager2.resetHealth = customResetHealth
		rest = CharManager.rest
		CharManager.rest= customRest
		getDamageAdjust = ActionDamage.getDamageAdjust
		ActionDamage.getDamageAdjust = customGetDamageAdjust
		parseEffects = PowerManager.parseEffects
		PowerManager.parseEffects = customParseEffects
		evalAction = PowerManager.evalAction
		PowerManager.evalAction = customEvalAction

		onSave = ActionSave.onSave
		ActionSave.onSave = onSaveRollHandler5E
		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost5E)
		EffectsManagerBCEDND.setProcessEffectOnDamage(onDamage5E)

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)

		bExpandedNPC = EffectsManagerBCE.hasExtension( "5E - Expanded NPCs")
		bAdvancedEffects = EffectsManagerBCE.hasExtension("AdvancedEffects")
		if bAdvancedEffects then
		 	performMultiAction = ActionsManager.performMultiAction
		 	ActionsManager.performMultiAction = customPerformMultiAction
		end
	end
end

function onClose()
	if User.getRulesetName() == "5E" then
		CharManager.rest = rest
		CombatManager2.resetHealth = resetHealth
		ActionDamage.getDamageAdjust = getDamageAdjust
		PowerManager.parseEffects = parseEffects

		ActionsManager.unregisterResultHandler("save")
		ActionSave.onSave = onSave
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost5E)

		if bAdvancedEffects then
		 	ActionsManager.performMultiAction = performMultiAction
		end
	end
end

--Advanced Effects
function customPerformMultiAction(draginfo, rActor, sType, rRolls)
	if rActor then
		rRolls[1].itemPath = rActor.itemPath
	end
	return performMultiAction(draginfo, rActor, sType, rRolls)
end
-- End Advanced Effects

function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
	local sDuplicateMsg = EffectManager5E.onEffectAddIgnoreCheck(nodeCT, rEffect)
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return sDuplicateMsg
	end
	local bIgnoreDuration = OptionsManager.isOption("CONSIDER_DUPLICATE_DURATION", "off");
	if OptionsManager.isOption("ALLOW_DUPLICATE_EFFECT", "off")  and not rEffect.sName:match("STACK") then
		for _, nodeEffect in pairs(nodeEffectsList.getChildren()) do
			if (DB.getValue(nodeEffect, "label", "") == rEffect.sName) and
					(DB.getValue(nodeEffect, "init", 0) == rEffect.nInit) and
					(bIgnoreDuration or (DB.getValue(nodeEffect, "duration", 0) == rEffect.nDuration)) and
					(DB.getValue(nodeEffect,"source_name", "") == rEffect.sSource) then
				sDuplicateMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rEffect.sName, Interface.getString("effect_status_exists"))
				break
			end
		end
	end
	return sDuplicateMsg
end

function customRest(nodeActor, bLong, bMilestone)
	EffectsManagerBCEDND.customRest(nodeActor, bLong, nil)
	rest(nodeActor, bLong)
end

-- For NPC
function customResetHealth (nodeCT, bLong)
	local rSource = ActorManager.resolveActor(nodeCT)

	local aTags = {"RESTS"}
	if bLong == true then
		table.insert(aTags, "RESTL")
	end

	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "RESTL" or tEffect.sTag == "RESTS" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		end
	end
	resetHealth(nodeCT,bLong)
end


function processEffectTurnStart5E(rSource)
	local aTags = {"SAVES"}
	local rEffectSource
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if(tEffect.sSource == "") then
			rEffectSource = rSource
		else
			rEffectSource = ActorManager.resolveActor(tEffect.sSource)
		end
		if tEffect.sTag == "SAVES" then
			saveEffect(rEffectSource, rSource, tEffect)
		end
	end
	return true
end

function processEffectTurnEnd5E(rSource)
	local aTags = {"SAVEE"}
	local rEffectSource
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if(tEffect.sSource == "") then
			rEffectSource = rSource
		else
			rEffectSource = ActorManager.resolveActor(tEffect.sSource)
		end
		if tEffect.sTag == "SAVEE" then
			saveEffect(rEffectSource, rSource, tEffect)
		end
	end
	return true
end

function addEffectPre5E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	local rSource
	if not rNewEffect.sSource or rNewEffect.sSource == "" then
		rSource = rActor
	else
		local nodeSource = DB.findNode(rNewEffect.sSource)
		rSource = ActorManager.resolveActor(nodeSource)
	end

	-- Save off original so we can match the name. Rebuilding a fully parsed effect
	-- will nuke spaces after a , and thus EE extension will not match names correctly.
	-- Consequently, if the name changes at all, AURA hates it and thus it isnt the same effect
	-- Really this is just to do some string replace. We just won't do string replace for any
	-- Effect that has FROMAURA;

	if  not rNewEffect.sName:upper():find("FROMAURA;") then
		local aOriginalComps = EffectManager.parseEffect(rNewEffect.sName);

		rNewEffect.sName = EffectManager5E.evalEffect(rSource, rNewEffect.sName)

		local aNewComps = EffectManager.parseEffect(rNewEffect.sName);
		aNewComps[1] = aOriginalComps[1]
		rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewComps);
	end

	replaceSaveDC(rNewEffect, rSource)

	if OptionsManager.isOption("RESTRICT_CONCENTRATION", "on") then
		local nDuration = rNewEffect.nDuration
		if rNewEffect.sUnits == "minute" then
			nDuration = nDuration*10
		end
		dropConcentration(rNewEffect, nDuration)
	end

	return true
end

function addEffectPost5E(sUser, sIdentity, nodeCT, rNewEffect, nodeEffect)
	local rTarget = ActorManager.resolveActor(nodeCT)
	if rNewEffect.sSource == "" then
		rSource = rTarget
	else
		rSource = ActorManager.resolveActor(rNewEffect.sSource)
	end

	local aTags = {"SAVEA"}
	local tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nodeEffect)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "SAVEA" then
			saveEffect(rSource, rTarget, tEffect)
		end
	end

	return true
end

function getDCEffectMod(nodeActor)
	local nDC = 0
	for _,nodeEffect in pairs(DB.getChildren(nodeActor, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local tEffectComps = EffectManager.parseEffect(sEffect)
		for _,sEffectComp in ipairs(tEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type == "DC" and (DB.getValue(nodeEffect, "isactive", 0) == 1) then
				nDC = tonumber(rEffectComp.mod) or 0
				break
			end
		end
	end
	return nDC
end

-- Replace SDC when applied from a power
function customEvalAction(rActor, nodePower, rAction)
	if rAction.type == "effect" and (rAction.sName:match("%[SDC]") or rAction.sName:match("%(SDC%)")) then
		local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower)
		if aPowerGroup and aPowerGroup.sSaveDCStat and DataCommon.ability_ltos[aPowerGroup.sSaveDCStat] then
			local nDC = 8 + aPowerGroup.nSaveDCMod + ActorManager5E.getAbilityBonus(rActor, aPowerGroup.sSaveDCStat)
			if aPowerGroup.nSaveDCProf == 1 then
				nDC = nDC + ActorManager5E.getAbilityBonus(rActor, "prf")
			end
			rAction.sName =  rAction.sName:gsub("%[SDC]", tostring(nDC))
			rAction.sName =  rAction.sName:gsub("%(SDC%)", tostring(nDC))
		end
	end
	evalAction(rActor, nodePower, rAction)
end

function replaceSaveDC(rNewEffect, rActor)
	if rNewEffect.sName:match("%[SDC]") and
			(rNewEffect.sName:match("SAVEE%s*:") or
			rNewEffect.sName:match("SAVES%s*:") or
			rNewEffect.sName:match("SAVEA%s*:") or
		    rNewEffect.sName:match("SAVEONDMG%s*:")) then
		local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor)
		local nSpellcastingDC = 0
		local bNewSpellcasting = true
		local nDC = getDCEffectMod(ActorManager.getCTNode(rActor))
		if sNodeType == "pc" then
			nSpellcastingDC = 8 +  ActorManager5E.getAbilityBonus(rActor, "prf") + nDC
			for _,nodeFeature in pairs(DB.getChildren(nodeActor, "featurelist")) do
				local sFeatureName = StringManager.trim(DB.getValue(nodeFeature, "name", ""):lower())
				if sFeatureName == "spellcasting" then
					local sDesc = DB.getValue(nodeFeature, "text", ""):lower();
					local sStat = sDesc:match("(%w+) is your spellcasting ability") or ""
					nSpellcastingDC = nSpellcastingDC + ActorManager5E.getAbilityBonus(rActor, sStat)
					--TODO savemod is the db tag in the power group to get the power modifier
					break
				end
			end
		elseif sNodeType == "ct" or sNodeType == "npc" then
			nSpellcastingDC = 8 +  ActorManager5E.getAbilityBonus(rActor, "prf") + nDC
			for _,nodeTrait in pairs(DB.getChildren(nodeActor, "traits")) do
				local sTraitName = StringManager.trim(DB.getValue(nodeTrait, "name", ""):lower())
				if sTraitName == "spellcasting" then
					local sDesc = DB.getValue(nodeTrait, "desc", ""):lower();
					local sStat = sDesc:match("its spellcasting ability is (%w+)") or ""
					nSpellcastingDC = nSpellcastingDC + ActorManager5E.getAbilityBonus(rActor, sStat)
					bNewSpellcasting = false
					break
				end
			end
			if bNewSpellcasting then
				for _,nodeAction in pairs(DB.getChildren(nodeActor, "actions")) do
					local sActionName = StringManager.trim(DB.getValue(nodeAction, "name", ""):lower())
					if sActionName == "spellcasting" then
						local sDesc = DB.getValue(nodeAction, "desc", ""):lower();
						nSpellcastingDC = nDC + (tonumber(sDesc:match("spell save dc (%d+)")) or 0)
						break
					end
				end
			end
		end
		rNewEffect.sName = rNewEffect.sName:gsub("%[SDC]", tostring(nSpellcastingDC))
	end
end

-- rSource is the source of the actor making the roll, hence it is the target of whatever is causing the same
-- rTarget is null for some reason.
function onSaveRollHandler5E(rSource, rTarget, rRoll)
	if  not rRoll.sSaveDesc or not rRoll.sSaveDesc:match("%[BCE]") then
		return onSave(rSource, rTarget, rRoll)
	end
	local nodeTarget =  DB.findNode(rRoll.sSource)
	local nodeSource = ActorManager.getCTNode(rSource)
	rTarget = ActorManager.resolveActor(nodeTarget)

	-- local nodeEffect = nil
	-- if rRoll.sEffectPath ~= "" then
	-- 	nodeEffect = DB.findNode(rRoll.sEffectPath)
	-- 	if nodeEffect and not rTarget then
	-- 		local nodeTarget = nodeEffect.getParent().getParent()
	-- 		rTarget = ActorManager.resolveActor(nodeTarget)
	-- 	end
	-- end

	-- something is wrong. Likely an extension messing with things
	if not rTarget or not rSource or not nodeTarget or not nodeSource then
	 	return onSave(rSource, rTarget, rRoll)
	end

	local tMatch
	local aTags

	local sNodeEffect = StringManager.trim(rRoll.sSaveDesc:gsub("%[[%a%s%d]*]", ""))
	local nodeEffect =  DB.findNode(sNodeEffect)
	local sEffectLabel = DB.getValue(nodeEffect, "label", "")
	local tParseEffect = EffectManager.parseEffect(sEffectLabel)
	local sLabel = StringManager.trim(tParseEffect[1]) or ""

	sNodeEffect = sNodeEffect:gsub("%.", "%%%.")
	sNodeEffect = StringManager.trim(sNodeEffect:gsub("%-", "%%%-"))

	rRoll.sSaveDesc = rRoll.sSaveDesc:gsub(sNodeEffect, sLabel)
	onSave(rSource, rTarget, rRoll)

	local nResult = ActionsManager.total(rRoll)
	local bAct = false
	-- Have the flip tag
	if rRoll.sSaveDesc:match("%[FLIP]") then
		if nResult < tonumber(rRoll.nTarget) then
			bAct = true
		end
	else
		if nResult >= tonumber(rRoll.nTarget) then
			bAct = true
		end
	end

	--Need the original effect because we only want to do things that are in the same effect
	--if we just pull all the tags on the Actor then we can't have multiple saves doing
	--multiple different things. We have to be careful about the one shot options expireing
	--our effect hence the check for nil
	if bAct and nodeEffect then
		aTags = {"SAVEADDP"}
		if rRoll.sSaveDesc:match( "%[HALF ON SAVE]") then
			table.insert(aTags, "SAVEDMG")
		end

		tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource, nil, nodeEffect)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADDP" then
				local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
				if next(rEffect) then
					rEffect.sSource = rRoll.sSource
					rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
					EffectManager.addEffect("", "", nodeSource, rEffect, true)
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rTarget, rSource, tEffect.rEffectComp, true, sLabel)
			end
		end
		if  rRoll.sSaveDesc:match("%[REMOVE ON SAVE]")  then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove");
		elseif rRoll.sSaveDesc:match("%[DISABLE ON SAVE]") then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Deactivate");
		end
	elseif nodeEffect  then
		aTags = {"SAVEADD", "SAVEDMG"}
		tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource, nil, nodeEffect)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADD" then
				local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
				if next(rEffect) then
					rEffect.sSource = rRoll.sSource
					rEffect.nInit  = DB.getValue(nodeTarget, "initresult", 0)
					EffectManager.addEffect("", "", nodeSource, rEffect, true)
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rTarget, rSource, tEffect.rEffectComp, false, sLabel)
			end
		end
	end
end

function onDamage5E(rSource,rTarget)
	local aTags = {"SAVEONDMG"}
	local rEffectSource

	local tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
	for _,tEffect in pairs(tMatch) do
		if(tEffect.sSource == "") then
			rEffectSource = rSource
		else
			rEffectSource = ActorManager.resolveActor(tEffect.sSource)
		end
		if tEffect.sTag == "SAVEONDMG" then
			saveEffect(rEffectSource, rTarget, tEffect)
		end
	end
	return true
end

function saveEffect(rSource, rTarget, tEffect)
	local aParsedRemiander = StringManager.parseWords(tEffect.rEffectComp.remainder[1])
	local sAbility = DataCommon.ability_stol[aParsedRemiander[1]]

	if  sAbility and sAbility ~= "" then
		local bSecret  = false
		local rAction = {}
		rAction.savemod = tonumber(aParsedRemiander[2])

		if not rAction.savemod then
			rAction.savemod = tEffect.rEffectComp.mod
		end
		if(type(tEffect.nodeCT) == "databasenode") then
			rAction.label = tEffect.nodeCT.getPath()
		else
			rAction.label = ""
		end
		if tEffect.rEffectComp.original:match("%(M%)") then
			rAction.magic = true
		end
		if tEffect.rEffectComp.original:match("%(H%)") then
			rAction.onmissdamage = "half"
		end
		local rSaveVsRoll =	ActionPower.getSaveVsRoll(rSource, rAction)

		rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [" .. StringManager.capitalize(aParsedRemiander[1]) .. " DC " .. rSaveVsRoll.nMod .. "]"
		if tEffect.nGMOnly == 1 then
			bSecret = true
		end
		if tEffect.rEffectComp.original:match("%(D%)") then
			rSaveVsRoll.bDisableOnSave = true
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [DISABLE ON SAVE]";
		end
		if tEffect.rEffectComp.original:match("%(R%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [REMOVE ON SAVE]";
			rSaveVsRoll.bRemoveOnSave = true
		end
		if tEffect.rEffectComp.original:match("%(F%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [FLIP]";
			rSaveVsRoll.bActonFail = true
		end
		local aSaveFilter = {};
		table.insert(aSaveFilter, sAbility:lower());

		-- if we don't have a filter, modSave will figure out the other adv/dis later
		if #(EffectManager5E.getEffectsByType(rTarget, "ADVSAV", aSaveFilter, rSource)) > 0 then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [ADV]"
		end
		if #(EffectManager5E.getEffectsByType(rTarget, "DISSAV", aSaveFilter, rSource)) > 0 then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [DIS]"
		end
		rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [BCE]"
		-- Pass the effect node if it wasn't expired by a One Shot
		if(type(tEffect.nodeCT) == "databasenode") then
			rSaveVsRoll.sEffectPath = tEffect.nodeCT.getPath()
		else
			rSaveVsRoll.sEffectPath = ""
		end

		ActionSave.performVsRoll(nil,rTarget, sAbility, rSaveVsRoll.nMod, bSecret, rSource, false, rSaveVsRoll.sDesc)
	end
end


function getReductionType(rSource, rTarget, sEffectType, rDamageOutput)
	local tEffects = EffectManager5E.getEffectsByType(rTarget, sEffectType, rDamageOutput.aDamageFilter, rSource);
	local aFinal = {};
	for _,v in pairs(tEffects) do
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
	local nDamageAdjust
	local nReduce = 0
	local bVulnerable, bResist
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
		local nLocalReduce = ActionDamage.checkNumericalReductionType(aReduce, aSrcDmgClauseTypes, v)
		--We need to do this nonsense because we need to reduce damage before resist calculation
		if nLocalReduce > 0 then
			rDamageOutput.aDamageTypes[k] = rDamageOutput.aDamageTypes[k] - nLocalReduce
			nDamage = nDamage - nLocalReduce
		end
		nReduce = nReduce + nLocalReduce
	end
	if (nReduce > 0) then
		table.insert(rDamageOutput.tNotifications, "[REDUCED]");
	end
	nDamageAdjust, bVulnerable, bResist = getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	nDamageAdjust = nDamageAdjust - nReduce
	return nDamageAdjust, bVulnerable, bResist
end

--5E Only - Check if this effect has concentration and drop all previous effects of concentration from the source
function dropConcentration(rNewEffect, nDuration)
	if(rNewEffect.sName:match("%(C%)")) then
		local nodeCT = CombatManager.getActiveCT()
		local sSourceName = rNewEffect.sSource
		if sSourceName == "" then
			sSourceName = ActorManager.getCTPathFromActorNode(nodeCT)
		end
		local sSource
		local ctEntries = CombatManager.getSortedCombatantList()
		local tEffectComps = EffectManager.parseEffect(rNewEffect.sName)
		local sNewEffectTag = tEffectComps[1]
		for _, nodeCTConcentration in pairs(ctEntries) do
			if nodeCT == nodeCTConcentration then
				sSource = ""
			else
				sSource = sSourceName
			end
			for _,nodeEffect in pairs(DB.getChildren(nodeCTConcentration, "effects")) do
				local sEffect = DB.getValue(nodeEffect, "label", "")
				tEffectComps = EffectManager.parseEffect(sEffect)
				local sEffectTag = tEffectComps[1]
				if (sEffect:match("%(C%)") and (DB.getValue(nodeEffect, "source_name", "") == sSource)) and
						(sEffectTag ~= sNewEffectTag) or
						((sEffectTag == sNewEffectTag and (DB.getValue(nodeEffect, "duration", 0) ~= nDuration))) then
							EffectsManagerBCE.modifyEffect(nodeEffect, "Remove", sEffect)
				end
			end
		end
	end
end

function customParseEffects(sPowerName, aWords)
	if OptionsManager.isOption("AUTOPARSE_EFFECTS", "off") then
		return parseEffects(sPowerName, aWords)
	end
	local effects = {};
	local rCurrent = nil;
	local rPrevious = nil;
	local i = 1;
	local bStart = false
	local bSource = false
	while aWords[i] do
		if StringManager.isWord(aWords[i], "damage") then
			i, rCurrent = PowerManager.parseDamagePhrase(aWords, i);
			if rCurrent then
				if StringManager.isWord(aWords[i+1], "at") and
						StringManager.isWord(aWords[i+2], "the") and
						StringManager.isWord(aWords[i+3], { "start", "end" }) and
						StringManager.isWord(aWords[i+4], "of") then
					if StringManager.isWord(aWords[i+3],  "start") then
						bStart = true
					end
					local nTrigger = i + 4;
					if StringManager.isWord(aWords[nTrigger+1], "each") and
							StringManager.isWord(aWords[nTrigger+2], "of") then
						if StringManager.isWord(aWords[nTrigger+3], "its") then
							nTrigger = nTrigger + 3;
						else
							nTrigger = nTrigger + 4;
							bSource = true
						end
					elseif StringManager.isWord(aWords[nTrigger+1], "its") then
						nTrigger = i;
					elseif StringManager.isWord(aWords[nTrigger+1], "your") then
						nTrigger = nTrigger + 1;
					end
					if StringManager.isWord(aWords[nTrigger+1], { "turn", "turns" }) then
						nTrigger = nTrigger + 1;
					end
					rCurrent.endindex = nTrigger;

					if StringManager.isWord(aWords[rCurrent.startindex - 1], "takes") and
							StringManager.isWord(aWords[rCurrent.startindex - 2], "and") and
							StringManager.isWord(aWords[rCurrent.startindex - 3], DataCommon.conditions) then
						rCurrent.startindex = rCurrent.startindex - 2;
					end

					local aName = {};
					for _,v in ipairs(rCurrent.clauses) do
						local sDmg = StringManager.convertDiceToString(v.dice, v.modifier);
						if v.dmgtype and v.dmgtype ~= "" then
							sDmg = sDmg .. " " .. v.dmgtype;
						end
						if bStart == true and bSource == false then
							table.insert(aName, "DMGO: " .. sDmg)
						elseif bStart ==false and bSource == false then
							table.insert(aName, "DMGOE: " .. sDmg)
						elseif bStart == true and bSource == true then
							table.insert(aName, "SDMGOS: " .. sDmg)
						elseif bStart == false and bSource == true then
							table.insert(aName, "SDMGOE: " .. sDmg)
						end
					end
					rCurrent.clauses = nil;
					rCurrent.sName = table.concat(aName, "; ");
					rPrevious = rCurrent
				elseif StringManager.isWord(aWords[rCurrent.startindex - 1], "extra") then
					rCurrent.startindex = rCurrent.startindex - 1;
					rCurrent.sTargeting = "self";
					rCurrent.sApply = "roll";

					local aName = {};
					for _,v in ipairs(rCurrent.clauses) do
						local sDmg = StringManager.convertDiceToString(v.dice, v.modifier);
						if v.dmgtype and v.dmgtype ~= "" then
							sDmg = sDmg .. " " .. v.dmgtype;
						end
						table.insert(aName, "DMG: " .. sDmg);
					end
					rCurrent.clauses = nil;
					rCurrent.sName = table.concat(aName, "; ");
					rPrevious = rCurrent
				else
					rCurrent = nil;
				end
			end
		-- Handle ongoing saves
		elseif  StringManager.isWord(aWords[i], "repeat") and StringManager.isWord(aWords[i+2], "saving") and
			StringManager.isWord(aWords[i +3], "throw") then
				local tSaves = PowerManager.parseSaves(sPowerName, aWords, false, false)
				local aSave = tSaves[#tSaves]
				if not aSave  then
					break
				end
				local j = i+3
				local bStartTurn = false
				local bEndSuccess = false
				local aName = {};
				local sClause

				while aWords[j] do
					if StringManager.isWord(aWords[j], "start") then
						bStartTurn = true
					end
					if StringManager.isWord(aWords[j], "ending") then
						bEndSuccess = true
					end
					j = j+1
				end
				if bStartTurn == true then
					sClause = "SAVES:"
				else
					sClause = "SAVEE:"
				end

				sClause  = sClause .. " " .. DataCommon.ability_ltos[aSave.save]
				sClause  = sClause .. " " .. aSave.savemod

				if bEndSuccess == true then
					sClause = sClause .. " (R)"
				end

				table.insert(aName, aSave.label);
				if rPrevious then
					table.insert(aName, rPrevious.sName)
				end
				table.insert(aName, sClause);
				rCurrent = {}
				rCurrent.startindex = i
				rCurrent.endindex = i+3
				rCurrent.sName = table.concat(aName, "; ");
		elseif (i > 1) and StringManager.isWord(aWords[i], DataCommon.conditions) then
			local bValidCondition = false;
			local nConditionStart = i;
			local j = i - 1;
			local sTurnModifier = getTurnModifier(aWords, i)
			while aWords[j] do
				if StringManager.isWord(aWords[j], "be") then
					if StringManager.isWord(aWords[j-1], "or") then
						bValidCondition = true;
						nConditionStart = j;
						break;
					end

				elseif StringManager.isWord(aWords[j], "being") and
						StringManager.isWord(aWords[j-1], "against") then
					bValidCondition = true;
					nConditionStart = j;
					break;

				--elseif StringManager.isWord(aWords[j], { "also", "magically" }) then

				-- Special handling: Blindness/Deafness
				elseif StringManager.isWord(aWords[j], "or") and StringManager.isWord(aWords[j-1], DataCommon.conditions) and
						StringManager.isWord(aWords[j-2], "either") and StringManager.isWord(aWords[j-3], "is") then
					bValidCondition = true;
					break;

				elseif StringManager.isWord(aWords[j], { "while", "when", "cannot", "not", "if", "be", "or" }) then
					bValidCondition = false;
					break;

				elseif StringManager.isWord(aWords[j], { "target", "creature", "it" }) then
					if StringManager.isWord(aWords[j-1], "the") then
						j = j - 1;
					end
					nConditionStart = j;

				elseif StringManager.isWord(aWords[j], "and") then
					if #effects == 0 then
						break;
					elseif effects[#effects].endindex ~= j - 1 then
						if not StringManager.isWord(aWords[i], "unconscious") and not StringManager.isWord(aWords[j-1], "minutes") then
							break;
						end
					end
					bValidCondition = true;
					nConditionStart = j;

				elseif StringManager.isWord(aWords[j], "is") then
					if bValidCondition or StringManager.isWord(aWords[i], "prone") or
							(StringManager.isWord(aWords[i], "invisible") and StringManager.isWord(aWords[j-1], {"wearing", "wears", "carrying", "carries"})) then
						break;
					end
					bValidCondition = true;
					nConditionStart = j;

				elseif StringManager.isWord(aWords[j], DataCommon.conditions) then
					break;

				elseif StringManager.isWord(aWords[i], "poisoned") then
					if (StringManager.isWord(aWords[j], "instead") and StringManager.isWord(aWords[j-1], "is")) then
						bValidCondition = true;
						nConditionStart = j - 1;
						break;
					elseif StringManager.isWord(aWords[j], "become") then
						bValidCondition = true;
						nConditionStart = j;
						break;
					end

				elseif StringManager.isWord(aWords[j], {"knock", "knocks", "knocked", "fall", "falls"}) and StringManager.isWord(aWords[i], "prone")  then
					bValidCondition = true;
					nConditionStart = j;

				elseif StringManager.isWord(aWords[j], {"knock", "knocks", "fall", "falls", "falling", "remain", "is"}) and StringManager.isWord(aWords[i], "unconscious") then
					if StringManager.isWord(aWords[j], "falling") and StringManager.isWord(aWords[j-1], "of") and StringManager.isWord(aWords[j-2], "instead") then
						break;
					end
					if StringManager.isWord(aWords[j], "fall") and StringManager.isWord(aWords[j-1], "you") and StringManager.isWord(aWords[j-1], "if") then
						break;
					end
					if StringManager.isWord(aWords[j], "falls") and StringManager.isWord(aWords[j-1], "or") then
						break;
					end
					bValidCondition = true;
					nConditionStart = j;
					if StringManager.isWord(aWords[j], "fall") and StringManager.isWord(aWords[j-1], "or") then
						break;
					end

				elseif StringManager.isWord(aWords[j], {"become", "becomes"}) and StringManager.isWord(aWords[i], "frightened")  then
					bValidCondition = true;
					nConditionStart = j;
					break;

				elseif StringManager.isWord(aWords[j], {"turns", "become", "becomes"})
						and StringManager.isWord(aWords[i], {"invisible"}) then
					if StringManager.isWord(aWords[j-1], {"can't", "cannot"}) then
						break;
					end
					bValidCondition = true;
					nConditionStart = j;

				-- Special handling: Blindness/Deafness
				elseif StringManager.isWord(aWords[j], "either") and StringManager.isWord(aWords[j-1], "is") then
					bValidCondition = true;
					break;

				else
					break;
				end
				j = j - 1;
			end

			if bValidCondition then
				rCurrent = {};
				if not sPowerName then
					rCurrent.sName = StringManager.capitalize(aWords[i]);
				else
					rCurrent.sName = sPowerName .. "; " .. StringManager.capitalize(aWords[i]);
				end
				rCurrent.startindex = nConditionStart;
				rCurrent.endindex = i;
				if sRemoveTurn ~= "" then
					rCurrent.sName = rCurrent.sName .. "; " .. sTurnModifier
				end
				rPrevious = rCurrent
			end
		end

		if rCurrent then
			PowerManager.parseEffectsAdd(aWords, i, rCurrent, effects);
			rCurrent = nil;
		end

		i = i + 1;
	end

	if rCurrent then
		PowerManager.parseEffectsAdd(aWords, i - 1, rCurrent, effects);
	end

	-- Handle duration field in NPC spell translations
	i = 1;
	while aWords[i] do
		if StringManager.isWord(aWords[i], "duration") and StringManager.isWord(aWords[i+1], ":") then
			j = i + 2;
			local bConc = false;
			if StringManager.isWord(aWords[j], "concentration") and StringManager.isWord(aWords[j+1], "up") and StringManager.isWord(aWords[j+2], "to") then
				bConc = true;
				j = j + 3;
			end
			if StringManager.isNumberString(aWords[j]) and StringManager.isWord(aWords[j+1], {"round", "rounds", "minute", "minutes", "hour", "hours", "day", "days"}) then
				local nDuration = tonumber(aWords[j]) or 0;
				local sUnits = "";
				if StringManager.isWord(aWords[j+1], {"minute", "minutes"}) then
					sUnits = "minute";
				elseif StringManager.isWord(aWords[j+1], {"hour", "hours"}) then
					sUnits = "hour";
				elseif StringManager.isWord(aWords[j+1], {"day", "days"}) then
					sUnits = "day";
				end

				for _,vEffect in ipairs(effects) do
					if not vEffect.nDuration and (vEffect.sName ~= "Prone") then
						if bConc then
							vEffect.sName = vEffect.sName .. "; (C)";
						end
						vEffect.nDuration = nDuration;
						vEffect.sUnits = sUnits;
					end
				end

				-- Add direct effect right from concentration text
				if bConc then
					local rConcentrate = {};
					rConcentrate.sName = sPowerName .. "; (C)";
					rConcentrate.startindex = i;
					rConcentrate.endindex = j+1;

					PowerManager.parseEffectsAdd(aWords, i, rConcentrate, effects);
				end
			end
		end
		i = i + 1;
	end

	return effects;
end

function getTurnModifier(aWords, i)
	local sRemoveTurn = ""
	while aWords[i] do
		if StringManager.isWord(aWords[i], "until") and
			StringManager.isWord(aWords[i+1], "the") and
			StringManager.isWord(aWords[i+2], {"start","end"}) and
			StringManager.isWord(aWords[i+3], "of") then
			if StringManager.isWord(aWords[i+4], "its") then
				if StringManager.isWord(aWords[i+2], "start") then
					sRemoveTurn = "TURNRS"
				else
					sRemoveTurn = "TURNRE"
				end
			else
				if StringManager.isWord(aWords[i+2], "start") then
					sRemoveTurn = "STURNRS"
				else
					sRemoveTurn = "STURNRE"
				end
			end
		end
		i = i +1
	end
	return sRemoveTurn
end
