--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local rest = nil
local charRest = nil

local getDamageAdjust = nil
local notifyApplyDamage = nil
local handleApplyDamage = nil
local parseEffects = nil
local evalAction = nil
local performMultiAction = nil
local bAdvancedEffects = nil

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


		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart35E)
		EffectsManagerBCE.setCustomProcessTurnEnd(processEffectTurnEnd35E)
		EffectsManagerBCE.setCustomPreAddEffect(addEffectPre35E)
		EffectsManagerBCE.setCustomPostAddEffect(addEffectPost35E)
		EffectsManagerBCEDND.setProcessEffectApplyDamage(applyDamage)

		ActionsManager.registerResultHandler("save", onSaveRollHandler35E)
		ActionsManager.registerModHandler("save", onModSaveHandler)

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)

		--WIP: Advanced Effects
		--bAdvancedEffects = EffectsManagerBCE.hasExtension("FG-PFRPG-Advanced-Effects")
		
		if bAdvancedEffects then
			notifyApplyDamage = ActionDamage.notifyApplyDamage
			handleApplyDamage = ActionDamage.handleApplyDamage
			ActionDamage.notifyApplyDamage = customNotifyApplyDamage
			ActionDamage.handleApplyDamage = customHandleApplyDamage
			OOBManager.registerOOBMsgHandler(ActionDamage.OOB_MSGTYPE_APPLYDMG, customHandleApplyDamage)
			performMultiAction = ActionsManager.performMultiAction
			ActionsManager.performMultiAction = customPerformMultiAction
		end

		--getDamageAdjust = ActionDamage.getDamageAdjust
		--ActionDamage.getDamageAdjust = customGetDamageAdjust
		--parseEffects = PowerManager.parseEffects
		--PowerManager.parseEffects = customParseEffects

		--evalAction = PowerManager.evalAction
		--PowerManager.evalAction = customEvalAction

	end
end

function onClose()
	if User.getRulesetName() == "3.5E" or  User.getRulesetName() == "PFRPG" then
		CombatManager2.rest = rest
		CharManager.rest = charRest
		ActionsManager.unregisterResultHandler("save")
		ActionsManager.unregisterModHandler("save")
		EffectsManagerBCE.removeCustomProcessTurnStart(processEffectTurnStart35E)
		EffectsManagerBCE.removeCustomProcessTurnEnd(processEffectTurnEnd35E)
		EffectsManagerBCE.removeCustomPreAddEffect(addEffectPre35E)
		EffectsManagerBCE.removeCustomPostAddEffect(addEffectPost35E)

		if bAdvancedEffects then
			ActionsManager.performMultiAction = performMultiAction
			ActionDamage.notifyApplyDamage = notifyApplyDamage
			ActionDamage.handleApplyDamage = handleApplyDamage
		end
	end
end

-- Replace SDC when applied from a power
function customEvalAction(rActor, nodePower, rAction)
	if rAction.type == "effect" and (rAction.sName:match("%[SDC]") or rAction.sName:match("%(SDC%)")) then
		local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower)
		if aPowerGroup and aPowerGroup.sStat and DataCommon.ability_ltos[aPowerGroup.sStat] then
			local nDC = 8 + aPowerGroup.nSaveDCMod + ActorManager35E.getAbilityBonus(rActor, aPowerGroup.sStat)
			if aPowerGroup.nSaveDCProf == 1 then
				nDC = nDC + ActorManager35E.getAbilityBonus(rActor, "prf")
			end
			rAction.sName =  rAction.sName:gsub("%[SDC]", tostring(nDC))
			rAction.sName =  rAction.sName:gsub("%(SDC%)", tostring(nDC))
		end
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
	if rNewEffect.sSource ~= nil and rNewEffect.sSource ~= "" then
		local nodeSource = DB.findNode(rNewEffect.sSource)
		rSource = ActorManager.resolveActor(nodeSource)
	else
		rSource = rActor
	end
	rNewEffect.sName = EffectManager35E.evalEffect(rSource, rNewEffect.sName)
	EffectsManagerBCE5E.replaceSaveDC(rNewEffect, rSource)
	return true
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

function applyDamage(rSource,rTarget)
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


function onSaveRollHandler35E(rSource, rTarget, rRoll)
	if rRoll.sSubtype ~= "bce" then
		return ActionSave.onSave(rSource, rTarget, rRoll)
	end

	local nodeEffect = nil
	if rRoll.sEffectPath ~= "" then
		nodeEffect = DB.findNode(rRoll.sEffectPath)
		if nodeEffect ~= nil then
			local nodeTarget = nodeEffect.getParent().getParent()
			rTarget = ActorManager.resolveActor(nodeTarget)
		end
	end

	local nodeSource = ActorManager.getCTNode(rRoll.sSource)
	local nodeTarget = ActorManager.getCTNode(rTarget)
	-- something is wrong. Likely an extension messign with things
	if nodeTarget == nil then
		return
	end
	local tMatch
	local aTags
	ActionSave.onSave(rSource, rTarget, rRoll)
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
	--Need the original effect because we only want to do things that are in the same effect
	--if we just pull all the tags on the Actor then we can't have multiple saves doing
	--multiple different things. We have to be careful about the one shot options expireing
	--our effect hence the check for nil

	if bAct and nodeEffect ~= nil then
		aTags = {"SAVEADDP"}
		if rRoll.sDesc:match( " %[HALF ON SAVE%]") then
			table.insert(aTags, "SAVEDMG")
		end

		tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nodeEffect)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADDP" then
				rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
				if next( rEffect) then
					rEffect.sSource = rRoll.sSource
					rEffect.nInit  = DB.getValue(rEffect.sSource, "initresult", 0)
					EffectManager.addEffect("", "", nodeTarget, rEffect, true)
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rSource, rTarget, tEffect.rEffectComp, true)
			end
		end
		if rRoll.bRemoveOnSave  then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Remove");
		elseif rRoll.bDisableOnSave then
			EffectsManagerBCE.modifyEffect(nodeEffect, "Deactivate");
		end
	elseif nodeEffect ~= nil then
		aTags = {"SAVEADD", "SAVEDMG"}
		tMatch = EffectsManagerBCE.getEffects(rTarget, aTags, rTarget, nil, nodeEffect)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "SAVEADD" then
				rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
				if next(rEffect) then
					rEffect.sSource = rRoll.sSource
					rEffect.nInit  = DB.getValue(nodeSource, "initresult", 0)
					EffectManager.addEffect("", "", nodeTarget, rEffect, true)
				end
			elseif tEffect.sTag == "SAVEDMG" then
				EffectsManagerBCEDND.applyOngoingDamage(rSource, rTarget, tEffect.rEffectComp)
			end
		end
	end
end

function saveEffect(rSource, rTarget, tEffect) -- Effect, Node which this effect is on, BCE String
	local aParsedRemiander = StringManager.parseWords(tEffect.rEffectComp.remainder[1])
	local sAbility = aParsedRemiander[1]
	local nDC = tonumber(aParsedRemiander[2])
	if not nDC then
		nDC = tEffect.rEffectComp.mod
	end
	if  sAbility and sAbility ~= "" then
		local rSaveVsRoll = ActionSave.getRoll(rTarget,sAbility) -- call to get the modifiers

		rSaveVsRoll.sSubtype = "bce"
		rSaveVsRoll.nTarget = nDC -- Save DC
		rSaveVsRoll.sSource = rSource.sCTNode -- Node who applied
		rSaveVsRoll.sDesc = "[ONGOING SAVE] " .. tEffect.sLabel -- Effect Label
		rSaveVsRoll.sSaveDesc = "[ONGOING SAVE] " .. StringManager.capitalize(sAbility)
		rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [" .. sAbility .. " DC " .. rSaveVsRoll.nTarget .. "]"

		if tEffect.rEffectComp.original:match("%(M%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [MAGIC]";
		end
		if tEffect.rEffectComp.original:match("%(H%)") then
			rSaveVsRoll.sDesc = rSaveVsRoll.sDesc .. " [HALF ON SAVE]";
		end
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
		-- Pass the effect node if it wasn't expired by a One Shot
		if(type(tEffect.nodeCT) == "databasenode") then
			rSaveVsRoll.sEffectPath = tEffect.nodeCT.getPath()
		else
			rSaveVsRoll.sEffectPath = ""
		end
	--	ActionsManager.actionRoll(rSource,{{rSource}}, {rSaveVsRoll})

		ActionsManager.actionRoll(rTarget,{{rTarget}}, {rSaveVsRoll})
	end
end

-- Needed for ongoing save. Have to flip source/target to get the correct mods
function onModSaveHandler(rSource, rTarget, rRoll)
	if rRoll.sSubtype ~= "bce" then
		return ActionSave.modSave(rSource, rTarget, rRoll)
	else
	 	return ActionSave.modSave(rTarget, rSource, rRoll)
	 end
end

--Advanced Effects
function customPerformMultiAction(draginfo, rActor, sType, rRolls)
	if rActor ~= nil then
		rRolls[1].itemPath = rActor.itemPath
	end
	return performMultiAction(draginfo, rActor, sType, rRolls)
end

-- only for Advanced Effects
-- ##WARNING CONFLICT POTENTIAL
function customHandleApplyDamage(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	if rTarget then
		rTarget.nOrder = msgOOB.nTargetOrder;
	end

	local nTotal = tonumber(msgOOB.nTotal) or 0;
	ActionDamage.applyDamage(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), msgOOB.sRollType, msgOOB.sDamage, nTotal);
end

-- only for Advanced Effects
-- ##WARNING CONFLICT POTENTIAL
function customNotifyApplyDamage(rSource, rTarget, bSecret, sRollType, sDesc, nTotal)
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

	msgOOB.sRollType = sRollType;
	msgOOB.nTotal = nTotal;
	msgOOB.sDamage = sDesc;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	msgOOB.nTargetOrder = rTarget.nOrder;

	Comm.deliverOOBMessage(msgOOB, "");
end