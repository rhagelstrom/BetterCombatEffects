--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local rest = nil
local charRest = nil

local getDamageAdjust = nil
local parseEffects = nil
local evalAction = nil
local performMultiAction = nil
local bAdvanceEffects = nil

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

		EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheck)

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

function processEffectTurnStart35E(sourceNodeCT, nodeCT, nodeEffect)
    return EffectsManagerBCE5E.processEffectTurnStart5E(sourceNodeCT, nodeCT, nodeEffect)
end

function processEffectTurnEnd35E(sourceNodeCT, nodeCT, nodeEffect)
    return EffectsManagerBCE5E.processEffectTurnEnd5E(sourceNodeCT, nodeCT, nodeEffect)
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
		local nodeTarget = nodeEffect.getParent().getParent()
		rTarget = ActorManager.resolveActor(nodeTarget)
	end

	local nodeSource = ActorManager.getCTNode(rRoll.sSourceCTNode)
	local nodeTarget = ActorManager.getCTNode(rTarget)
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
					rEffect.sSource = rRoll.sSourceCTNode
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


function saveEffect(rSource, rTarget, tEffect) -- Effect, Node which this effect is on, BCE String
	local aParsedRemiander = StringManager.parseWords(tEffect.rEffectComp.remainder[1])
	local sAbility = aParsedRemiander[1]
	local nDC = tonumber(aParsedRemiander[2])
	if  (nDC and sAbility) ~= nil then
		local rSaveVsRoll = {}
		rSaveVsRoll.sType = "save"
		rSaveVsRoll.sSubtype = "bce"
		rSaveVsRoll.aDice = {}
		rSaveVsRoll.sSaveType = "Save"
		rSaveVsRoll.nTarget = nDC -- Save DC
		rSaveVsRoll.sSourceCTNode = rSource.sCTNode -- Node who applied
		rSaveVsRoll.sDesc = "[ONGOING SAVE] " .. tEffect.sLabel -- Effect Label
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
		ActionsManager.actionRoll(rTarget,{{rTarget}}, {rSaveVsRoll})
	end
end
