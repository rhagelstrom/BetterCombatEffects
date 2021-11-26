--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

OOB_MSGTYPE_BCEACTIVATE = "activateeffect"
OOB_MSGTYPE_BCEDEACTIVATE = "deactivateeffect"
OOB_MSGTYPE_BCEREMOVE = "removeeffect"
OOB_MSGTYPE_BCEUPDATE = "updateeffect"

local addEffect = nil
local expireEffect = nil

function onInit()
	addEffect = EffectManager.addEffect
	EffectManager.addEffect = customAddEffect

	expireEffect = EffectManager.expireEffect	
	EffectManager.expireEffect = customExpireEffect

	ActionsManager.registerResultHandler("effectbce", onEffectRollHandler)

	CombatManager.setCustomTurnStart(customTurnStart)
	CombatManager.setCustomTurnEnd(customTurnEnd)
	
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEACTIVATE, handleActivateEffect)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEDEACTIVATE, handleDeactivateEffect)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEREMOVE, handleRemoveEffect)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEUPDATE, handleUpdateEffect)
end

function onClose()
	EffectManager.addEffect = addEffect
	EffectManager.expireEffect = expireEffect

	ActionsManager.unregisterResultHandler("effectbce")
end

function customExpireEffect(nodeActor, nodeEffect, nExpireComp)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	expireEffect(nodeActor, nodeEffect, nExpireComp)
	if sEffect:match("EXPIREADD") then
		local rEffect = EffectsManagerBCE.matchEffect(sEffect)
		if rEffect.sName ~= nil then
			local rSource = ActorManager.resolveActor(nodeActor)
			local nodeSource = ActorManager.getCTNode(rSource)
			rEffect.sSource = ActorManager.getCTNodeName(rSource)
			rEffect.nInit  = DB.getValue(nodeActor, "initresult", 0)
			EffectManager.addEffect("", "", nodeSource, rEffect, true)
		end
	end
end

function customTurnStart(sourceNodeCT)
	if not sourceNodeCT then
		return
	end
	local sSourceName = sourceNodeCT.getNodeName()
	local rSource = ActorManager.resolveActor(sourceNodeCT)
	local ctEntries = CombatManager.getCombatantNodes()
	for _, nodeCT in pairs(ctEntries) do
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do		
			if onCustomProcessTurnStart(sourceNodeCT, nodeCT, nodeEffect) then
				local sEffect = DB.getValue(nodeEffect, "label", "")
				local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
				local rSourceEffect = ActorManager.resolveActor(sEffectSource)
				if rSourceEffect == nil then
					rSourceEffect = rSource
				end
				local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
				if nodeCT == sourceNodeCT then
					if processEffect(rSource,nodeEffect,"TURNAS", nil, true) then
						modifyEffect(nodeEffect, "Activate")
					end
					if processEffect(rSource,nodeEffect,"TURNDS") then
						modifyEffect(nodeEffect, "Deactivate")
					end
					if processEffect(rSource,nodeEffect,"TURNRS") and not sEffect:match("STURNRS") and (DB.getValue(nodeEffect, "duration", "") == 1) then
						modifyEffect(nodeEffect, "Remove")
					end
					if sEffectSource == "" and (DB.getValue(nodeEffect, "duration", "") == 1) and processEffect(rSource,nodeEffect,"STURNRS") then
						modifyEffect(nodeEffect, "Remove")
					end
				else
					if sEffectSource ~= nil  and sSourceName == sEffectSource then
						if processEffect(rSource,nodeEffect,"STURNRS") and (DB.getValue(nodeEffect, "duration", "") == 1) then
							modifyEffect(nodeEffect, "Remove")
						end
					end
				end
			end
		end
	end
end

function customTurnEnd(sourceNodeCT)
	if not sourceNodeCT then
		return
	end
	local rSource = ActorManager.resolveActor(sourceNodeCT)
	local sSourceName = sourceNodeCT.getNodeName()
	local ctEntries = CombatManager.getCombatantNodes()
	for _, nodeCT in pairs(ctEntries) do
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			if onCustomProcessTurnEnd(sourceNodeCT, nodeCT, nodeEffect) then
				local sEffect = DB.getValue(nodeEffect, "label", "")
				local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
				local rSourceEffect = ActorManager.resolveActor(sEffectSource)
				if rSourceEffect == nil then
					rSourceEffect = rSource
				end
				if nodeCT == sourceNodeCT then
					if processEffect(rSource,nodeEffect,"TURNAE", nil, true) then
						modifyEffect(nodeEffect, "Activate")
					end
					if processEffect(rSource,nodeEffect,"TURNDE") then
						modifyEffect(nodeEffect, "Deactivate")
					end
					if sEffectSource == "" and (DB.getValue(nodeEffect, "duration", "") == 1) and processEffect(rSource,nodeEffect,"STURNRE") then
						modifyEffect(nodeEffect, "Remove")
					end
					if processEffect(rSource,nodeEffect,"TURNRE") and not sEffect:match("STURNRE") and (DB.getValue(nodeEffect, "duration", "") == 1) then	
						modifyEffect(nodeEffect, "Remove")
					end
				else
					if sEffectSource ~= nil  and sSourceName == sEffectSource then
						if processEffect(rSource,nodeEffect,"STURNRE") and (DB.getValue(nodeEffect, "duration", "") == 1) then
							modifyEffect(nodeEffect, "Remove")
						end
					end
				end
			end
		end
	end
end


function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end

	if onCustomPreAddEffect(sUser, sIdentity, nodeCT, rNewEffect,bShowMsg) == false then
		return
	end
	-- Play nice with others
	addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)

	if onCustomPostAddEffect(sUser, sIdentity, nodeCT, rNewEffect) == false then
		return
	end

	local rActor = ActorManager.resolveActor(nodeCT)
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		if (DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) and
			(DB.getValue(nodeEffect, "init", 0) == rNewEffect.nInit) and
			(DB.getValue(nodeEffect, "duration", 0) == rNewEffect.nDuration) and
			(DB.getValue(nodeEffect,"source_name", "") == rNewEffect.sSource) then

			local nodeSource = DB.findNode(rNewEffect.sSource)
			local rSource = ActorManager.resolveActor(nodeSource)
			local rTarget = rActor
			if processEffect(rSource, nodeEffect, "TURNRS", rTarget)  then
				local nDuration = DB.getValue(nodeEffect, "duration", 0)
				if nDuration > 0 and Session.IsHost then
					DB.setValue(nodeEffect, "duration", "number", nDuration + 1)
				end
			end
		end
	end
end

function processEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive)
	if nodeEffect ~= nil then
		local sEffect = DB.getValue(nodeEffect, "label", "")
		if sEffect:match(sBCETag) == nil  then -- Does it contain BCE Tag
			return false
		end
		local nActive = DB.getValue(nodeEffect, "isactive", 0)
		--is it active
		if  ((nActive == 0 and bIgnoreDeactive == nil) or nActive == 2) then
			if nActive == 2 and Session.IsHost then -- Don't think we need to check if is host 
				DB.setValue(nodeEffect, "isactive", "number", 1)
			end
			return false
		end
			
		return onCustomProcessEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive)
	else
		return false -- Effect doesn't exist anymore
	end
end

function checkApply(nodeEffect)
	if nActive == 2 then
		DB.setValue(nodeEffect, "isactive", "number", 1);
	else
		local sApply = DB.getValue(nodeEffect, "apply", "");
		if sApply == "action" then
			EffectManager.notifyExpire(nodeEffect, 0);
		elseif sApply == "roll" then
			EffectManager.notifyExpire(nodeEffect, 0, true);
		elseif sApply == "single" then
			EffectManager.notifyExpire(nodeEffect, nMatch, true);
		end
	end
	return true
end

function matchEffect(sEffect, aComps)
	if not aComps then
		aComps = {
			"TDMGADDT",
			"TDMGADDS",
			"SDMGADDT",
			"SDMGADDS",
			"EXPIREADD"
		};
	end

	local rEffect = {}
	local sEffectLookup = ""
	local aEffectComps = EffectManager.parseEffect(sEffect)
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)

		-- Parse out individual componets 
		if StringManager.contains(aComps, rEffectComp.type) then	
			local aEffectLookup = rEffectComp.remainder
			sEffectLookup = EffectManager.rebuildParsedEffect(aEffectLookup)
			sEffectLookup = sEffectLookup:gsub("%;", "")
		end	
	end
	--Find the effect name in our custom effects list
	for _,v in pairs(DB.getChildrenGlobal("effects")) do
		rEffect = {}
		local sEffect = DB.getValue(v, "label", "")
		if sEffect ~= nil and sEffect ~= "" then
			aEffectComps = EffectManager.parseEffect(sEffect)
			-- Is this the effeect we are looking for?
			-- Name is parsed to index 1 in the array
			if aEffectComps[1]:lower() == sEffectLookup:lower() then
				local nodeGMOnly = DB.getChild(v, "isgmonly")	
				if nodeGMOnly then
					rEffect.nGMOnly = nodeGMOnly.getValue()
				end

				local nodeEffectDuration = DB.getChild(v, "duration")
				if nodeEffectDuration then
					rEffect.nDuration = nodeEffectDuration.getValue()
				end
				local nodeUnits = DB.getChild(v, "unit")
				if nodeUnits then
					rEffect.sUnits = nodeUnits.getValue()
				end
				rEffect.sName = sEffect
				if onCustomMatchEffect(sEffect) then
					break
				end
			end
		end
	end
	return rEffect
end

function modifyEffect(nodeEffect, sAction, sEffect)
	local nActive = DB.getValue(nodeEffect, "isactive", 0)

	if sAction == "Activate" then
		if nActive == 1 then
			return
		else
			sendOOB(nodeEffect, OOB_MSGTYPE_BCEACTIVATE)
		end
	end
	if sAction == "Deactivate" then
		if nActive == 0 then
			return
		else
			sendOOB(nodeEffect, OOB_MSGTYPE_BCEDEACTIVATE)
		end
	end
	if sAction == "Remove" then
		sendOOB(nodeEffect, OOB_MSGTYPE_BCEREMOVE)
	end
	if sAction == "Update" then
		sendOOB(nodeEffect, OOB_MSGTYPE_BCEUPDATE, sEffect)
	end
end

-- CoreRPG has no function to activate effect. If it did it would likely look this this
function activateEffect(nodeActor, nodeEffect)
	if not nodeEffect then
		return false
	end
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
	if  Session.IsHost then
		DB.setValue(nodeEffect, "isactive", "number", 1)
	end
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_activated"))
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

function updateEffect(nodeActor, nodeEffect, sLabel)
	if not nodeEffect then
		return false
	end
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sLabel, Interface.getString("effect_status_updated"))
	if  Session.IsHost then
		DB.setValue(nodeEffect, "label", "string", sLabel)
	end
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

function handleActivateEffect(msgOOB)
	if handlerCheck(msgOOB) then
		local nodeActor = DB.findNode(msgOOB.sNodeActor)
		local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
		activateEffect(nodeActor, nodeEffect)
	end
end

function handleUpdateEffect(msgOOB)
	if handlerCheck(msgOOB) then
		local nodeActor = DB.findNode(msgOOB.sNodeActor)
		local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
		updateEffect(nodeActor, nodeEffect, msgOOB.sLabel)
	end
end 

function handleDeactivateEffect(msgOOB)
	if handlerCheck(msgOOB) then
		local nodeActor = DB.findNode(msgOOB.sNodeActor)
		local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
		EffectManager.deactivateEffect(nodeActor, nodeEffect)
	end
end

function handleRemoveEffect(msgOOB)
	if handlerCheck(msgOOB) then
		local nodeActor = DB.findNode(msgOOB.sNodeActor)
		local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
		EffectManager.expireEffect(nodeActor, nodeEffect, 0)
	end
end

function handlerCheck(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor)
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")")
		return false
	end
	local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sNodeEffect .. ")")
		return false
	end
	return true
end

function sendOOB(nodeEffect,type, sEffect)
	local msgOOB = {}

	msgOOB.type = type
	msgOOB.sNodeActor = nodeEffect.getParent().getParent().getPath()
	msgOOB.sNodeEffect = nodeEffect.getPath()
	if type == OOB_MSGTYPE_BCEUPDATE then
		msgOOB.sLabel = sEffect
	end
	Comm.deliverOOBMessage(msgOOB, "")
end

-----------------------------------------
-----------CUSTOM BCE HOOKS--------------
-----------------------------------------
local aCustomProcessTurnStartHandlers = {}
local aCustomProcessTurnEndHandlers = {}
local aCustomMatchEffectHandlers = {}
local aCustomProcessEffectHandlers = {}
local aCustomPreAddEffectHandlers = {}
local aCustomPostAddEffectHandlers = {}

function setCustomProcessTurnStart(f)
	table.insert(aCustomProcessTurnStartHandlers, f)
end

function removeCustomProcessTurnStart(f)
	for kCustomProcess,fCustomProcess in ipairs(aCustomProcessTurnStartHandlers) do
		if fCustomProcess == f then
			table.remove(aCustomProcessTurnStartHandlers, kCustomProcess)
			return true
		end
	end
	return false
end

function onCustomProcessTurnStart(sourceNodeCT, nodeCT, nodeEffect)
	for _,fCustomProcess in ipairs(aCustomProcessTurnStartHandlers) do
		if fCustomProcess(sourceNodeCT, nodeCT, nodeEffect) == false then
			return false
		end
	end
	return true
end

function setCustomProcessTurnEnd(f)
	table.insert(aCustomProcessTurnEndHandlers, f)
end
function removeCustomProcessTurnEnd(f)
	for kCustomProcess,fCustomProcess in ipairs(aCustomProcessTurnEndHandlers) do
		if fCustomProcess == f then
			table.remove(aCustomProcessTurnEndHandlers, kCustomProcess)
			return true
		end
	end
	return false
end

function onCustomProcessTurnEnd(sourceNodeCT, nodeCT, nodeEffect)
	for _,fCustomProcess in ipairs(aCustomProcessTurnEndHandlers) do
		if fCustomProcess(sourceNodeCT, nodeCT, nodeEffect) == false then
			return false
		end
	end
	return true
end

function setCustomMatchEffect(f)
	table.insert(aCustomMatchEffectHandlers, f)
end
function removeCustomMatchEffect(f)
	for kCustomMatchEffect,fCustomMatchEffect in ipairs(aCustomMatchEffectHandlers) do
		if fCustomMatchEffect == f then
			table.remove(aCustomMatchEffectHandlers, kCustomMatchEffect)
			return true
		end
	end
	return false
end

function onCustomMatchEffect(sEffect)
	for _,fMatchEffect in ipairs(aCustomMatchEffectHandlers) do
		if fMatchEffect(sourceNodeCT, nodeCT, nodeEffect) == false then
			return false
		end
	end
	return true
end

function setCustomProcessEffect(f)
	table.insert(aCustomProcessEffectHandlers, f)
end
function removeCustomProcessEffect(f)
	for kCustomProcessEffect,fCustomProcessEffect in ipairs(aCustomProcessEffectHandlers) do
		if fCustomProcessEffect == f then
			table.remove(aCustomProcessEffectHandlers, kCustomProcessEffect)
			return true
		end
	end
	return false
end

function onCustomProcessEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive)
	for _,fProcessEffect in ipairs(aCustomProcessEffectHandlers) do
		if fProcessEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive) == false then
			return false
		end
	end
	return true
end

function setCustomPreAddEffect(f)
	table.insert(aCustomPreAddEffectHandlers, f)
end
function removeCustomPreAddEffect(f)
	for kCustomPreAddEffect,fCustomPreAddEffect in ipairs(aCustomPreAddEffectHandlers) do
		if fCustomPreAddEffect == f then
			table.remove(aCustomPreAddEffectHandlers, kCustomPreAddEffect)
			return true
		end
	end
	return false
end

function onCustomPreAddEffect(sUser, sIdentity, nodeCT, rNewEffect,bShowMsg)
	-- do this backwards from order added. Need to account for string changes in the effect
	-- from things like [STR] before we do any dice roll handlers
	for i = #aCustomPreAddEffectHandlers, 1, -1 do
		if aCustomPreAddEffectHandlers[i](sUser, sIdentity, nodeCT, rNewEffect,bShowMsg) == false then
			return false
		end
	end
	return true
end

function setCustomPostAddEffect(f)
	table.insert(aCustomPostAddEffectHandlers, f)
end
function removeCustomPostAddEffect(f)
	for kCustomPostAddEffect,fCustomPostAddEffect in ipairs(aCustomPostAddEffectHandlers) do
		if fCustomPostAddEffect == f then
			table.remove(aCustomPostAddEffectHandlers, kCustomPostAddEffect)
			return true
		end
	end
	return false
end

function onCustomPostAddEffect(sUser, sIdentity, nodeCT, rNewEffect)
	for _,fPostAddEffect in ipairs(aCustomPostAddEffectHandlers) do
		fPostAddEffect(sUser, sIdentity, nodeCT, rNewEffect) 
	end
end
