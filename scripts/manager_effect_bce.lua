--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

OOB_MSGTYPE_BCEACTIVATE = "activateeffect"
OOB_MSGTYPE_BCEDEACTIVATE = "deactivateeffect"
OOB_MSGTYPE_BCEREMOVE = "removeeffect"
OOB_MSGTYPE_BCEUPDATE = "updateeffect"
local bAdvancedEffects = false
local addEffect = nil
local expireEffect = nil
local RulesetEffectManager =  nil
local lastExpire = ""
local extensions = {}

-- Predefined option arrays for getting effect tags
aBCEActivateOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = true, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 0}
aBCEActivateNoDisableOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = true, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = true, nDuration = 0}
aBCEDeactivateOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 0}
aBCEDefaultOptions = {bTargetedOnly = false, bIgnoreEffectTargets = false, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 0}
aBCERemoveOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 1}
aBCERemoveSourceMattersOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = false, bOnlySourceEffect = true, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 1}
aBCEIgnoreOneShotOptions = {bTargetedOnly = false, bIgnoreEffectTargets = false, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = true, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 0}
aBCESourceMattersOptions = {bTargetedOnly = false, bIgnoreEffectTargets = false, bOnlyDisabled = false, bOnlySourceEffect = true, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = false, bNoDisable = false, nDuration = 0}
aBCEOneShotOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = true, bAdvancedEffects = false, bNoDisable = false, nDuration = 0}

--Options for tags that work for Advanced Effects
aBCEActivateOptionsAE = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = true, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = true, bNoDisable = false, nDuration = 0}
aBCEDeactivateOptionsAE = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = true, bNoDisable = false, nDuration = 0}
aBCEDefaultOptionsAE = {bTargetedOnly = false, bIgnoreEffectTargets = false, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = false, bAdvancedEffects = true, bNoDisable = false, nDuration = 0}
aBCEOneShotOptions = {bTargetedOnly = false, bIgnoreEffectTargets = true, bOnlyDisabled = false, bOnlySourceEffect = false, bIgnoreOneShot = false, bOneShot = true, bAdvancedEffects = true, bNoDisable = false, nDuration = 0}

local tBCETag = {}

function onInit()
	registerBCETag("TURNAS", aBCEActivateOptions)
	registerBCETag("TURNAE", aBCEActivateOptions)
	registerBCETag("ATURN", aBCEActivateNoDisableOptions)

	registerBCETag("TURNRS",  aBCERemoveOptions)
	registerBCETag("STURNRS", aBCERemoveSourceMattersOptions)
	registerBCETag("TURNRE",  aBCERemoveOptions)
	registerBCETag("STURNRE", aBCERemoveSourceMattersOptions)

	registerBCETag("TURNDE", aBCEDeactivateOptions)
	registerBCETag("TURNDS", aBCEDeactivateOptions)

	registerBCETag("EXPIREADD", aBCEIgnoreOneShotOptions)

	if User.getRulesetName() == "5E" then
		RulesetEffectManager = EffectManager5E
	elseif User.getRulesetName() == "4E" then
		RulesetEffectManager = EffectManager
	elseif User.getRulesetName() == "3.5E" or User.getRulesetName() == "PFRPG" then
		RulesetEffectManager = EffectManager35E
	else
		RulesetEffectManager = EffectManager
	end
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

	for index, name in pairs(Extension.getExtensions()) do
		extensions[name] = index
   	end
	if hasExtension("AdvancedEffects") or hasExtension("FG-PFRPG-Advanced-Effects") then
		bAdvancedEffects =  true
	end
end
function onClose()
	EffectManager.addEffect = addEffect
	EffectManager.expireEffect = expireEffect

	ActionsManager.unregisterResultHandler("effectbce")
end

function registerBCETag(sTag, aOptions, bNoUpdate)
	local bUpdated = true

	if bNoUpdate == nil then
		tBCETag[sTag] = aOptions
	elseif bNoUpdate and tBCETag[sTag] == nil then
		tBCETag[sTag] = aOptions
	else
		-- Not updated
		bUpdated = false
	end
	return bUpdated
end

function unregisterBCETag(sTag)
	tBCETag[sTag] = nil
end

function hasExtension(sName)
	if extensions[sName] then
		return true
	else
		return false
	end
end

-- Expire effect is called twice. Once initially and then once for delayed remove
-- to get the delay expire action options
function customExpireEffect(nodeActor, nodeEffect, nExpireComp)
	if not nodeActor or not nodeEffect or nodeEffect == lastExpire then
		return expireEffect(nodeActor, nodeEffect, nExpireComp)
	end
	lastExpire = nodeEffect
	-- Adding an effect before we expire the existing can make a feedback loop
	-- which causes a stack overflow so we see if the effect has expire add, grab it
	-- expire the effect and then process for any adds or additional expires
	local sSource = DB.getValue(nodeEffect,"source_name", "")
	local rSource = ActorManager.resolveActor(nodeActor)
	local nInit = DB.getValue(nodeEffect,"init", 0)
	local aTags = {"EXPIREADD"}

	local bRet = expireEffect(nodeActor, nodeEffect, nExpireComp)
	local tMatch = getEffects(rSource, aTags, rSource)
	for _,tEffect in pairs(tMatch) do
		if tEffect.nodeCT == nodeEffect and tEffect.sTag == "EXPIREADD" then
			local rEffect = EffectsManagerBCE.matchEffect(tEffect.rEffectComp.remainder[1])
			if next(rEffect) then
				rEffect.sSource = sSource
				rEffect.nInit = nInit
				aTags  = EffectManager.parseEffect(tEffect.sLabel)
				-- Check for match
				for i,sTag in pairs(aTags) do
					local rEffectComp = nil
					if RulesetEffectManager.parseEffectComp then
						rEffectComp = RulesetEffectManager.parseEffectComp(sTag)
					else
						rEffectComp = RulesetEffectManager.parseEffectCompSimple(sTag)
					end
					if "EXPIREADD" == rEffectComp.type:upper() then
						-- if the effect has already been deleted in full
						if type(nodeEffect) ~= "error" then
							expireEffect(nodeActor, nodeEffect, i)
						end
						EffectManager.addEffect("", "", nodeActor, rEffect, true)
					end
				end
			end
			break
		end
	end
	return bRet
end

function customTurnStart(sourceNodeCT)
	if not sourceNodeCT then
		return
	end
	local rSource = ActorManager.resolveActor(sourceNodeCT)
	local ctEntries = CombatManager.getCombatantNodes()

	if onCustomProcessTurnStart(rSource) then
		local aTags = {"TURNAS", "TURNDS", "TURNRS"}
		local tMatch = getEffects(rSource, aTags, rSource)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "TURNAS" then
				modifyEffect(tEffect.nodeCT, "Activate")
			elseif tEffect.sTag == "TURNDS" then
				modifyEffect(tEffect.nodeCT, "Deactivate")
			elseif  tEffect.sTag  == "TURNRS" then
				modifyEffect(tEffect.nodeCT, "Remove")
			end
		end

		aTags = {"STURNRS","ATURN"}
		for _, nodeCT in pairs(ctEntries) do
			local rActor = ActorManager.resolveActor(nodeCT)
			if rActor.sCTNode ~= rSource.sCTNode then
				tMatch = getEffects(rActor, aTags, rActor, rSource)
				for _,tEffect in pairs(tMatch) do
					if tEffect.sTag == "STURNRS" then
						modifyEffect(tEffect.nodeCT, "Remove")
					end
					if tEffect.sTag == "ATURN" then
						modifyEffect(tEffect.nodeCT, "Activate")
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
	local ctEntries = CombatManager.getCombatantNodes()
	if onCustomProcessTurnEnd(rSource) then
		local aTags = {"TURNAE", "TURNDE", "TURNRE"}
		local tMatch = getEffects(rSource, aTags, rSource)
		for _,tEffect in pairs(tMatch) do
			if tEffect.sTag == "TURNAE" then
				modifyEffect(tEffect.nodeCT, "Activate")
			elseif tEffect.sTag == "TURNDE" then
				modifyEffect(tEffect.nodeCT, "Deactivate")
			elseif  tEffect.sTag == "TURNRE" then
				modifyEffect(tEffect.nodeCT, "Remove")
			end
		end

		aTags = {"STURNRE"}
		for _, nodeCT in pairs(ctEntries) do
			local rActor = ActorManager.resolveActor(nodeCT)
			if rActor.sCTNode ~= rSource.sCTNode then
				tMatch = getEffects(rActor, aTags, rActor, rSource)
				for _,tEffect in pairs(tMatch) do
					if tEffect.sTag == "STURNRE" then
						modifyEffect(tEffect.nodeCT, "Remove")
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
	local sUnits = rNewEffect.sUnits or ""

	if onCustomPreAddEffect(sUser, sIdentity, nodeCT, rNewEffect,bShowMsg) == false then
		return
	end
	-- Play nice with others
	addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local nodeDisableEffect = nil
	local bDeactivate = false

	--Deactivate Check here. Deactivate at end
	if rNewEffect.sName:match("%(DE%)") then
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			if (DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) and
			(DB.getValue(nodeEffect, "duration", 0) == rNewEffect.nDuration) and
			ActorManager.getDisplayName(nodeCT) ~= "" then
				nodeDisableEffect = nodeEffect
				bDeactivate = true
				break
			end
		end
	end

	local rActor = ActorManager.resolveActor(nodeCT)
	if Session.IsHost and rNewEffect.nDuration ~= 0 then
		--Special Case. We want to get the effect with TURNRS but we aren't processing it
		-- we are just reseting the duration so it processes correctly
		registerBCETag("TURNRS",  aBCEIgnoreOneShotOptions)
		local aTags = {"TURNRS"}
		local tMatch = getEffects(rActor, aTags, rActor)
		for _,tEffect in pairs(tMatch) do
			if type(tEffect.nodeCT) == "databasenode" and
			tEffect.sTag == "TURNRS" and
			(DB.getValue(tEffect.nodeCT, "label", "") == rNewEffect.sName) and
			(DB.getValue(tEffect.nodeCT, "init", 0) == rNewEffect.nInit) and
			(DB.getValue(tEffect.nodeCT, "duration", 0) == rNewEffect.nDuration) and
			(DB.getValue(tEffect.nodeCT,"source_name", "") == rNewEffect.sSource) then
				DB.setValue(tEffect.nodeCT, "duration", "number", rNewEffect.nDuration + 1)
			end
		end
		--reset the options to what they should be
		registerBCETag("TURNRS",  aBCERemoveOptions)
	end

	if bDeactivate then
		modifyEffect(nodeDisableEffect, "Deactivate")
	end
	-- 5E scubs the sUnits so we add it back in
	rNewEffect.sUnits = sUnits
	if onCustomPostAddEffect(sUser, sIdentity, nodeCT, rNewEffect) == false then
		return
	end

end

--Helper function
function getDamageTypes(rRoll)
	local aDMGTypes = {}
	aDMGTypes.sRange = rRoll.range
	for _,aType in pairs(rRoll.clauses) do
		table.insert(aDMGTypes, {aDMG = ActionDamage.getDamageTypesFromString(aType.dmgtype), nTotal = aType.nTotal})
	end
	return aDMGTypes
end


--This function gets called a ton and it seems expensive. Try to do as much optimization as possible
	-- by grouping tags called at the same point in the code
function getEffects(rActor, aTags, rTarget, rSourceEffect, nodeEffect, aDMGTypes, aConditions)
	for v,sTag in pairs(aTags) do
		-- make sure passed tag is a registered tag
		if not tBCETag[sTag]  then
			table.remove(aTags, v)
		end
	end
	-- If we have no vaild tags to process or no rActor return empty
	if aTags == {} or not rActor then
		return {}
	end

	local rEffectComp
	local aOptions

	-- Iterate through each effect
	local aMatch = {}
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		local nActive = DB.getValue(v, "isactive", 0);
		local sLabel = DB.getValue(v, "label", "")
		local nGMOnly = DB.getValue(v, "isgmonly", "")
		local sSourceEffect = DB.getValue(v, "source_name", "")
		local nDuration = tonumber(DB.getValue(v, "duration", ""))
		local bTargeted = EffectManager.isTargetedEffect(v)
		local tEffectComps = EffectManager.parseEffect(sLabel)
		local bAEValid = true
		local bDisableUse = false

		if bAdvancedEffects then
			if User.getRulesetName() == "5E" then
				bAEValid = EffectManagerADND.isValidCheckEffect(rActor,v)
			elseif User.getRulesetName() == "PFRPG" or User.getRulesetName() == "3.5E" then
				bAEValid = AdvancedEffects.isValidCheckEffect(rActor,v)
			end
		end
		if  sLabel:match("DUSE") then
			bDisableUse = true
		end
		-- We only want to process a specific effect. Used mostly
		-- for something to happen after a save result
		if not nodeEffect or nodeEffect == v then
			-- Iterate through each effect component looking for a type match
			for kEffectComp,sEffectComp in ipairs(tEffectComps) do
				local tMatch = {}
				if RulesetEffectManager.parseEffectComp then
					rEffectComp = RulesetEffectManager.parseEffectComp(sEffectComp)
				else
					rEffectComp = RulesetEffectManager.parseEffectCompSimple(sEffectComp)
				end

				-- Handle conditionals
				if rEffectComp.type == "IF" and RulesetEffectManager.checkConditional then
					if not RulesetEffectManager.checkConditional(rActor, v, rEffectComp.remainder) then
						break
					end
				elseif hasExtension("IF_NOT_untrue_effects_berwind") and rEffectComp.type == "IFN" then
					if RulesetEffectManager.checkConditional(rActor, v, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFT" and RulesetEffectManager.checkConditional then
					if not rTarget then
						break
					end
					if not RulesetEffectManager.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
						break
					end
				elseif  hasExtension("IF_NOT_untrue_effects_berwind") and rEffectComp.type == "IFTN" then
					if not rTarget then
						break;
					end
					if RulesetEffectManager.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
						break
					end
				end
				-- Check for match
				for _,sTag in pairs(aTags) do
					if rEffectComp.original:upper() == sTag or rEffectComp.type:upper() == sTag  then
						local bDiscard = false
						-- Get the options
						aOptions =  tBCETag[sTag]

						if aOptions.bNoDisable then
							bDisableUse = false
						end
						-- If we have rSourceEffect, then only match effects where the source of the
						-- effect matches rSourceEffect
						if rSourceEffect and aOptions.bOnlySourceEffect and
							rSourceEffect.sCTNode ~= DB.getValue(v, "source_name", "") then
							break
						end

						if ((aOptions.bOnlyDisabled and nActive == 0 ) or nActive ~= 0) then
							if aOptions.nDuration ~= 0 and aOptions.nDuration ~= nDuration then
								break
							else
								-- Do damage and range filter
								if aDMGTypes then
									bDiscard = true
									for _,sRemainder in ipairs(rEffectComp.remainder) do
										if sRemainder == "all" then
											bDiscard = false
										elseif aDMGTypes.aDamageTypes[sRemainder] then
											bDiscard = false
										end
										if bDiscard == false then
											break
										end
									end
								end
								if aConditions then
									bDiscard = true
									for _,sRemainder in ipairs(rEffectComp.remainder) do
										sRemainder = sRemainder:lower()
										if sRemainder == "all" or StringManager.contains(aConditions, sRemainder) then
											bDiscard = false
											break
										end
									end
								end
								-- Check to see if we have a hard fail save
								if rEffectComp.type == "SAVEADD" then
									if tonumber(rEffectComp.mod) > 0 and (tonumber(rEffectComp.mod) + rActor.nResult >= rActor.nDC) then
										-- Failed by more than mod on the save
										bDiscard = true
									elseif tonumber(rEffectComp.mod) < 0  and (rActor.nResult <= math.abs(tonumber(rEffectComp.mod))) then
										bDiscard = true
									end
								end
								-- Is this a vaild AE BCE tag and if so is the attached item being used?
								if bAEValid == false and aOptions.bAdvancedEffects then
									bDiscard = true
								end
								if bTargeted and not aOptions.bIgnoreEffectTargets and bDiscard == false then
									if EffectManager.isEffectTarget(v, rTarget) then
										table.insert(tMatch, {nMatch = kEffectComp, sTag = sTag, sSourceEffect = sSourceEffect, bDisableUse = bDisableUse, nGMOnly = nGMOnly, bIgnoreOneShot = aOptions.bIgnoreOneShot})
									end
								elseif not aOptions.bTargetedOnly and bDiscard == false then
									table.insert(tMatch, {nMatch = kEffectComp, sTag = sTag, sSourceEffect = sSourceEffect, bDisableUse = bDisableUse, nGMOnly = nGMOnly, bIgnoreOneShot = aOptions.bIgnoreOneShot})
								end
							end
						end
					end
				end
				for _,aMatchComp in pairs(tMatch) do

					-- If matched, then remove one-off effects
					if type(v) == "databasenode" and aMatchComp.bIgnoreOneShot == false  then
						if nActive == 2 then
							DB.setValue(v, "isactive", "number", 1)
						else
							table.insert(aMatch, {nodeCT = v, sTag = aMatchComp.sTag, sSource = aMatchComp.sSourceEffect,
							sLabel = sLabel, nGMOnly = aMatchComp.nGMOnly, bDisableUse = aMatchComp.bDisableUse, rEffectComp = rEffectComp})
							local sApply = DB.getValue(v, "apply", "")
							if sApply == "action" then
								EffectManager.notifyExpire(v, 0)
							elseif sApply == "roll" then
								EffectManager.notifyExpire(v, 0, true)
							elseif sApply == "single" or aOptions.bOneShot == true then
								EffectManager.notifyExpire(v, aMatchComp.nMatch, true)
							end
						end
					elseif type(v) == "databasenode" and aMatchComp.bIgnoreOneShot == true then
						table.insert(aMatch, {nodeCT = v, sTag = aMatchComp.sTag, sSource = aMatchComp.sSourceEffect,
						sLabel = sLabel, nGMOnly = aMatchComp.nGMOnly, bDisableUse = aMatchComp.bDisableUse, rEffectComp = rEffectComp})
					end
				end
			end
		end
	end
	for _,tEffect in ipairs(aMatch) do
		if tEffect.sLabel:match("DUSE") and tEffect.bDisableUse and type(tEffect.nodeCT) == "databasenode" then
			EffectsManagerBCE.modifyEffect(tEffect.nodeCT, "Deactivate")
		end
	end
	return aMatch
end

-- We are looking for the label which is the first tag followed by ; if not the end
function matchEffect(sEffectSearch, aComps)
	local sEffectLookup = sEffectSearch:lower()

	--search conditions table first
	if DataCommon and DataCommon.conditions  then
		if StringManager.contains(DataCommon.conditions, sEffectLookup:lower()) then
			local rEffect = {}
			rEffect.sName = StringManager.capitalize(sEffectLookup)
			rEffect.nDuration = 0
			rEffect.sUnits = ""
			rEffect.nGMOnly = 0
			return rEffect
		end
	end

	local rEffect = {}
	--Find the effect name in our custom effects list
	for _,v in pairs(DB.getChildrenGlobal("effects")) do
		local sEffect = DB.getValue(v, "label", "")
		if sEffect ~= "" then
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
				local apply = DB.getChild(v, "apply")
				if apply then
					rEffect.sApply = DB.getValue(v, "apply", "")
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
	-- Must be database node, if not it is probably marked for deletion from one-shot
	if type(nodeEffect) ~= "databasenode" then
		return
	end
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

function onCustomProcessTurnStart(rSource)
	for _,fCustomProcess in ipairs(aCustomProcessTurnStartHandlers) do
		if fCustomProcess(rSource) == false then
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

function onCustomProcessTurnEnd(rSource)
	for _,fCustomProcess in ipairs(aCustomProcessTurnEndHandlers) do
		if fCustomProcess(rSource) == false then
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
		if fMatchEffect(sEffect) == false then
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

function onCustomPostAddEffect(sUser, sIdentity, nodeCT, rNewEffect, nodeEffect)
	for _,fPostAddEffect in ipairs(aCustomPostAddEffectHandlers) do
		fPostAddEffect(sUser, sIdentity, nodeCT, rNewEffect, nodeEffect)
	end
end
