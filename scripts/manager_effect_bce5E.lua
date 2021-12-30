--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local bMadNomadCharSheetEffectDisplay = false
local bAutomaticSave = false
local restChar = nil
local getDamageAdjust = nil
local parseEffects = nil

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
		EffectsManagerBCE.registerBCETag("SAVEADD", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEADDP", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEONDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVERESTL", EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("DMGR",EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("SSAVES", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SSAVEE", EffectsManagerBCE.aBCESourceMattersOptions)


		rest = CharManager.rest
		CharManager.rest = customRest
		getDamageAdjust = ActionDamage.getDamageAdjust
		ActionDamage.getDamageAdjust = customGetDamageAdjust
		parseEffects = PowerManager.parseEffects
		PowerManager.parseEffects = customParseEffects

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost5E)
		EffectsManagerBCEDND.setProcessEffectOnDamage(onDamage)

		ActionsManager.registerResultHandler("save", onSaveRollHandler5E)
		ActionsManager.registerModHandler("save", onModSaveHandler)

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)
	
		aExtensions = Extension.getExtensions()
		for _,sExtension in ipairs(aExtensions) do
			tExtension = Extension.getExtensionInfo(sExtension)
			if (tExtension.name == "MNM Charsheet Effects Display") then
				bMadNomadCharSheetEffectDisplay = true
			end
			if (tExtension.name == "5E - Automatic Save Advantage") then
				bAutomaticSave = true
			end
			
		end
	end
end

function onClose()
	if User.getRulesetName() == "5E" then 
		CharManager.rest = rest
		ActionDamage.getDamageAdjust = getDamageAdjust
		PowerManager.parseEffects = parseEffects
		ActionsManager.unregisterResultHandler("save")
		ActionsManager.unregisterModHandler("save")
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost5E)

	end
end

function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
	local sDuplicateMsg = nil; 
	sDuplicateMsg = EffectManager5E.onEffectAddIgnoreCheck(nodeCT, rEffect)
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return sDuplicateMsg
	end
	local bIgnoreDuration = OptionsManager.isOption("CONSIDER_DUPLICATE_DURATION", "off");
	if OptionsManager.isOption("ALLOW_DUPLICATE_EFFECT", "off")  and not rEffect.sName:match("STACK") then
		for k, nodeEffect in pairs(nodeEffectsList.getChildren()) do
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


function processEffectTurnStart5E(rSource)
	local tMatch = {}
	local aTags = {"SAVES"}
	local rEffectSource = {}

	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
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
	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	local aTags = {"SSAVES"}
	for _, nodeCT in pairs(ctEntries) do
		local rActor = ActorManager.resolveActor(nodeCT)
		tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rSource, rSource)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SSAVES" then
				saveEffect(rSource, rActor, tEffect)
			end
		end
	end
	return true
end

function processEffectTurnEnd5E(rSource)
	local tMatch = {}
	local aTags = {"SAVEE"}
	local rEffectSource = {}

	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
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

	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	local aTags = {"SSAVEE"}
	for _, nodeCT in pairs(ctEntries) do
		local rActor = ActorManager.resolveActor(nodeCT)
		tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rSource, rSource)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SSAVEE" then
				saveEffect(rSource, rActor, tEffect)
			end
		end
	end


	return true
end

function addEffectPre5E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	-- Repalace effects with () that fantasygrounds will autocalc with [ ]
	local aReplace = {"PRF", "LVL"}
	for _,sClass in pairs(DataCommon.classes) do
		table.insert(aReplace, sClass:upper())	
	end
	for _,sAbility in pairs(DataCommon.abilities) do
		table.insert(aReplace, DataCommon.ability_ltos[sAbility]:upper())
	end
	for _,sTag in pairs(aReplace) do
		local sMatchString = "%([%-H%d+]?" .. sTag .. "%)"
		local sSubMatch = rNewEffect.sName:match(sMatchString)
		if sSubMatch ~= nil then
			sSubMatch = sSubMatch:gsub("%-", "%%%-")
			sSubMatch = sSubMatch:gsub("%(", "%%%[")
			sSubMatch = sSubMatch:gsub("%)", "]")
			rNewEffect.sName = rNewEffect.sName:gsub(sMatchString, sSubMatch)
		end
	end

	if rNewEffect.sName:match("EFFINIT:%s*%-?%d+") then
		local sInit = rNewEffect.sName:match("%d+")
		rNewEffect.nInit = tonumber(sInit)
	end
	local rActor = ActorManager.resolveActor(nodeCT)
	local rSource = nil
	if rNewEffect.sSource == nil or rNewEffect.sSource == "" then
		rSource = rActor
	else
		local nodeSource = DB.findNode(rNewEffect.sSource)
		rSource = ActorManager.resolveActor(nodeSource)		
	end
	rNewEffect.sName = EffectManager5E.evalEffect(rSource, rNewEffect.sName)
	replaceSaveDC(rNewEffect, rSource)
	abilityReplacement(rNewEffect,rSource)

	if OptionsManager.isOption("RESTRICT_CONCENTRATION", "on") then
		local nDuration = rNewEffect.nDuration
		if rNewEffect.sUnits == "minute" then
			nDuration = nDuration*10
		end
		dropConcentration(rNewEffect, nDuration)
	end

	return true
end

function addEffectPost5E(sUser, sIdentity, nodeCT, rNewEffect)
	local rTarget = ActorManager.resolveActor(nodeCT)
	local rSource = {}
	if rNewEffect.sSource == "" then
		rSource = rTarget
	else
		rSource = ActorManager.resolveActor(rNewEffect.sSource)
	end

	local tMatch = {}
	local aTags = {"SAVEA"}

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "SAVEA" then
			saveEffect(rSource, rTarget, tEffect)
		end
	end

	if rNewEffect.sName:lower():match("unconscious") and EffectManager5E.hasEffectCondition(nodeCT, "Unconscious") and not EffectManager5E.hasEffectCondition(nodeCT, "Prone") then
		local rProne = {sName = "Prone" , nInit = rNewEffect.nInit, nDuration = rNewEffect.nDuration, sSource = rNewEffect.sSource, nGMOnly = rNewEffect.nGMOnly}
		EffectManager.addEffect("", "", nodeCT, rProne, true)
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

--when effect has tags, [PRF],[LVL], in a remiander evalEffect evaluates and returns those as the mod and not part of the remainder. 
--For our save DC to work correctly we need to massage that number a bit and move it to the correct place
function abilityReplacement(rNewEffect, rActor)
	local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.mod ~= 0 and
			rEffectComp.type == "SAVEE"  or 
			rEffectComp.type == "SAVES" or
			rEffectComp.type == "SAVEA" or
			rEffectComp.type == "SAVEONDMG" then
			for j,sRemainder in ipairs(rEffectComp.remainder) do
				for _,sAbility in pairs(DataCommon.abilities) do
					if sRemainder == DataCommon.ability_ltos[sAbility]:upper() then
						nMod = tonumber(rEffectComp.remainder[j+1])
						if (nMod ~= nil) then
							rEffectComp.remainder[j+1] = tostring(nMod + rEffectComp.mod)
						else
							table.insert(rEffectComp.remainder, j+1, tostring(rEffectComp.mod))
						end
						rEffectComp.mod = 0
						break
					end
				end
			end
			aEffectComps[i] =  EffectManager5E.rebuildParsedEffectComp(rEffectComp):gsub(",", " ")
			rNewEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
		end
	end
end

function replaceSaveDC(rNewEffect, rActor)
	if (rNewEffect.sName:match("%[SDC]") or rNewEffect.sName:match("%(SDC%)")) and  
			(rNewEffect.sName:match("SAVEE%s*:") or 
			rNewEffect.sName:match("SAVES%s*:") or 
			rNewEffect.sName:match("SAVEA%s*:") or
		    rNewEffect.sName:match("SAVEONDMG%s*:")) then
		local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor)
		local nSpellcastingDC = 0
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
					break
				end
			end
		end
		rNewEffect.sName = rNewEffect.sName:gsub("%[SDC]", tostring(nSpellcastingDC))
		rNewEffect.sName = rNewEffect.sName:gsub("%(SDC%)", tostring(nSpellcastingDC))
	end
end


function onSaveRollHandler5E(rSource, rTarget, rRoll)
	if rRoll.sSubtype ~= "bce" then
		ActionSave.onSave(rSource, rTarget, rRoll) -- Reverse target/source because the target of the effect is making the save
		return
	end
	local nodeEffect = nil 
	if rRoll.sEffectPath ~= "" then
		nodeEffect = DB.findNode(rRoll.sEffectPath)
	end
	local nodeSource = ActorManager.getCTNode(rRoll.sSourceCTNode)
	local nodeTarget = ActorManager.getCTNode(rTarget)
	local tMatch = {}
	local aTags = {}

	ActionSave.onSave(rTarget, rSource, rRoll) -- Reverse target/source because the target of the effect is making the save
	local nResult = ActionsManager.total(rRoll)
	local bAct = false
	if rRoll.bActonFail then
		if nResult < tonumber(rRoll.nTarget) then
			bAct = true
		end
	else
		if nResult >= tonumber(rRoll.nTarget) then
			bAct = true
		end
	end
	local sEffect = DB.getValue(nodeEffect, "label", "")

	--Need the original effect because we only want to do things that are in the same effect
	--if we just pull all the tags on the Actor then we can't have multiple saves doing
	--multiple different things. We have to be careful about the one shot options expireing
	--our effect hence the check for nil

	if bAct and nodeEffect ~= nil then	
		aTags = {"SAVEADDP"}
		if rRoll.sDesc:match( " %[HALF ON SAVE%]") then
			table.insert(aTags, "SAVEDMG")
		end
		
		if rRoll.bRemoveOnSave  then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove");
		elseif rRoll.bDisableOnSave then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Deactivate");
		end

		tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rSource, nil, nodeEffect)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADDP" then
				rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
				if rEffect ~= {} then
					rEffect.sSource = rRoll.sSourceCTNode 
					rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
					EffectManager.addEffect("", "", nodeTarget, rEffect, true)
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rSource, rTarget, tEffect.rEffectComp, true)
			end
			end
	elseif nodeEffect ~= nil then
		aTags = {"SAVEADD", "SAVEDMG"}
		tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rSource)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADD" then
				rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1], nil, nodeEffect)
				if rEffect ~= {} then
					rEffect.sSource = rRoll.sSourceCTNode
					rEffect.nInit  = DB.getValue(nodeSource, "initresult", 0)
					EffectManager.addEffect("", "", nodeTarget, rEffect, true)
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rSource, rTarget, tEffect.rEffectComp)
			end
		end
	end
end

function onDamage(rSource,rTarget, nodeEffect)
	local tMatch = {}
	local aTags = {"SAVEONDMG"}
	local rEffectSource = {}

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rSource)
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
end

function saveEffect(rSource, rTarget, tEffect) -- Effect, Node which this effect is on, BCE String
	local nodeSource = ActorManager.getCTNode(rSource)
	local nodeTarget = ActorManager.getCTNode(rTarget)
	local aParsedRemiander = StringManager.parseWords(tEffect.rEffectComp.remainder[1])
	local sAbility = aParsedRemiander[1]
	if User.getRulesetName() == "5E" then
		sAbility = DataCommon.ability_stol[sAbility]
	end
	local nDC = tonumber(aParsedRemiander[2])
	if  (nDC and sAbility) ~= nil then
		local rSaveVsRoll = {}
		rSaveVsRoll.sType = "save"
		rSaveVsRoll.sSubtype = "bce"
		rSaveVsRoll.aDice = {}
		rSaveVsRoll.sSaveType = "Save"
		rSaveVsRoll.nTarget = nDC -- Save DC
		rSaveVsRoll.sSourceCTNode = rSource.sCTNode -- Node who applied
		rSaveVsRoll.sDesc = "[SAVE VS] " .. tEffect.sLabel -- Effect Label
		if rSaveVsRoll then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [" .. sAbility .. " DC " .. rSaveVsRoll.nTarget .. "]";
		end
		if tEffect.rEffectComp.original:match("%(M%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [MAGIC]";
		end
		if tEffect.rEffectComp.original:match("%(H%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [HALF ON SAVE]";
		end
		rSaveVsRoll.sSaveDesc = rSaveVsRoll.sDesc
		if tEffect.nGMOnly == 1 then
			rSaveVsRoll.bSecret = true
		end
		if tEffect.rEffectComp.original:match("%(D%)") then
			rSaveVsRoll.bDisableOnSave = true
		end
		if tEffect.rEffectComp.original:match("%(R%)") then
			rSaveVsRoll.bRemoveOnSave = true
		end
		if tEffect.rEffectComp.original:match("%(F%)") then
			rSaveVsRoll.bActonFail = true
		end
		if tEffect.rEffectComp.original:match("%(ADV%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [ADV]";
		end
		if tEffect.rEffectComp.original:match("%(DIS%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [DIS]";
		end

		rSaveVsRoll.sSaveDesc = rSaveVsRoll.sDesc .. "[TYPE " .. tEffect.sLabel .. "]" 
		local rRoll = {}
		rRoll = ActionSave.getRoll(nodeTarget,sAbility) -- call to get the modifiers
		rSaveVsRoll.nMod = rRoll.nMod -- Modfiers 
		rSaveVsRoll.aDice = rRoll.aDice
		-- Pass the effect node if it wasn't expired by a One Shot
		if(type(tEffect.nodeCT) == "databasenode") then
			rSaveVsRoll.sEffectPath = tEffect.nodeCT.getPath()
		else
			rSaveVsRoll.sEffectPath = ""
		end

		ActionsManager.actionRoll(rSource.sName,{{nodeTarget}}, {rSaveVsRoll})
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
	local nDamageAdjust = 0
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

-- Needed for ongoing save. Have to flip source/target to get the correct mods
function onModSaveHandler(rSource, rTarget, rRoll)
	if rRoll.sSubtype ~= "bce" then
		ActionSave.modSave(rSource, rTarget, rRoll) -- Reverse target/source because the target of the effect is making the save
	elseif bAutomaticSave == true then
		ActionSaveASA.customModSave(rTarget, rSource, rRoll)
	else
		ActionSave.modSave(rTarget, rSource, rRoll)
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
				if aSave == nil then
					break
				end
				local j = i+3
				local bStartTurn = false
				local bEndSuccess = false
				local aName = {};
				local sClause = nil;
				
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
				if rPrevious ~= nil then
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
				
				elseif StringManager.isWord(aWords[j], { "also", "magically" }) then
				
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
				rCurrent.sName = sPowerName .. "; " .. StringManager.capitalize(aWords[i]);
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
