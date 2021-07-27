--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local bMadNomadCharSheetEffectDisplay = false
local bAutomaticSave = false
local restChar = nil

function onInit()
	if User.getRulesetName() == "5E" then 
		if Session.IsHost then
			OptionsManager.registerOption2("ALLOW_DUPLICATE_EFFECT", false, "option_Better_Combat_Effects", 
			"option_Allow_Duplicate", "option_entry_cycler", 
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" })

			OptionsManager.registerOption2("RESTRICT_CONCENTRATION", false, "option_Better_Combat_Effects", 
			"option_Concentrate_Restrict", "option_entry_cycler", 
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" })  
		end

		rest = CharManager.rest
		CharManager.rest = customRest

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost5E)
		EffectsManagerBCE.setCustomProcessEffect(processEffect)

		ActionsManager.registerResultHandler("savebce", onSaveRollHandler5E)
		ActionsManager.registerModHandler("savebce", onModSaveHandler)

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
		ActionsManager.unregisterResultHandler("savebce")
		ActionsManager.unregisterModHandler("savebce")
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost5E)
		EffectsManagerBCE.removeCustomProcessEffect(processEffect)

	end
end

function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
	local sDuplicateMsg = nil; 
	sDuplicateMsg = EffectManager5E.onEffectAddIgnoreCheck(nodeCT, rEffect)
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return sDuplicateMsg
	end
	if OptionsManager.isOption("ALLOW_DUPLICATE_EFFECT", "off")  and not rEffect.sName:match("STACK") then
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

function customRest(nodeActor, bLong, bMilestone)
	EffectsManagerBCEDND.customRest(nodeActor, bLong, nil)
	rest(nodeActor, bLong)
end

--Do sanity checks to see if we should process this effect any further
function processEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	-- is there a conditional that prevents us from processing
	local aEffectComps = EffectManager.parseEffect(sEffect)
	for _,sEffectComp in ipairs(aEffectComps) do -- Check conditionals
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "IF" then
			if not EffectManager5E.checkConditional(rSource, nodeEffect, rEffectComp.remainder, rTarget) then
				return false
			end
		elseif rEffectComp.type == "IFT" then
			if not EffectManager5E.checkConditional(rSource, nodeEffect, rEffectComp.remainder, rTarget) then
				return false
			end
		end
	end	
	return true -- Everything looks good to continue processing
end

function processEffectTurnStart5E(sourceNodeCT, nodeCT, nodeEffect)
	local rSource = ActorManager.resolveActor(sourceNodeCT)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
	local rSourceEffect = ActorManager.resolveActor(sEffectSource)
	if rSourceEffect == nil then
		rSourceEffect = rSource
	end
	if sourceNodeCT == nodeCT and EffectsManagerBCE.processEffect(rSource,nodeEffect,"SAVES") then
		saveEffect(nodeEffect, sourceNodeCT, "Save")
	end
	return true
end

function processEffectTurnEnd5E(sourceNodeCT, nodeCT, nodeEffect)
	local rSource = ActorManager.resolveActor(sourceNodeCT)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
	local rSourceEffect = ActorManager.resolveActor(sEffectSource)
	if rSourceEffect == nil then
		rSourceEffect = rSource
	end
	if sourceNodeCT == nodeCT and EffectsManagerBCE.processEffect(rSource,nodeEffect,"SAVEE") then
		saveEffect(nodeEffect, sourceNodeCT, "Save")
	end
	return true
end

function addEffectPre5E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	
	if rNewEffect.sSource ~= nil  and rNewEffect.sSource ~= "" then
		replaceSaveDC(rNewEffect, ActorManager.resolveActor(rNewEffect.sSource))
	else
		replaceSaveDC(rNewEffect, rActor)
	end
	if OptionsManager.isOption("RESTRICT_CONCENTRATION", "on") then
		dropConcentration(rNewEffect, rNewEffect.nDuration)
	end
	return true
end

function addEffectPost5E(sUser, sIdentity, nodeCT, rNewEffect)
	local rActor = ActorManager.resolveActor(nodeCT)
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		if (DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) and
			(DB.getValue(nodeEffect, "init", 0) == rNewEffect.nInit) and
			(DB.getValue(nodeEffect, "duration", 0) == rNewEffect.nDuration) and
			(DB.getValue(nodeEffect,"source_name", "") == rNewEffect.sSource) then
			local nodeSource = DB.findNode(rNewEffect.sSource)
			local rSource = ActorManager.resolveActor(nodeSource)
			local rTarget = rActor
			if EffectsManagerBCE.processEffect(rSource, nodeEffect, "SAVEA", rTarget) then
				saveEffect(nodeEffect, nodeCT, "Save")
			end
			if EffectsManagerBCE.processEffect(rSource, nodeEffect, "REGENA", rTarget) then
				EffectsManagerBCEDND.applyOngoingRegen(rSource, rTarget, nodeEffect, true)
			end
		end
	end
	return true
end

function replaceSaveDC(rNewEffect, rActor)
	if rNewEffect.sName:match("%[SDC]") and  
			(rNewEffect.sName:match("SAVEE") or 
			rNewEffect.sName:match("SAVES") or 
			rNewEffect.sName:match("SAVEA")) then
		local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor)
		local nSpellcastingDC = 0
		if sNodeType == "pc" then
			nSpellcastingDC = 8 +  ActorManager5E.getAbilityBonus(rActor, "prf");
			for _,nodeFeature in pairs(DB.getChildren(nodeActor, "featurelist")) do
				local sFeatureName = StringManager.trim(DB.getValue(nodeFeature, "name", ""):lower())
				if sFeatureName == "spellcasting" then
					local sDesc = DB.getValue(nodeFeature, "text", ""):lower();
					local sStat = sDesc:match("(%w+) is your spellcasting ability") or ""
					nSpellcastingDC = nSpellcastingDC + ActorManager5E.getAbilityBonus(rActor, sStat) 
					break
				end
			end 	
		elseif sNodeType == "ct" then
			nSpellcastingDC = 8 +  ActorManager5E.getAbilityBonus(rActor, "prf");
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
	end
end


function onSaveRollHandler5E(rSource, rTarget, rRoll)
	local nodeEffect = DB.findNode(rRoll.sEffectPath)
	if not nodeEffect then
		return
	end
	local sName = ActorManager.getDisplayName(nodeSource)
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
	if bAct then
		if rRoll.sDesc:match( " %[HALF ON SAVE%]") then
			EffectsManagerBCEDND.applyOngoingDamage(rSource, rTarget, nodeEffect, true)
		end
		if rRoll.bRemoveOnSave then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove")
		elseif rRoll.bDisableOnSave then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Deactivate")
		end
	else
		EffectsManagerBCEDND.applyOngoingDamage(rSource, rTarget, nodeEffect, false)
	end
end

function saveEffect(nodeEffect, nodeTarget, sSaveBCE) -- Effect, Node which this effect is on, BCE String
	local sEffect = DB.getValue(nodeEffect, "label", "")
	if (DB.getValue(nodeEffect, "isactive", 0) ~= 1 ) then
		return
	end
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local sLabel = ""
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "SAVEE" or rEffectComp.type == "SAVES" or rEffectComp.type == "SAVEA" then
			local sAbility = rEffectComp.remainder[1]
			if User.getRulesetName() == "5E" then
				sAbility = DataCommon.ability_stol[sAbility]
			end
			local nDC = tonumber(rEffectComp.remainder[2])
			if  (nDC and sAbility) ~= nil then		
				local sNodeEffectSource  = DB.getValue(nodeEffect, "source_name", "")
				if sLabel == "" then
					sLabel = "Ongoing Effect"
				end
				local rSaveVsRoll = {}
				rSaveVsRoll.sType = "savebce"
				rSaveVsRoll.aDice = {}
				rSaveVsRoll.sSaveType = sSaveBCE
				rSaveVsRoll.nTarget = nDC -- Save DC
				rSaveVsRoll.sSource = sNodeEffectSource
				rSaveVsRoll.sDesc = "[SAVE VS] " .. sLabel
				if rSaveVsRoll then
					rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [" .. sAbility .. " DC " .. rSaveVsRoll.nTarget .. "]";
				end
				if rEffectComp.original:match("%(M%)") then
					rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [MAGIC]";
				end
				if rEffectComp.original:match("%(H%)") then
					rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [HALF ON SAVE]";
				end
				rSaveVsRoll.sSaveDesc = rSaveVsRoll.sDesc
				if EffectManager.isGMEffect(sourceNodeCT, nodeEffect) or CombatManager.isCTHidden(sourceNodeCT) then
					rSaveVsRoll.bSecret = true
				end
				if rEffectComp.original:match("%(D%)") then
					rSaveVsRoll.bDisableOnSave = true
				end
				if rEffectComp.original:match("%(R%)") then
					rSaveVsRoll.bRemoveOnSave = true
				end
				if rEffectComp.original:match("%(F%)") then
					rSaveVsRoll.bActonFail = true
				end

				rSaveVsRoll.sSaveDesc = rSaveVsRoll.sDesc .. "[TYPE " .. sEffect .. "]" 
				local rRoll = {}
				rRoll = ActionSave.getRoll(nodeTarget,sAbility) -- call to get the modifiers
				rSaveVsRoll.nMod = rRoll.nMod -- Modfiers 
				rSaveVsRoll.aDice = rRoll.aDice
				rSaveVsRoll.sEffectPath = nodeEffect.getPath()
				ActionsManager.actionRoll(sNodeEffectSource,{{nodeTarget}}, {rSaveVsRoll})
				break  
			end
		elseif rEffectComp.type == "" and sLabel == "" then
			sLabel = sEffectComp
		end
	end
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
		for _, nodeCTConcentration in pairs(ctEntries) do
			if nodeCT == nodeCTConcentration then
				sSource = ""
			else
				sSource = sSourceName
			end
			for _,nodeEffect in pairs(DB.getChildren(nodeCTConcentration, "effects")) do
				local sEffect = DB.getValue(nodeEffect, "label", "")
				if (sEffect:match("%(C%)") and (DB.getValue(nodeEffect, "source_name", "") == sSource)) and 
						((DB.getValue(nodeEffect, "label", "") ~= rNewEffect.sName) or
						((DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) and (DB.getValue(nodeEffect, "duration", 0) ~= nDuration))) then
							EffectsManagerBCE.modifyEffect(nodeEffect, "Remove", sEffect)
				end
			end
		end
	end
end

-- Needed for ongoing save. Have to flip source/target to get the correct mods
function onModSaveHandler(rSource, rTarget, rRoll)
	if bAutomaticSave == true then
		ActionSaveASA.customModSave(rTarget, rSource, rRoll)
	else
		ActionSave.modSave(rTarget, rSource, rRoll)
	end
end
