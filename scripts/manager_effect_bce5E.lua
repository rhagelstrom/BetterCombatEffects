--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local bMadNomadCharSheetEffectDisplay = false
local restChar = nil
local getDamageAdjust = nil
local parseEffects = nil
local evalAction = nil
local performMultiAction = nil
local bAdvanceEffects = nil 

OOB_MSGTYPE_APPLYDMG = "applydmg";

--local parseNPCPower = nil

-- Save vs condition
local decodeActors = nil 
local performAction = nil
local getPCPowerAction = nil
local handleApplySaveVs = nil
local notifyApplySaveVs = nil
local performVsRoll = nil
local performSaveVsRoll = nil
local addCustomNPC = nil 
local addCustomPC = nil 
-- end save vs condition

local OOB_MSGTYPE_APPLYSAVEVS = "applysavevs";

local tTraitsAdvantage = {}
local tTraitsDisadvantage = {}

function onInit()
	local aExtensions = Extension.getExtensions()
	for _,sExtension in ipairs(aExtensions) do
		local tExtension = Extension.getExtensionInfo(sExtension)
		if (tExtension.name == "MNM Charsheet Effects Display") then
			bMadNomadCharSheetEffectDisplay = true
		end
	end

	if User.getRulesetName() == "5E" then 
		if Session.IsHost then
			OptionsManager.registerOption2("ALLOW_DUPLICATE_EFFECT", false, "option_Better_Combat_Effects_Gold", 
			"option_Allow_Duplicate", "option_entry_cycler", 
			{ labels = "option_val_off", values = "off",
				baselabel = "option_val_on", baseval = "on", default = "on" });

			OptionsManager.registerOption2("CONSIDER_DUPLICATE_DURATION", false, "option_Better_Combat_Effects_Gold", 
			"option_Consider_Duplicate_Duration", "option_entry_cycler", 
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" });

			OptionsManager.registerOption2("RESTRICT_CONCENTRATION", false, "option_Better_Combat_Effects_Gold", 
			"option_Concentrate_Restrict", "option_entry_cycler", 
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" });
			OptionsManager.registerOption2("AUTOPARSE_EFFECTS", false, "option_Better_Combat_Effects_Gold", 
			"option_Autoparse_Effects", "option_entry_cycler", 
			{ labels = "option_val_on", values = "on",
				baselabel = "option_val_off", baseval = "off", default = "off" });
			if Session.IsHost then
--				registerMenuItem(Interface.getString("Recalcuate Traits"), "shuffle", 6);
		--		registerMenuItem("Recalcuate Traits", "shuffle", 6);
			end
		end

		--5E/3.5E BCE Tags
		EffectsManagerBCE.registerBCETag("SAVEA", EffectsManagerBCE.aBCEOneShotOptions)

		EffectsManagerBCE.registerBCETag("SAVES", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEADD", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVEADDP", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVEDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEONDMG", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVERESTL", EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("DMGR",EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("SSAVES", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SSAVEE", EffectsManagerBCE.aBCESourceMattersOptions)

		EffectsManagerBCE.registerBCETag("ATKR",  EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKD",  EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKA",  EffectsManagerBCE.aBCEActivateOptionsAE)

		EffectsManagerBCE.registerBCETag("ADVCOND",  EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("DISCOND",  EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("NOREST",  EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("NORESTL",  EffectsManagerBCE.aBCEDefaultOptions)
	
		rest = CharManager.rest
		CharManager.rest = customRest
		
		--Save vs Condition
		decodeActors  = ActionsManager.decodeActors 
		performAction =PowerManager.performAction 
		getPCPowerAction = PowerManager.getPCPowerAction
		handleApplySaveVs = PowerManager.handleApplySaveVs
		notifyApplySaveVs = ActionPower.notifyApplySaveVs
		performVsRoll = ActionSave.performVsRoll
		performSaveVsRoll = ActionPower.performSaveVsRoll
		addCustomNPC = CombatManager.addNPC 
		addCustomPC = CombatManager.addPC 

		ActionsManager.decodeActors = customDecodeActors
		PowerManager.performAction = customPerformAction
		PowerManager.getPCPowerAction = customGetPCPowerAction
		PowerManager.handleApplySaveVs = customHandleApplySaveVs
		ActionPower.notifyApplySaveVs = customNotifyApplySaveVs
		ActionSave.performVsRoll = customPerformVsRoll
		ActionPower.performSaveVsRoll = customPerformSaveVsRoll
		CombatManager.addNPC = addNPCtoCT
		CombatManager.addPC = addPCtoCT
		-- End Save vs Condiition

--		parseNPCPower = PowerManager.parseNPCPower
--		PowerManager.parseNPCPower = customParseNPCPower
		getDamageAdjust = ActionDamage.getDamageAdjust
		ActionDamage.getDamageAdjust = customGetDamageAdjust
		parseEffects = PowerManager.parseEffects
		PowerManager.parseEffects = customParseEffects
		evalAction = PowerManager.evalAction 
		PowerManager.evalAction = customEvalAction

		onAttack = ActionAttack.onAttack 
		ActionAttack.onAttack = customOnAttack

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost5E)
		EffectsManagerBCEDND.setProcessEffectOnDamage(onDamage)

		ActionsManager.registerResultHandler("save", onSaveRollHandler5E)
		ActionsManager.registerModHandler("save", onModSaveHandler)
		ActionsManager.registerResultHandler("attack", customOnAttack)
	
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYSAVEVS, customHandleApplySaveVs);

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)
	
		aExtensions = Extension.getExtensions()
		for _,sExtension in ipairs(aExtensions) do
			tExtension = Extension.getExtensionInfo(sExtension)
			if (tExtension.name == "MNM Charsheet Effects Display") then
				bMadNomadCharSheetEffectDisplay = true
			end
			if (tExtension.name == "5E - Advanced Effects") then
				bAdvanceEffects = true
			end			
		end

		initTraitTables()
		
		if bAdvanceEffects then
			performMultiAction = ActionsManager.performMultiAction
			ActionsManager.performMultiAction = customPerformMultiAction
		end
	end
end

function onClose()
	if User.getRulesetName() == "5E" then 
		CharManager.rest = rest
		ActionDamage.getDamageAdjust = getDamageAdjust
		PowerManager.parseEffects = parseEffects
	--	PowerManager.parseNPCPower = parseNPCPower
		ActionsManager.unregisterResultHandler("save")
		ActionsManager.unregisterModHandler("save")
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost5E)

		ActionsManager.decodeActors = decodeActors
		PowerManager.performAction = performAction
		PowerManager.getPCPowerAction = getPCPowerAction
		PowerManager.handleApplySaveVs = handleApplySaveVs
		ActionPower.notifyApplySaveVs = notifyApplySaveVs
		ActionSave.performVsRoll = performVsRoll
		ActionPower.performSaveVsRoll = performSaveVsRoll
	end
end

function initTraitTables()
	tTraitsAdvantage = {}
	tTraitsDisadvantage = {}

	for _,nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local rActor = ActorManager.resolveActor(nodeCT)
		addTraitstoConditionsTables(rActor)
	end
end

---------------------Save Vs Condition ----------------------------

function customPerformSaveVsRoll(draginfo, rActor, rAction)
	local rRoll = ActionPower.getSaveVsRoll(rActor, rAction);
	if rAction.sConditions == nil then
		local sConditions = ""
		if rAction.sType == "powersave" and rAction.label ~= nil then
			rActor.sConditions = searchPowerGetConditions(rActor, rAction.label)
		end
	end
	if (draginfo and rActor.sConditions and rActor.sConditions ~= "") then
        draginfo.setMetaData("sConditions",rActor.sConditions)
    end

	ActionsManager.performAction(draginfo, rActor, rRoll);
end

-- WARNING: Conflict Potential
--Need to set conditions in rRoll
function customPerformVsRoll(draginfo, rActor, sSave, nTargetDC, bSecretRoll, rSource, bRemoveOnMiss, sSaveDesc, sConditions)
	local rRoll = ActionSave.getRoll(rActor, sSave);	
	if bSecretRoll then
		rRoll.bSecret = true;
	end
	rRoll.nTarget = nTargetDC;
	if bRemoveOnMiss then
		rRoll.bRemoveOnMiss = "true";
	end
	if sSaveDesc then
		rRoll.sSaveDesc = sSaveDesc;
	end
	if sConditions then
		rRoll.sConditions = sConditions
	end
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

-- WARNING: Conflict Potential
-- Need to send our conditions in OOB messagee
function customHandleApplySaveVs(msgOOB)
	local sConditions = msgOOB.sConditions
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	local sSaveShort, sSaveDC = string.match(msgOOB.sDesc, "%[(%w+) DC (%d+)%]")
	if sSaveShort then
		local sSave = DataCommon.ability_stol[sSaveShort];
		if sSave then
			customPerformVsRoll(nil, rTarget, sSave, msgOOB.nDC, (tonumber(msgOOB.nSecret) == 1), rSource, msgOOB.bRemoveOnMiss, msgOOB.sDesc, sConditions);
		end
	end
end
-- WARNING: Conflict Potential
-- Need to get our conditions from OOB messagee
function customNotifyApplySaveVs(rSource, rTarget, bSecret, sDesc, nDC, bRemoveOnMiss)
	if not rTarget then
		return;
	end
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYSAVEVS;
	
	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sDesc = sDesc;
	msgOOB.nDC = nDC;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	msgOOB.sConditions = rSource.sConditions;
	
	if bRemoveOnMiss then
		msgOOB.bRemoveOnMiss = 1;
	end

	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if nodeTarget and (sTargetNodeType == "pc") then
		if Session.IsHost then
			local sOwner = DB.getOwner(nodeTarget);
			if sOwner ~= "" then
				for _,vUser in ipairs(User.getActiveUsers()) do
					if vUser == sOwner then
						for _,vIdentity in ipairs(User.getActiveIdentities(vUser)) do
							if nodeTarget.getName() == vIdentity then
								Comm.deliverOOBMessage(msgOOB, sOwner);
								return;
							end
						end
					end
				end
			end
		else
			if DB.isOwner(nodeTarget) then
				handleApplySaveVs(msgOOB);
				return;
			end
		end
	end

	Comm.deliverOOBMessage(msgOOB, "");
end

--Using the given node power, get the resulting conditions from the database
-- for the PC and NPC
function customPerformAction(draginfo, rActor, rAction, nodePower)
	if rAction.type == "powersave" then
		local sNodeType, nodeCT = ActorManager.getTypeAndNode(rActor)
		local sConditions = ""
		if rActor.sType == "pc" then
			for _,v in pairs(DB.getChildren(nodePower, "actions")) do
				local sLabel = DB.getValue(v, "label", "")
				local sType = DB.getValue(v, "type", "")
				if sType == "effect" then
					local sLabel = DB.getValue(v, "label", "")
					local aEffectComps = EffectManager.parseEffect(sLabel)
					for _,sEffectComp in ipairs(aEffectComps) do
						sEffectComp = sEffectComp:lower()
						if StringManager.contains(DataCommon.conditions, sEffectComp) then
							sConditions = sConditions .. sEffectComp .. ","
						end
					end
				end
			end
			if sConditions ~= "" then
				sConditions = sConditions:sub(1, #sConditions -1 )
			end
		elseif rActor.sType == "npc" then
			sConditions = getNPCPowerConditions(nodePower)
		end
		rActor.sConditions = sConditions
	end 

	if (draginfo and rActor.sConditions and rActor.sConditions ~= "") then
        draginfo.setMetaData("sConditions",rActor.sConditions)
    end

	return performAction(draginfo, rActor, rAction, nodePower)
end

-- Needed for draged things
function customDecodeActors(draginfo)
	local rSource, aTargets = decodeActors(draginfo)
	local sConditions = draginfo.getMetaData("sConditions");
    if (rSource and sConditions and sConditions ~= "") then
        rSource.sConditions = sConditions;
    end
	
	return rSource, aTargets
end

-- setup up metadata for saves vs conditon when PC rolled from character sheet
function customGetPCPowerAction(nodeAction, sSubRoll)
	local sConditions = ""
	local rAction, rActor = getPCPowerAction(nodeAction, sSubRoll)
	if rActor ~= nil and rAction.save then
		for _,v in pairs(DB.getChildren(nodeAction.getParent(), "")) do
			local sType = DB.getValue(v, "type", "")
			if sType == "effect" then
				local sLabel = DB.getValue(v, "label", "")
				local aEffectComps = EffectManager.parseEffect(sLabel)
				for _,sEffectComp in ipairs(aEffectComps) do
					sEffectComp = sEffectComp:lower()
					if StringManager.contains(DataCommon.conditions, sEffectComp) then
						sConditions =  sEffectComp .. ","
					end
				end
			end
		end
		if sConditions ~= "" then
			sConditions =  sConditions:sub(1, #sConditions -1 )
		end
	end
	if rActor ~= nil then
		rActor.sConditions = sConditions
	end
	return rAction, rActor
end

--Gets the conditions of effects to be applied for the power from the NPC database
function getNPCPowerConditions(nodePower)
	local sConditions = ""
	local sValue = DB.getValue(nodePower, "value")
	local rPower = CombatManager2.parseAttackLine(sValue)
	for _,aAbility in ipairs(rPower.aAbilities) do
		if aAbility.sType == "effect" then
			local tEffectComps = EffectManager.parseEffect( aAbility.sName)
			for _,sEffectComp in ipairs(tEffectComps) do
				sEffectComp = sEffectComp:lower()
				if StringManager.contains(DataCommon.conditions, sEffectComp) then
					sConditions = sConditions .. sEffectComp .. ","
				end
			end
		end
	end
	if sConditions ~= "" then
		sConditions = sConditions:sub(1, #sConditions -1 )
	end
	return sConditions
end

--Searches the powers to find the power label. Best we can do when we don't have the link to the power
function searchPowerGetConditions(rActor, sLabel)
	local sConditions = ""
	--Search these database nodes
	local aSearchNodes= {"spells","innatespells","actions","lairactions","legendaryactions","reactions"}
	sLabel = sLabel:lower()

	local nodeActor = ActorManager.getCTNode(rActor)
	for _,sSearch in pairs(aSearchNodes) do
		for _,node in pairs(DB.getChildren(nodeActor, sSearch)) do
			local sName = DB.getValue(node, "name", "")
			if sName:lower() == sLabel then
				return getNPCPowerConditions(node)
			end
		end
	end
	return sConditions
end

function getSaveConditions(sLabel)
	local sRet = ""
	local tEffectComps = EffectManager.parseEffect(sLabel)
	for _,sEffectComp in ipairs(tEffectComps) do
		rEffectComp =  EffectManager5E.parseEffectComp(sEffectComp)
		if rEffectComp.type == "SAVEADD" or rEffectComp.type == "SAVEADDP" then
			if  rEffectComp.remainder ~= {} and StringManager.contains(DataCommon.conditions, rEffectComp.remainder[1]:lower()) then
				sRet = sRet .. rEffectComp.remainder[1]:lower() .. ","
			end
		end		
	end
	if rRet ~= "" then
		sRet = sRet:sub(1, #sRet -1 )
	end
	return sRet
end

--Check to see if creature has a trait that gives them advantage against this save
function hasAdvDisCondition(rActor, aConditions)
	local tReturn = {}
	if next(aConditions) then
		local nodeActor = ActorManager.getCreatureNode(rActor)
		local nodeTraits = nodeActor.getChild("traitlist")
		if  nodeTraits == nil then
			nodeTraits = nodeActor.getChild("traits")
		end

		if nodeTraits ~= nil then
			local aTraits = nodeTraits.getChildren()
			for _, nodeTrait in pairs(aTraits) do
				local sName = DB.getValue(nodeTrait, "name", "")
				local sTraitAdv =  tTraitsAdvantage[sName]
				local sTraitDis =  tTraitsDisadvantage[sName]
				if sTraitAdv ~= nil then
					for _,cond in pairs(aConditions) do
						if sTraitAdv:match(cond) then
							table.insert(tReturn, " ["..sName.."] [ADV]")
							break
						end
					end
				end
				if sTraitDis ~= nil  then
					for _,cond in pairs(aConditions) do
						if sTraitDis:match(cond) then
							table.insert(tReturn, " ["..sName.."] [DIS]")
							break
						end
					end
				end
			end
		end
	end
	return tReturn
end

function addPCtoCT(nodePC)
	local rActor = ActorManager.resolveActor(nodePC)
	addCustomPC(nodePC)
	addTraitstoConditionsTables(rActor)
end

function addNPCtoCT(sClass, nodeNPC, sName)
	local rActor = ActorManager.resolveActor(nodeNPC)
	local nodeCTEntry  = addCustomNPC(sClass, nodeNPC, sName)
	addTraitstoConditionsTables(rActor)
	return nodeCTEntry
end

function addTraitstoConditionsTables(rActor)
	local bAdvantage = false
	local nodeActor = ActorManager.getCreatureNode(rActor)
	local nodeTraits = nodeActor.getChild("traitlist") or nodeActor.getChild("traits")
	if nodeTraits ~= nil then
		local aTraits = nodeTraits.getChildren()
		for _, nodeTrait in pairs(aTraits) do
			local sName = DB.getValue(nodeTrait, "name", "")
			local sText = DB.getValue(nodeTrait, "text") or DB.getValue(nodeTrait, "desc", "")
			--Parse Text
			local i = 1
			aWords = StringManager.parseWords(sText:lower())
			while aWords[i] do
				if StringManager.isWord(aWords[i], {"advantage", "disadvantage"}) then
					if StringManager.isWord(aWords[i], "advantage") then
						bAdvantage = true
					else
						bAdvantage = false
					end
					local j = i
					while aWords[j] do
						if StringManager.isWord(aWords[j], "saves") or (StringManager.isWord(aWords[j], "saving") and StringManager.isWord(aWords[j+1], "throws")) then
							local k = j
							local sConditions = ""
							while aWords[k] do
								if StringManager.isWord(aWords[k], DataCommon.conditions) then
									sConditions = sConditions .. aWords[k] .. ","
								end
								k=k+1
								j=k
							end
							if sConditions ~= "" then
								sConditions =  sConditions:sub(1, #sConditions -1 )
								if bAdvantage then
									tTraitsAdvantage[sName] = sConditions
								else
									tTraitsDisadvantage[sName] = sConditions
								end
							end
						end
						j=j+1
						i=j
					end
				end
				i=i+1
			end	
		end

--		if bAdvanceEffects then
--			ActionsManager.performMultiAction = performMultiAction
--		end

	end
end
---------------------End Save Vs Condition -------------------------

--function customParseNPCPower(nodePower, bAllowSpellDataOverride)
	--Debug.chat(nodePower)
--	local nodeCT = nodePower.getParent().getParent()
--	local rActor = ActorManager.resolveActor(nodeCT)
--	local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower)
--	Debug.chat(aPowerGroup)
--	return parseNPCPower(nodePower, bAllowSpellDataOverride)
--end


--Advanced Effects
function customPerformMultiAction(draginfo, rActor, sType, rRolls)
	if rActor ~= nil then
		rRolls[1].itemPath = rActor.itemPath
	end
	return performMultiAction(draginfo, rActor, sType, rRolls)
end

function hasAdvancedEffects()
	return bAdvanceEffects
end
-- End Advanced Effects

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

function noRest(nodeActor, bLong, bMilestone)
	local rSource = ActorManager.resolveActor(nodeActor)
	local tMatch = {}
	local aTags = {"NOREST"}
	if bLong then
		table.insert(aTags, "NORESTL")
	end
	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	return tMatch
end

function customRest(nodeActor, bLong, bMilestone)
	local bRest = true
	EffectsManagerBCEDND.customRest(nodeActor, bLong, nil)
	local tMatch = {}
	tMatch = noRest(nodeActor, bLong, bMilestone)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "NORESTL" or tEffect.sTag == "NOREST" then
			bRest = false
		end
	end
	if bRest then
		rest(nodeActor, bLong)
	end
end

function customOnAttack(rSource, rTarget, rRoll)
	local tMatch = {}
	local aTags = {"ATKD","ATKA","ATKR"}
	local rEffectSource = {}

	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "ATKA" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Activate")
		elseif tEffect.sTag == "ATKD" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Deactivate")
		elseif  tEffect.sTag  == "ATKR" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		end
	end
	return onAttack(rSource, rTarget, rRoll)
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

function addEffectPost5E(sUser, sIdentity, nodeCT, rNewEffect, nodeEffect)
	local rTarget = ActorManager.resolveActor(nodeCT)
	local rSource = {}
	if rNewEffect.sSource == "" then
		rSource = rTarget
	else
		rSource = ActorManager.resolveActor(rNewEffect.sSource)
	end

	local tMatch = {}
	local aTags = {"SAVEA"}
	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nodeEffect)
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

-- Replace SDC when applied from a power
function customEvalAction(rActor, nodePower, rAction)
	local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower)
	if rAction.type == "effect" and (rAction.sName:match("%[SDC]") or rAction.sName:match("%(SDC%)")) then
		local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower)
		if aPowerGroup and aPowerGroup.sStat and DataCommon.ability_ltos[aPowerGroup.sStat] then
			local nDC = 8 + aPowerGroup.nSaveDCMod + ActorManager5E.getAbilityBonus(rActor, aPowerGroup.sStat) 
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
		return ActionSave.onSave(rSource, rTarget, rRoll)
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
	rTarget.nResult = nResult
	rTarget.nDC = tonumber(rRoll.nTarget)
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

		tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nodeEffect)
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
		tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nodeEffect)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADD" then
				rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
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
	rTarget.nDC = nil
	rTarget.nResult = nil
end

function onDamage(rSource,rTarget, rRoll)
	local tMatch = {}
	local aTags = {"SAVEONDMG"}
	local rEffectSource = {}

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
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


function saveEffect(rSource, rTarget, tEffect) -- Effect, Node which this effect is on, BCE String
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
		if rSource ~= nil then
			rSaveVsRoll.sSourceCTNode = rSource.sCTNode -- Node who applied
		end
		rSaveVsRoll.sConditions = getSaveConditions(tEffect.sLabel)
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
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [ADV]"
		end
		if tEffect.rEffectComp.original:match("%(DIS%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [DIS]"
		end

		rSaveVsRoll.sSaveDesc = rSaveVsRoll.sDesc .. "[TYPE " .. tEffect.sLabel .. "]" 
		local rRoll = {}
		rRoll = ActionSave.getRoll(rTarget,sAbility) -- call to get the modifiers
		rSaveVsRoll.nMod = rRoll.nMod -- Modfiers 
		rSaveVsRoll.aDice = rRoll.aDice
		-- Pass the effect node if it wasn't expired by a One Shot
		if(type(tEffect.nodeCT) == "databasenode") then
			rSaveVsRoll.sEffectPath = tEffect.nodeCT.getPath()
		else
			rSaveVsRoll.sEffectPath = ""
		end

		ActionsManager.actionRoll(rSource,{{rTarget}}, {rSaveVsRoll})
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
	local tTraits = {}
	local tMatch = {}
	local aTags = {}
	local rEffectSource = {}
	
	--Determine if we have a trait gives adv or disadv
	-- Do the Trait advantage first so we don't burn our effect if we don't need to
	if rRoll.sConditions ~= "" and rRoll.sSubType == "bce" then
		local aConditions =  StringManager.split(rRoll.sConditions, "," ,true)
		tTraits = hasAdvDisCondition(rTarget, aConditions)
	elseif rRoll.sConditions ~= "" then
		local aConditions =  StringManager.split(rRoll.sConditions, "," ,true)
		tTraits = hasAdvDisCondition(rSource, aConditions) 
	end

	for _, sDesc in pairs(tTraits) do
		if  sDesc:match("%[ADV]") and not rRoll.sDesc:match("%[ADV]") then
			rRoll.sDesc = rRoll.sDesc .. sDesc
		elseif sDesc:match("%[DIS]") and not rRoll.sDesc:match("%[DIS]")  then
			rRoll.sDesc = rRoll.sDesc .. sDesc
		end
	end

	--check to see if we already have adv/dis and if we do don't poll effects
	if not rRoll.sDesc:match("%[ADV]") then
		table.insert(aTags,"ADVCOND")
	end
	if not rRoll.sDesc:match("%[DIS]") then
		table.insert(aTags,"DISCOND")
	end

	-- Get tags if any
	if rRoll.sConditions and aTags ~= {} then
		local aConditions =  StringManager.split(rRoll.sConditions, "," ,true)
		if rRoll.sSubType == "bce" then
			tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil,nil,nil,aConditions)
		else 
			tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource, nil,nil,nil,aConditions)
		end
	end

	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "ADVCOND" then
			rRoll.sDesc = rRoll.sDesc .. " [" .. tEffect.rEffectComp.original .. "] [ADV]"
		elseif tEffect.sTag == "DISCOND" then 
			rRoll.sDesc = rRoll.sDesc .. " [" .. tEffect.rEffectComp.original .. "] [DIS]"		
		end
	end

	if rRoll.sSubtype == "bce" then
		ActionSave.modSave(rTarget, rSource, rRoll) -- Reverse target/source because the target of the effect is making the save
	else
		ActionSave.modSave(rSource, rTarget, rRoll)
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