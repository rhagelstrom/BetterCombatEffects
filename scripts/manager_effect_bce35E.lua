--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local rest = nil
local charRest = nil
local evalAction = nil
local performMultiAction = nil
local bAdvancedEffects = nil
local onSave = nil

function onInit()
	if User.getRulesetName() == "3.5E" or  User.getRulesetName() == "PFRPG" then

		rest = CombatManager2.rest
		CombatManager2.rest = customRest
		charRest = CharManager.rest
		CharManager.rest = customCharRest


		EffectsManagerBCE.registerBCETag("SAVEA", EffectsManagerBCE.aBCEOneShotOptions)

		EffectsManagerBCE.registerBCETag("SAVES", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEE", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEADD", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEADDP", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("SAVEONDMG", EffectsManagerBCE.aBCEDefaultOptions)
		EffectsManagerBCE.registerBCETag("DC",  EffectsManagerBCE.aBCEDefaultOptions)

		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart35E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd35E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre35E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost35E)
		EffectsManagerBCEDND.setProcessEffectOnDamage(onDamage35E)

		ActionsManager.registerResultHandler("save", onSaveRollHandler35E)
		onSave = ActionSave.onSave
		ActionSave.onSave = onSaveRollHandler35E
		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)

		bAdvancedEffects = EffectsManagerBCE.hasExtension("Feature: Advanced Effects")
		if bAdvancedEffects then
			performMultiAction = ActionsManager.performMultiAction
			ActionsManager.performMultiAction = customPerformMultiAction
		end
	end
end

function onClose()
	if User.getRulesetName() == "3.5E" or  User.getRulesetName() == "PFRPG" then
		CombatManager2.rest = rest
		CharManager.rest = charRest
		ActionsManager.unregisterResultHandler("save")
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart35E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd35E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre35E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost35E)

		ActionSave.onSave = onSave
		if bAdvancedEffects then
			ActionsManager.performMultiAction = performMultiAction
		end
	end
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
				nDC = 8 + aPowerGroup.nSaveDCMod + ActorManager35E.getAbilityBonus(rActor, aPowerGroup.sSaveDCStat) + rSave.saveMod
				if aPowerGroup.nSaveDCProf == 1 then
					nDC = nDC + ActorManager35E.getAbilityBonus(rActor, "prf")
				end
			end
		elseif rSave.saveBase == "fixed" then
			nDC = rSave.saveMod
		elseif rSave.saveBase == "ability" then
			nDC = 8 + rSave.saveMod + ActorManager35E.getAbilityBonus(rActor, rSave.savestat)
			if rSave.saveProf == 1 then
				nDC = nDC + ActorManager35E.getAbilityBonus(rActor, "prf")
			end
		end
		rAction.sName =  rAction.sName:gsub("%[SDC]", tostring(nDC))
		rAction.sName =  rAction.sName:gsub("%(SDC%)", tostring(nDC))
	end

	evalAction(rActor, nodePower, rAction)
end

-- This is likely where we will conflict with any other extensions
function customOnEffectAddIgnoreCheck(nodeCT, rEffect)
	local sDuplicateMsg = nil
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return sDuplicateMsg
	end
	if  not rEffect.sName:match("STACK") then
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

function customCharRest(nodeChar)

	EffectsManagerBCEDND.customRest(nodeChar, true, nil)
	charRest(nodeChar)
end

function customRest(bShort)
    local bLong = not bShort
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		local rSource = ActorManager.resolveActor(v)
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

		local sClass, sRecord = DB.getValue(v, "link", "", "");
		if sClass == "charsheet" and sRecord ~= "" then
			local nodePC = DB.findNode(sRecord);
			if nodePC then
				EffectsManagerBCEDND.customRest(nodePC, bLong, nil)
			end
		end
	end
	rest(bShort)
end

function replaceSaveDC(rNewEffect, rActor)
	-- TODO
end

function processEffectTurnStart35E(rSource)
	local aTags = {"SAVES"}

	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		local rEffectSource
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

function processEffectTurnEnd35E(rSource)
	local aTags = {"SAVEE"}
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		local rEffectSource
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
function addEffectPre35E(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local rActor = ActorManager.resolveActor(nodeCT)
	local rSource = nil
	if rNewEffect.sSource  and rNewEffect.sSource ~= "" then
		local nodeSource = DB.findNode(rNewEffect.sSource)
		rSource = ActorManager.resolveActor(nodeSource)
	else
		rSource = rActor
	end
	if  not rNewEffect.sName:upper():find("FROMAURA;") then
		rNewEffect = moveModtoMod(rNewEffect) -- Eventually we can get rid of this. Used to replace old format with New
		rNewEffect = EffectsManagerBCE5E.replaceSaveDC(rNewEffect, rSource)
		rNewEffect.sName = EffectManager35E.evalEffect(rSource, rNewEffect.sName)
	end
	return true
end

function moveModtoMod(rEffect)
	local aMatch = {"WILL", "REFLEX", "FORTITUDE"}

	local aEffectComps = EffectManager.parseEffect(rEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "SAVEE"  or
		rEffectComp.type == "SAVES" or
		rEffectComp.type == "SAVEA" or
		rEffectComp.type == "SAVEONDMG" then
			local aSplitString = StringManager.splitTokens(sEffectComp)
			if StringManager.contains(aMatch, aSplitString[2]:upper()) then
				table.insert(aSplitString, 2, aSplitString[3])
				table.remove(aSplitString, 4)
			end
			aEffectComps[i] = table.concat(aSplitString, " ")
		end
	end
	rEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
	return rEffect
end

function addEffectPost35E(sUser, sIdentity, nodeCT, rNewEffect, nodeEffect)
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
	return true
end

function onDamage35E(rSource,rTarget)
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

-- rSource is the source of the actor making the roll, hence it is the target of whatever is causing the same
-- rTarget is null for some reason.
function onSaveRollHandler35E(rSource, rTarget, rRoll)
	if  not rRoll.sSaveDesc or not rRoll.sSaveDesc:match("%[BCE]") then
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
	local sNodeEffect = StringManager.trim(rRoll.sSaveDesc:gsub("%[[%a%s%d]*]", ""))
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
end

function saveEffect(rSource, rTarget, tEffect)
	local aParsedRemiander = StringManager.parseWords(tEffect.rEffectComp.remainder[1])
	local sAbility = aParsedRemiander[1]

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
		local rSaveVsRoll =	ActionSpell.getSaveVsRoll(rSource, rAction)

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

--Advanced Effects
function customPerformMultiAction(draginfo, rActor, sType, rRolls)
	if rActor then
		rRolls[1].nodeWeapon = rActor.nodeWeapon
		rRolls[1].nodeAmmo = rActor.nodeAmmo
	end
	return performMultiAction(draginfo, rActor, sType, rRolls)
end
