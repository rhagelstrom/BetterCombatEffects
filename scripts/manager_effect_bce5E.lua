--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local onAttack = nil
local getDamageAdjust = nil
local parseEffects = nil
local evalAction = nil
local performMultiAction = nil
local onPostAttackResolve = nil
--local bAutomaticShieldMaster = nil
--local bMadNomadCharSheetEffectDisplay = nil
local modSave = nil
local getEffectsByType = nil
local hasEffect = nil

-- Save vs condition
local decodeActors = nil
local encodeActors = nil
local performAction = nil
local getPCPowerAction = nil
local handleApplySaveVs = nil
local notifyApplySaveVs = nil
local performVsRoll = nil
local performSaveVsRoll = nil
local addCustomNPC = nil
local addCustomPC = nil
-- end save vs condition
local applyModifiers = nil

local tTraitsAdvantage = {}
local tTraitsDisadvantage = {}

local bAdvancedEffects = nil
local resetHealth = nil
local onSave = nil
local rest = nil
local bExpandedNPC = nil
local bFlanking = nil
local bUntrueEffects = nil

local checkFlanking = nil
function onInit()
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

		end
		EffectsManagerBCE.registerBCETag("ATKHA", EffectsManagerBCE.aBCEActivateOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKHR", EffectsManagerBCE.aBCERemoveOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKHD", EffectsManagerBCE.aBCEDeactivateOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKHADD", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKMA", EffectsManagerBCE.aBCEActivateOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKMR", EffectsManagerBCE.aBCERemoveOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKMD", EffectsManagerBCE.aBCEDeactivateOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKMADD", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKFADD", EffectsManagerBCE.aBCEDefaultOptionsAE)

		--5E/3.5E BCE Tags
		EffectsManagerBCE.registerBCETag("SAVEA", EffectsManagerBCE.aBCEOneShotOptions)

		EffectsManagerBCE.registerBCETag("SAVES", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEADD", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVEADDP", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVEDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEONDMG", EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("SAVERESTL", EffectsManagerBCE.aBCEDefaultOptions)

		ActionsManager.registerResultHandler("save", onSaveRollHandler5E)
		ActionsManager.registerModHandler("save", onModSaveHandler)
		ActionsManager.registerResultHandler("attack", customOnAttack)

		--4E/5E
		EffectsManagerBCE.registerBCETag("DMGR",EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("SSAVES", EffectsManagerBCE.aBCESourceMattersOptions)
		EffectsManagerBCE.registerBCETag("SSAVEE", EffectsManagerBCE.aBCESourceMattersOptions)

		EffectsManagerBCE.registerBCETag("ATKR",  EffectsManagerBCE.aBCERemoveOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKD",  EffectsManagerBCE.aBCEDeactivateOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKA",  EffectsManagerBCE.aBCEActivateOptionsAE)
		EffectsManagerBCE.registerBCETag("ATKADD",  EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("TATKHDMGS",  EffectsManagerBCE.aBCEDefaultOptionsAE)
		EffectsManagerBCE.registerBCETag("TATKMDMGS",  EffectsManagerBCE.aBCEDefaultOptionsAE)

		EffectsManagerBCE.registerBCETag("ELUSIVE",  EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("ADVCOND",  EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("DISCOND",  EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("NOREST",  EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("NORESTL",  EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.registerBCETag("IMMUNE",  EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SDC",  EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("DC",  EffectsManagerBCE.aBCEDefaultOptions)

		resetHealth = CombatManager2.resetHealth
		CombatManager2.resetHealth = customResetHealth
		rest = CharManager.rest
		CharManager.rest = customRest

		--Save vs Condition
		hasEffect = EffectManager5E.hasEffect
		getEffectsByType = EffectManager5E.getEffectsByType
		decodeActors  = ActionsManager.decodeActors
		encodeActors  = ActionsManager.encodeActors
		performAction =PowerManager.performAction
		getPCPowerAction = PowerManager.getPCPowerAction
		handleApplySaveVs = PowerManager.handleApplySaveVs
		notifyApplySaveVs = ActionPower.notifyApplySaveVs
		performVsRoll = ActionSave.performVsRoll
		performSaveVsRoll = ActionPower.performSaveVsRoll
		addCustomNPC = CombatManager.addNPC
		addCustomPC = CombatManager.addPC

		EffectManager5E.hasEffect = customHasEffect
		EffectManager5E.getEffectsByType = customGetEffectsByType
		ActionsManager.decodeActors = customDecodeActors
		ActionsManager.encodeActors = customEncodeActors
		PowerManager.performAction = customPerformAction
		PowerManager.getPCPowerAction = customGetPCPowerAction
		PowerManager.handleApplySaveVs = customHandleApplySaveVs
		ActionPower.notifyApplySaveVs = customNotifyApplySaveVs
		ActionSave.performVsRoll = customPerformVsRoll
		ActionPower.performSaveVsRoll = customPerformSaveVsRoll
		CombatManager.addNPC = addNPCtoCT
		CombatManager.addPC = addPCtoCT
		-- End Save vs Condiition

		modSave = ActionSave.modSave
		ActionSave.modSave = onModSaveHandler

		getDamageAdjust = ActionDamage.getDamageAdjust
		ActionDamage.getDamageAdjust = customGetDamageAdjust
		parseEffects = PowerManager.parseEffects
		PowerManager.parseEffects = customParseEffects
		evalAction = PowerManager.evalAction
		PowerManager.evalAction = customEvalAction

		onAttack = ActionAttack.onAttack
		ActionAttack.onAttack = customOnAttack
		onPostAttackResolve =ActionAttack.onPostAttackResolve
		ActionAttack.onPostAttackResolve = customOnPostAttackResolve

		applyModifiers =	ActionsManager.applyModifiers
		ActionsManager.applyModifiers = customApplyModifiers

		onSave = ActionSave.onSave
		ActionSave.onSave = onSaveRollHandler5E
		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart5E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd5E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre5E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost5E)
		EffectsManagerBCEDND.setProcessEffectOnDamage(onDamage5E)


		OOBManager.registerOOBMsgHandler(ActionPower.OOB_MSGTYPE_APPLYSAVEVS, customHandleApplySaveVs);

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)

		bExpandedNPC = EffectsManagerBCE.hasExtension( "5E - Expanded NPCs")
		initTraitTables()
		bUntrueEffects = EffectsManagerBCE.hasExtension("Feature: Untrue Effects")
		bAdvancedEffects = EffectsManagerBCE.hasExtension("5E - Advanced Effects")
		bFlanking = EffectsManagerBCE.hasExtension("5E - Automatic Flanking and Range")

		if bAdvancedEffects then
		 	performMultiAction = ActionsManager.performMultiAction
		 	ActionsManager.performMultiAction = customPerformMultiAction
		end
		if bFlanking then
			EffectsManagerBCE.registerBCETag("UNFLANKABLE", EffectsManagerBCE.aBCEDefaultOptions)
			checkFlanking = ActionAttackAFAR.checkFlanking
			ActionAttackAFAR.checkFlanking = customCheckFlanking
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

		EffectManager5E.hasEffect = hasEffect
		EffectManager5E.getEffectsByType = getEffectsByType
		ActionsManager.encodeActors = encodeActors
		ActionsManager.decodeActors = decodeActors
		PowerManager.performAction = performAction
		PowerManager.getPCPowerAction = getPCPowerAction
		PowerManager.handleApplySaveVs = handleApplySaveVs
		ActionPower.notifyApplySaveVs = notifyApplySaveVs
		ActionSave.performVsRoll = performVsRoll
		ActionPower.performSaveVsRoll = performSaveVsRoll
		ActionsManager.applyModifiers = applyModifiers
		ActionAttack.onPostAttackResolve = onPostAttackResolve

		if bAdvancedEffects then
		 	ActionsManager.performMultiAction = performMultiAction
		end
		if bFlanking then
			ActionAttackAFAR.checkFlanking = checkFlanking
		end
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
	local rRoll = ActionPower.getSaveVsRoll(rActor, rAction)

	if rAction.sType == "powersave" and rAction.label ~= nil then
		if rAction.sConditions == nil then
			rActor.sConditions = searchPowerGetConditions(rActor, rAction.label)
		else
			rActor.sConditions = rActor.sConditions .. "," .. searchPowerGetConditions(rActor, rAction.label)
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
	local rRoll = ActionSave.getRoll(rActor, sSave)
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
	if rSource then
		rRoll.sSource = ActorManager.getCTNodeName(rSource);
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
-- Need to get our conditions from OOB message
function customNotifyApplySaveVs(rSource, rTarget, bSecret, sDesc, nDC, bRemoveOnMiss)
	if not rTarget then
		return;
	end
	local aDMGTypes = {}
	if rSource.sConditions then
		table.insert(aDMGTypes, {aDMG = ActionDamage.getDamageTypesFromString(rSource.sConditions), nTotal = 0})
	else
		aDMGTypes = nil
	end
	local aTags = {"SDC"}
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource, nil, nil, aDMGTypes)
	for _,tEffect in pairs(tMatch) do
		nDC = nDC + tEffect.rEffectComp.mod
	end

	local msgOOB = {};
	msgOOB.type =ActionPower.OOB_MSGTYPE_APPLYSAVEVS;

	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sDesc = sDesc;
	msgOOB.nDC = nDC;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	if rSource then
		msgOOB.sConditions = rSource.sConditions;
	end
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
				customHandleApplySaveVs(msgOOB);
				return;
			end
		end
	end

	Comm.deliverOOBMessage(msgOOB, "");
end

--Using the given node power, get the resulting conditions from the database
-- for the PC and NPC
function customPerformAction(draginfo, rActor, rAction, nodePower)
	if rAction.type == "powersave" or rAction.type == "cast" then
		local sConditions = ""
		if rActor.sType == "pc" or rActor.sType == "charsheet" then
			for _,v in pairs(DB.getChildren(nodePower, "actions")) do
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
				elseif sType == "damage" then
					local nodeDmgList = v.getChild("damagelist")
					if nodeDmgList ~= nil then
						local aDmgList = nodeDmgList.getChildren()
						for _, nodeDmg in pairs(aDmgList) do
							local type = DB.getValue(nodeDmg, "type", "")
							sConditions = sConditions .. type .. ","
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

	if (draginfo and rActor.sConditions) then
        draginfo.setMetaData("sConditions",rActor.sConditions)
    end
	return performAction(draginfo, rActor, rAction, nodePower)
end

-- Needed for draged things
function customDecodeActors(draginfo)
	-- Reset the slot to 1. Needed when we drag a cast. It'll work the first roll but then will set the slot
	-- to two and never reset it.
	draginfo.setSlot(1)
	local rSource, aTargets = decodeActors(draginfo)
	local sConditions = draginfo.getMetaData("sConditions");
    if (rSource and sConditions) then
        rSource.sConditions = sConditions;
    end
	return rSource, aTargets
end

-- Needed for draged things
function customEncodeActors(draginfo, rSource, aTargets)
	if (draginfo and rSource and rSource.sConditions) then
        draginfo.setMetaData("sConditions",rSource.sConditions)
    end
	return	encodeActors(draginfo, rSource, aTargets)
end

-- setup up metadata for saves vs conditon when PC rolled from character sheet
function customGetPCPowerAction(nodeAction, sSubRoll)
	local sConditions = ""
	local rAction, rActor = getPCPowerAction(nodeAction, sSubRoll)
	if rActor ~= nil and rAction.save then
		for _,v in pairs(DB.getChildren(nodeAction.getParent(), "")) do
			local sType = DB.getValue(v, "type", "")
			local sLabel = DB.getValue(v, "label", "")
			if sType == "effect" then
				local aEffectComps = EffectManager.parseEffect(sLabel)
				for _,sEffectComp in ipairs(aEffectComps) do
					sEffectComp = sEffectComp:lower()
					if StringManager.contains(DataCommon.conditions, sEffectComp) then
						sConditions = sConditions .. sEffectComp .. ","
					end
				end
			elseif sType == "damage" then
				local nodeDmgList = v.getChild("damagelist")
				if nodeDmgList ~= nil then
					local aDmgList = nodeDmgList.getChildren()
					for _, nodeDmg in pairs(aDmgList) do
						sType = DB.getValue(nodeDmg, "type", "")
						sConditions = sConditions .. sType:lower() .. ","
					end
				end
			end
		end
		if sConditions ~= "" then
			sConditions =  sConditions:sub(1, #sConditions -1 )
		end
	end
	if rActor then
		rActor.sConditions = sConditions
	end
	return rAction, rActor
end

--Gets the conditions of effects to be applied for the power from the NPC database
function getNPCPowerConditions(nodePower)
	local sConditions = ""
	local sValue = DB.getValue(nodePower, "value")
	if not sValue then
		return sConditions
	end
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
		elseif aAbility.sType == "damage" then
			for _,aClause in ipairs(aAbility.clauses) do
				sConditions = sConditions .. aClause.dmgtype:lower() .. ","
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
			-- remove anything in () such as (Recharge x)
			sName = sName:gsub("%s+%(.+%)", "")
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
		if rEffectComp.type == "SAVEADD" or rEffectComp.type == "SAVEADDP" or rEffectComp.type == "SAVEDMG" then
			if  rEffectComp.remainder ~= {} and (StringManager.contains(DataCommon.conditions, rEffectComp.remainder[1]:lower()) or
						StringManager.contains(DataCommon.dmgtypes, rEffectComp.remainder[1]:lower())) then
				sRet = sRet .. rEffectComp.remainder[1]:lower() .. ","
			end
		end
		-- already has  a conditiion
		if StringManager.contains(DataCommon.conditions, rEffectComp.original:lower())  then
			sRet = sRet .. rEffectComp.original:lower() .. ","
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
		if not nodeTraits then
			nodeTraits = nodeActor.getChild("traits")
		end

		if nodeTraits then
			local aTraits = nodeTraits.getChildren()
			for _, nodeTrait in pairs(aTraits) do
				local sName = DB.getValue(nodeTrait, "name", "")
				local sTraitAdv =  tTraitsAdvantage[sName]
				local sTraitDis =  tTraitsDisadvantage[sName]
				if sTraitAdv then
					for _,cond in pairs(aConditions) do
						if sTraitAdv:match(cond) then
							table.insert(tReturn, " ["..sName.."] [ADV]")
							break
						end
					end
				end
				if sTraitDis then
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
	local bAdvantage
	local nodeActor = ActorManager.getCreatureNode(rActor)
	local nodeTraits = nodeActor.getChild("traitlist") or nodeActor.getChild("traits")
	if nodeTraits  then
		local aTraits = nodeTraits.getChildren()
		for _, nodeTrait in pairs(aTraits) do
			local sName = DB.getValue(nodeTrait, "name", "")
			local sText = DB.getValue(nodeTrait, "text") or DB.getValue(nodeTrait, "desc", "")
			--Parse Text
			local i = 1
			local aWords = StringManager.parseWords(sText:lower())
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
								if StringManager.isWord(aWords[k], DataCommon.conditions) or
									(StringManager.isWord(aWords[k], DataCommon.dmgtypes) and (aWords[k] ~= "magic")) then
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
	end
end
---------------------End Save Vs Condition -------------------------

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

function noRest(nodeActor, bLong, bMilestone)
	local rSource = ActorManager.resolveActor(nodeActor)
	local tMatch
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
	local tMatch
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

function customApplyModifiers(rSource, rTarget, rRoll, bSkipModStack)
	local results = {applyModifiers(rSource, rTarget, rRoll, bSkipModStack)}
	if rRoll.sType == "attack" and rRoll.sDesc:match("%[ADV]") then
		local aTags = {"ELUSIVE"}
		local tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
		if next(tMatch)	then
			rRoll.sDesc = rRoll.sDesc:gsub("%[ADV]", "%[ELUSIVE]")
			rRoll.aDice[2] = nil
		end
	end

	return unpack(results)
end

function customOnAttack(rSource, rTarget, rRoll)
	local tMatch
	local aTags = {"ATKD","ATKA","ATKR","ATKADD"}

	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "ATKA" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Activate")
		elseif tEffect.sTag == "ATKD" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Deactivate")
		elseif  tEffect.sTag  == "ATKR" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		elseif  tEffect.sTag  == "ATKADD" then
			local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
			if next(rEffect) then
				rEffect.sSource = rRoll.sSource
				rEffect.nGMOnly = nGMOnly -- If the parent is secret then we should be too.
				rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
				local nodeSource = ActorManager.getCTNode(rSource)
				if Session.IsHost then
					EffectManager.addEffect("", "", nodeSource, rEffect, true)
				else
					EffectsManagerBCE.notifyAddEffect(nodeSource, rEffect, tEffect.rEffectComp.remainder[1])
				end
			end
		end
	end
	return onAttack(rSource, rTarget, rRoll)
end

function customOnPostAttackResolve(rSource, rTarget, rRoll, rMessage)
	local tMatch
	local aTags = {}
	local aRange =  {}
	if rRoll.sRange == "M" then
		table.insert(aRange, "melee")
	elseif rRoll.sRange == "R" then
		table.insert(aRange, "ranged")
	end
	if rRoll.sResult == "hit" or rRoll.sResult == "crit" then
		aTags = {"TATKHDMGS"}
	elseif rRoll.sResult == "miss" or rRoll.sResult == "fumble" then
		aTags = {"TATKMDMGS"}
	end
	if rSource then
		rSource.tADVDIS = {}
		if rRoll.sDesc:match("%[ADV]") then
			rSource.tADVDIS.bADV = true
		end
		if rRoll.sDesc:match("%[DIS]") then
			rSource.tADVDIS.bDIS = true
		end
	end

	tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nil, aRange)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "TATKHDMGS" or tEffect.sTag == "TATKMDMGS" then
			EffectsManagerBCEDND.applyOngoingDamage(rTarget, rSource, tEffect.rEffectComp, false, "Return Damage")
		end
	end
	if rRoll.sResult == "hit" or rRoll.sResult == "crit" then
		aTags = {"ATKHA", "ATKHD","ATKHR", "ATKHADD"}
	elseif rRoll.sResult == "miss" or rRoll.sResult == "fumble" then
		aTags = {"ATKMA", "ATKMD","ATKMR", "ATKMADD"}
	end
	if  rRoll.sResult == "fumble" then
		table.insert(aTags,"ATKFADD")
	end

	tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rTarget, nil, nil, aRange)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "ATKHA" or tEffect.sTag == "ATKMA" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Activate")
		elseif tEffect.sTag == "ATKHD" or tEffect.sTag == "ATKMD" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Deactivate")
		elseif tEffect.sTag  == "ATKHR" or tEffect.sTag == "ATKMR" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Remove")
		elseif tEffect.sTag  == "ATKHADD" or tEffect.sTag == "ATKMADD" or tEffect.sTag == "ATKFADD" then
			local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
			if next(rEffect) then
				rEffect.sSource = rRoll.sSource
				rEffect.nGMOnly = false --nGMOnly -- If the parent is secret then we should be too.
				rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
				local nodeSource = ActorManager.getCTNode(rSource)
				if Session.IsHost then
					EffectManager.addEffect("", "", nodeSource, rEffect, true)
				else
					EffectsManagerBCE.notifyAddEffect(nodeSource, rEffect, tEffect.rEffectComp.remainder[1])
				end
			end
		end
	end
	if rSource then
		rSource.tADVDIS = nil
	end

	return onPostAttackResolve(rSource, rTarget, rRoll, rMessage)
end



-- For NPC
function customResetHealth (nodeCT, bLong)
	local bRest = true
	EffectsManagerBCEDND.customRest(nodeCT, bLong, nil)
	local tMatch
	tMatch = noRest(nodeCT, bLong, bMilestone)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "NORESTL" or tEffect.sTag == "NOREST" then
			bRest = false
		end
	end
	if bRest then
		resetHealth(nodeCT,bLong)
	end
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
	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	aTags = {"SSAVES"}
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

	local ctEntries = CombatManager.getCombatantNodes()
	--Tags to be processed on other nodes in the CT
	aTags = {"SSAVEE"}
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
		rNewEffect = replaceEffectParens(rNewEffect)
		rNewEffect = moveModtoMod(rNewEffect) -- Eventually we can get rid of this. Used to replace old format with New
		rNewEffect = replaceSaveDC(rNewEffect, rSource)

		local aOriginalComps = EffectManager.parseEffect(rNewEffect.sName);

		rNewEffect.sName = EffectManager5E.evalEffect(rSource, rNewEffect.sName)

		local aNewComps = EffectManager.parseEffect(rNewEffect.sName);
		aNewComps[1] = aOriginalComps[1]
		rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewComps);
	end

	local aTags = {"IMMUNE"}
	local aImmuneEffect = {};
	local tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rSource, rSource)

	for _,v in pairs(tMatch) do
		for _,vType in pairs(v.rEffectComp.remainder) do
			table.insert(aImmuneEffect, vType:lower():match("^custom%s*%(([^)]+)%)$"))
		end
	end

	local aEffectComps = EffectManager.parseEffect(rNewEffect.sName);
	for _,sEffectComp in ipairs(aEffectComps) do
		-- should be our effect take that and match to our immune list. if match throw out
		if StringManager.contains(aImmuneEffect, sEffectComp:lower()) then
			local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_targetimmune"));
			EffectManager.message(sMessage, nodeCT, false, sUser);
			return false
		end
	end

	if rNewEffect.sName:match("EFFINIT:%s*%-?%d+") then
		local sInit = rNewEffect.sName:match("%d+")
		rNewEffect.nInit = tonumber(sInit)
	end

	if OptionsManager.isOption("RESTRICT_CONCENTRATION", "on") then
		local nDuration = rNewEffect.nDuration
		if rNewEffect.sUnits == "minute" then
			nDuration = nDuration*10
		end
		dropConcentration(rNewEffect, nDuration)
	end

	return true
end

function replaceEffectParens(rEffect)
	--	Repalace effects with () that fantasygrounds will autocalc with [ ]
	local aReplace = {"PRF", "LVL", "SDC"}
	for _,sClass in pairs(DataCommon.classes) do
		table.insert(aReplace, sClass:upper())
	end
	for _,sAbility in pairs(DataCommon.abilities) do
		table.insert(aReplace, DataCommon.ability_ltos[sAbility]:upper())
	end

	for _,sTag in pairs(aReplace) do
		local sMatchString = "%([%-H%d+]?" .. sTag .. "%)"
		local sSubMatch = rEffect.sName:match(sMatchString)
		if sSubMatch then
			sSubMatch = sSubMatch:gsub("%-", "%%%-")
			sSubMatch = sSubMatch:gsub("%(", "%%%[")
			sSubMatch = sSubMatch:gsub("%)", "]")
			rEffect.sName = rEffect.sName:gsub(sMatchString, sSubMatch)
		end
	end
	return rEffect
end

function moveModtoMod(rEffect)
	local aMatch = {}
	for _,sAbility in pairs(DataCommon.abilities) do
		table.insert(aMatch, DataCommon.ability_ltos[sAbility]:upper())
	end

	local aEffectComps = EffectManager.parseEffect(rEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "SAVEE"  or
		rEffectComp.type == "SAVES" or
		rEffectComp.type == "SAVEA" or
		rEffectComp.type == "SAVEONDMG" then
			local aSplitString = StringManager.splitTokens(sEffectComp)
			if StringManager.contains(aMatch, aSplitString[2]) then
				table.insert(aSplitString, 2, aSplitString[3])
				table.remove(aSplitString, 4)
			end
			aEffectComps[i] = table.concat(aSplitString, " ")
		end
	end
	rEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
	return rEffect
end

function addEffectPost5E(sUser, sIdentity, nodeCT, rNewEffect, nodeEffect)
	local rTarget = ActorManager.resolveActor(nodeCT)
	local rSource
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

function getDCEffectMod(rActor)
	local nDC = 0
	local aTags = {"DC"}
	local tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rActor)
	for _,tEffect in pairs(tMatch) do
		if tEffect.sTag == "DC" then
			nDC = tEffect.rEffectComp.mod
			break
		end
	end
	return nDC
end


-- Replace SDC when applied from a power
function customEvalAction(rActor, nodePower, rAction)
	if rAction.type == "effect" and (rAction.sName:match("%[SDC]") or rAction.sName:match("%(SDC%)")) then
		local aNodeActionChild =  DB.getChildren(nodePower.getChild("actions"))
		local rSave = {saveMod = 0, saveBase = "", saveStat = "", saveProf = 0}
		local nDC = 0
		for _,nodeChild in pairs(aNodeActionChild) do
			local sSaveType = DB.getValue(nodeChild, "savetype", "");
			if sSaveType ~= "" then
				rSave.saveMod = DB.getValue(nodeChild, "savedcmod", 0);
				rSave.saveBase = DB.getValue(nodeChild, "savedcbase", "group");
				if rSave.saveBase == "ability" then
					rSave.saveStat = DB.getValue(nodeChild, "savedcstat", "");
					rSave.saveProf = DB.getValue(nodeChild, "savedcprof", 1);
				end
				break
			end
		end
		if rSave.saveBase == "group" then
			local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower)
			if aPowerGroup and aPowerGroup.sSaveDCStat  then
				nDC = 8 + aPowerGroup.nSaveDCMod + ActorManager5E.getAbilityBonus(rActor, aPowerGroup.sSaveDCStat) + rSave.saveMod
				if aPowerGroup.nSaveDCProf == 1 then
					nDC = nDC + ActorManager5E.getAbilityBonus(rActor, "prf")
				end
			end
		elseif rSave.saveBase == "fixed" then
			nDC = rSave.saveMod
		elseif rSave.saveBase == "ability" then
			nDC = 8 + rSave.saveMod + ActorManager5E.getAbilityBonus(rActor, rSave.savestat)
			if rSave.saveProf == 1 then
				nDC = nDC + ActorManager5E.getAbilityBonus(rActor, "prf")
			end
		end
		rAction.sName =  rAction.sName:gsub("%[SDC]", tostring(nDC))
		rAction.sName =  rAction.sName:gsub("%(SDC%)", tostring(nDC))
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
		local nDC = getDCEffectMod(rActor)
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
	return rNewEffect
end

-- rSource is the source of the actor making the roll, hence it is the target of whatever is causing the same
-- rTarget is null for some reason.
function onSaveRollHandler5E(rSource, rTarget, rRoll)
	-- Something is wrong if rRoll.sSource is null
	if  not rRoll.sSaveDesc or not rRoll.sSaveDesc:match("%[BCE]") or not rRoll.sSource then
		return onSave(rSource, rTarget, rRoll)
	end
	local nodeTarget =  DB.findNode(rRoll.sSource)
	local nodeSource = ActorManager.getCTNode(rSource)
	rTarget = ActorManager.resolveActor(nodeTarget)

	-- something is wrong. Likely an extension messing with things
	if not rTarget or not rSource or not nodeTarget or not nodeSource then
	 	return onSave(rSource, rTarget, rRoll)
	end

	local tMatch
	local aTags
	local sNodeEffect = StringManager.trim(rRoll.sSaveDesc:gsub("%[[%a%s%,%d!]*]", ""))
	local nodeEffect =  DB.findNode(sNodeEffect)
	local sEffectLabel = DB.getValue(nodeEffect, "label", "")
	local nGMOnly = DB.getValue(nodeEffect, "isgmonly", 0)
	local tParseEffect = EffectManager.parseEffect(sEffectLabel)
	local sLabel = StringManager.trim(tParseEffect[1]) or ""

	sNodeEffect = sNodeEffect:gsub("%.", "%%%.")
	sNodeEffect = StringManager.trim(sNodeEffect:gsub("%-", "%%%-"))

	rRoll.sSaveDesc = rRoll.sSaveDesc:gsub(sNodeEffect, sLabel)
	onSave(rSource, rTarget, rRoll)

	local nResult = ActionsManager.total(rRoll)
	rTarget.nResult = nResult
	rTarget.nDC = tonumber(rRoll.nTarget)
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
					rEffect.nGMOnly = nGMOnly -- If the parent is secret then we should be too.
					rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
					if Session.IsHost then
						EffectManager.addEffect("", "", nodeSource, rEffect, true)
					else
						EffectsManagerBCE.notifyAddEffect(nodeSource, rEffect, tEffect.rEffectComp.remainder[1])
					end
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
					rEffect.nGMOnly = nGMOnly -- If the parent is secret then we should be too.
					rEffect.nInit  = DB.getValue(nodeTarget, "initresult", 0)
					if Session.IsHost then
							EffectManager.addEffect("", "", nodeSource, rEffect, true)
					else
						EffectsManagerBCE.notifyAddEffect(nodeSource, rEffect, tEffect.rEffectComp.remainder[1])
					end
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rTarget, rSource, tEffect.rEffectComp, false, sLabel)
			end
		end
	end
	rTarget.nDC = nil
	rTarget.nResult = nil
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
		table.insert(aSaveFilter, sAbility:lower())

		if tEffect.rEffectComp.original:match("%(ADV%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [ADV]"
		elseif #(EffectManager5E.getEffectsByType(rTarget, "ADVSAV", aSaveFilter, rSource)) > 0 then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [ADV]"
		end
		if tEffect.rEffectComp.original:match("%(DIS%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [DIS]"
		elseif #(EffectManager5E.getEffectsByType(rTarget, "DISSAV", aSaveFilter, rSource)) > 0 then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [DIS]"
		end
		rSaveVsRoll.sDesc  = rSaveVsRoll.sDesc  .. " [!" .. getSaveConditions(tEffect.sLabel) .. "!]"

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

function customGetDamageAdjust(rSource, rTarget, nDamage, rDamageOutput, ...)
	local nReduce = 0
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
	local results = {getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput, ...)}
	-- By default FG returns the following values with anything else being another extension
	--1 nDamageAdjust
	--2 bVulnerable
	--3 bResist
	results[1] = results[1] - nReduce
	return unpack(results)
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

-- Needed for ongoing save. Have to flip source/target to get the correct mods for BCE
function onModSaveHandler(rSource, rTarget, rRoll)
	local tTraits = {}
	local tMatch = {}
	local aTags = {}
	local sConditions
	--Temp Solution.. Trait tables not init on clients
	addTraitstoConditionsTables(rSource)

	--Determine if we have a trait gives adv or disadv
	-- Do the Trait advantage first so we don't burn our effect if we don't need to
	if rRoll.sSaveDesc then
		sConditions = rRoll.sSaveDesc:match("%[![%a%d%s%,]*!]")
		if sConditions then
			sConditions = sConditions:gsub("%[!", ""):gsub("!]", "")
		end
	end
	if rRoll.sConditions and rRoll.sConditions ~= "" and sConditions then
		sConditions = sConditions .. "," .. rRoll.sConditions
	elseif rRoll.sConditions and rRoll.sConditions ~= "" and  not sConditions then
		sConditions =  rRoll.sConditions
	elseif not sConditions and (not rRoll.sConditions or rRoll.sConditions == "") then
		sConditions = nil
	end
	if rRoll.sSaveDesc and rRoll.sSaveDesc:match("%[MAGIC]") then
		if not sConditions  then
			sConditions = "magic"
		else
			sConditions = sConditions ..  ",magic"
		end
	end
	if sConditions then
		local aConditions =  StringManager.split(sConditions, "," ,true)
		tTraits = hasAdvDisCondition(rSource, aConditions)
		for _, sDesc in pairs(tTraits) do
			if  sDesc:match("%[ADV]") and not rRoll.sDesc:match("%[ADV]") then
				rRoll.sDesc = rRoll.sDesc .. sDesc
			elseif sDesc:match("%[DIS]") and not rRoll.sDesc:match("%[DIS]")  then
				rRoll.sDesc = rRoll.sDesc .. sDesc
			end
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
	if sConditions and aTags ~= {} then
		local aConditions =  StringManager.split(sConditions, "," ,true)
			tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource, nil,nil,nil,aConditions)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "ADVCOND" then
				rRoll.sDesc = rRoll.sDesc .. " [" .. tEffect.rEffectComp.original .. "] [ADV]"
			elseif tEffect.sTag == "DISCOND" then
				rRoll.sDesc = rRoll.sDesc .. " [" .. tEffect.rEffectComp.original .. "] [DIS]"
			end
		end
	end
	return modSave(rSource, rTarget, rRoll)
end

function customHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
	local bRet = hasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
	if bRet == true then
		local aTags = {}
		local bUpdated = false
		--- we don't want to update existing BCE tag properties by mistake
		bUpdated = EffectsManagerBCE.registerBCETag(sEffect:upper(), EffectsManagerBCE.aBCEIgnoreOneShotOptions, true)
		table.insert(aTags, sEffect:upper())
		local tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rActor)
		-- Remove the tag from BCE tags
		if bUpdated then
			EffectsManagerBCE.unregisterBCETag(sEffect:upper())
		end
	end
	return bRet
end

--WARNING BIGTIME CONFLICT POTENTIAL----
function customGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	if not rActor then
		return {};
	end
	local results = {};
	-- Set up filters
	local aRangeFilter = {};
	local aOtherFilter = {};
	if aFilter then
		for _,v in pairs(aFilter) do
			if type(v) ~= "string" then
				table.insert(aOtherFilter, v);
			elseif StringManager.contains(DataCommon.rangetypes, v) then
				table.insert(aRangeFilter, v);
			else
				table.insert(aOtherFilter, v);
			end
		end
	end
	-- Iterate through effects
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		-- Check active
		local nActive = DB.getValue(v, "isactive", 0);

		if ((not bAdvancedEffects and nActive ~= 0) or (bAdvancedEffects and EffectManagerADND.isValidCheckEffect(rActor,v))) then
			local bDisableUse = false

			local sLabel = DB.getValue(v, "label", "");
			local sApply = DB.getValue(v, "apply", "");
			if  sLabel:match("DUSE") then
				bDisableUse = true
			end

			-- IF COMPONENT WE ARE LOOKING FOR SUPPORTS TARGETS, THEN CHECK AGAINST OUR TARGET
			local bTargeted = EffectManager.isTargetedEffect(v);
			if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
				local aEffectComps = EffectManager.parseEffect(sLabel);

				-- Look for type/subtype match
				local nMatch = 0;
				for kEffectComp,sEffectComp in ipairs(aEffectComps) do
					local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
					-- Handle conditionals
					if rEffectComp.type == "IF" then
						if not EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
							break;
						end
					elseif bUntrueEffects and rEffectComp.type == "IFN" then
						if EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
							break;
						end
					elseif rEffectComp.type == "IFT" then
						if not rFilterActor then
							break;
						end
						if not EffectManager5E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
							break;
						end
						bTargeted = true;
					elseif bUntrueEffects and rEffectComp.type == "IFTN" then
						if OptionsManager.isOption('NO_TARGET', 'off') and not rFilterActor then
							break;
						end
						if EffectManager5E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
							break;
						end
						bTargeted = true;

					-- Compare other attributes
					else
						-- Strip energy/bonus types for subtype comparison
						local aEffectRangeFilter = {};
						local aEffectOtherFilter = {};
						local j = 1;
						while rEffectComp.remainder[j] do
							local s = rEffectComp.remainder[j];
							if #s > 0 and ((s:sub(1,1) == "!") or (s:sub(1,1) == "~")) then
								s = s:sub(2);
							end
							if StringManager.contains(DataCommon.dmgtypes, s) or s == "all" or
									StringManager.contains(DataCommon.bonustypes, s) or
									StringManager.contains(DataCommon.conditions, s) or
									StringManager.contains(DataCommon.connectors, s) then
								-- SKIP
							elseif StringManager.contains(DataCommon.rangetypes, s) then
								table.insert(aEffectRangeFilter, s);
							else
								table.insert(aEffectOtherFilter, s);
							end

							j = j + 1;
						end

						-- Check for match
						local comp_match = false;
						if rEffectComp.type == sEffectType then

							-- Check effect targeting
							if bTargetedOnly and not bTargeted then
								comp_match = false;
							else
								comp_match = true;
							end

							-- Check filters
							if #aEffectRangeFilter > 0 then
								local bRangeMatch = false;
								for _,v2 in pairs(aRangeFilter) do
									if StringManager.contains(aEffectRangeFilter, v2) then
										bRangeMatch = true;
										break;
									end
								end
								if not bRangeMatch then
									comp_match = false;
								end
							end
							if #aEffectOtherFilter > 0 then
								local bOtherMatch = false;
								for _,v2 in pairs(aOtherFilter) do
									if type(v2) == "table" then
										local bOtherTableMatch = true;
										for k3, v3 in pairs(v2) do
											if not StringManager.contains(aEffectOtherFilter, v3) then
												bOtherTableMatch = false;
												break;
											end
										end
										if bOtherTableMatch then
											bOtherMatch = true;
											break;
										end
									elseif StringManager.contains(aEffectOtherFilter, v2) then
										bOtherMatch = true;
										break;
									end
								end
								if not bOtherMatch then
									comp_match = false;
								end
							end
						end

						-- Match!
						if comp_match then
							nMatch = kEffectComp;
							if nActive == 1 then
								table.insert(results, rEffectComp);
							end
						end
					end
				end -- END EFFECT COMPONENT LOOP

				-- Remove one shot effects
				if nMatch > 0 then

					if nActive == 2 then
						DB.setValue(v, "isactive", "number", 1);
					else
						if sApply == "action" then
							EffectManager.notifyExpire(v, 0);
						elseif sApply == "roll" then
							EffectManager.notifyExpire(v, 0, true);
						elseif sApply == "single" then
							EffectManager.notifyExpire(v, nMatch, true);
						elseif bDisableUse then
							EffectsManagerBCE.modifyEffect(v, "Deactivate")
						end
					end
				end
			end -- END TARGET CHECK
		end  -- END ACTIVE CHECK
	end  -- END EFFECT LOOP
	-- RESULTS
	return results;
end

function customCheckFlanking(rSource, rTarget)
	local aTags = {"UNFLANKABLE"}

	local tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget)
	if next(tMatch) then
		return false
	else
		return checkFlanking(rSource, rTarget)
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
				if not aSave.savemod then
					aSave.savemod = 0
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

				sClause  = sClause .. " " .. tostring(aSave.savemod)
				sClause  = sClause .. " " .. DataCommon.ability_ltos[aSave.save]

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