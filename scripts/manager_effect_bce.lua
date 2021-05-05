--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

-- Better Combat Effects CT Values
-- TURNAS  activate start of turn
-- TURNDS  deactivate start of turn
-- TURNRS  remove start of turn
-- TURNAE  activate end of turn
-- TURNDE  deactivate end of turn
-- TURNRE  remove end of turn
-- DMGDT deactivate when target takes damage 
-- DMGAT activate when target takes damage
-- DMGRT remove when target takes damage 
-- TDMGADDT target add effect to the target when damage taken
-- TDMGADDS target add effect to the source of the damage
-- SDMGADDT source add effect to the target when damage taken
-- SDMGADDS source add effect to the source of the damage

OOB_MSGTYPE_BCEACTIVATE = "activateeffect";
OOB_MSGTYPE_BCEDEACTIVATE = "deactivateeffect";
OOB_MSGTYPE_BCEREMOVE = "removeeffect";

function onInit()
	OptionsManager.registerOption2("ALLOW_DUPLICATE_EFFECT", false, "option_Better_Combat_Effects", 
	"option_Allow_Duplicate", "option_entry_cycler", 
	{ labels = "option_val_on", values = "on",
	  baselabel = "option_val_off", baseval = "off", default = "off" });

	OptionsManager.registerOption2("TEMP_IS_DAMAGE", false, "option_Better_Combat_Effects", 
	"option_Temp_Is_Damage", "option_entry_cycler", 
	{ labels = "option_val_on", values = "on",
		baselabel = "option_val_off", baseval = "off", default = "off" });  

	-- save off the originals so we play nice with others
	onDamage = ActionDamage.onDamage;
	addEffect = EffectManager.addEffect;

	ActionDamage.onDamage = customOnDamage;
	EffectManager.addEffect = customAddEffect;

	if User.getRulesetName() == "5E" then
		rest = CombatManager2.rest;
		CombatManager2.rest = customRest;
	end

	ActionsManager.registerResultHandler("damage", customOnDamage);
	ActionsManager.registerResultHandler("effectbce", onEffectRollHandler);

	CombatManager.setCustomTurnStart(customTurnStart);
	CombatManager.setCustomTurnEnd(customTurnEnd);
	
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEACTIVATE, handleActivateEffect);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEDEACTIVATE, handleDeactivateEffect);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEREMOVE, handleRemoveEffect);
end

--5E only. Deletes effets on long/short rest with tags to do so
function customRest(bLong)
	for _,nodeActor in pairs(CombatManager.getCombatantNodes()) do
		for _,nodeEffect in pairs(DB.getChildren(nodeActor, "effects")) do
			sEffect = DB.getValue(nodeEffect, "label", "");
			if sEffect:match("RESTL") or sEffect:match("RESTS") then
				if bLong == false and sEffect:match("RESTS") then
					nodeEffect.delete();
				end
				if bLong == true then
					nodeEffect.delete();
				end
			end
		end
	end
	rest(bLong);
end

function performRoll(draginfo, rActor, rRoll)
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function onEffectRollHandler(rSource, rTarget, rRoll)
	local nodeSource = ActorManager.getCTNode(rSource);
	local nResult = ActionsManager.total(rRoll);

	if rRoll.sType ~= "effectbce" then
		return;
	end

	if not Session.IsHost then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectclient"));
		return;
	end
	
	local sEffect = "";
	local sEffectOriginal = "";
	local nodeEffect = nil;
	for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
		sEffect = DB.getValue(nodeEffect, "label", "");
		if sEffect == rRoll.sEffect then
			sEffectOriginal = sEffect
			local sResult = tostring(nResult);
			local sValue = rRoll.sValue;
			local sReverseValue = string.reverse(sValue);
			---Needed to get creative with patern matching - to correctly process
			-- if the negative is to total, or do we have a negative modifier
			if sValue:match("%+%d+") then
				sValue = sValue:gsub("%+%d+", "") .. "%+%d+";
			elseif  (sReverseValue:match("%d+%-") and rRoll.nMod ~= 0) then
				sReverseValue = sReverseValue:gsub("%d+%-", "", 1);
				sValue = "%-?" .. string.reverse(sReverseValue) .. "%-*%d?";
			elseif (sReverseValue:match("%d+%-") and rRoll.nMod == 0) then
				sValue = "%-*" .. sValue:gsub("%-", "");
			end
			sEffect = sEffect:gsub(sValue, sResult);
			DB.setValue(nodeEffect, "label", "string", sEffect);
			break;
		end
	end
	-- Deliver message
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
	local sMessage = string.format("%s ['%s'] -> [%s] -> [%s]", Interface.getString("effect_label"), sEffectOriginal,  sEffect, Interface.getString("effect_status_updated"));
	EffectManager.message(sMessage, nodeSource, bGMOnly);

end

function customTurnStart(nodeCT)
	if not nodeCT then
		return;
	end

	local cbTable = CombatManager.getCombatantNodes();
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "");
		local sAction = nil;
					
		if sEffect:match("TURNAS") then
			sAction = "Activate";
		elseif sEffect:match("TURNDS") then
			sAction = "Deactivate";
		elseif sEffect:match("TURNRS") then
			sAction = "Remove";
		end

		if sAction ~= nil then
			modifyEffect(nodeEffect, sAction);
		end
	end
end

function customTurnEnd(nodeCT)
	if not nodeCT then
		return;
	end
	
	-- loop all items in the CT and refresh any effects with the turn flag
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "");
		local sAction = nil;
		
		if sEffect:match("TURNAE") then
			sAction = "Activate";
		elseif sEffect:match("TURNDE") then
			sAction = "Deactivate";
		elseif sEffect:match("TURNRE") then	
			sAction = "Remove";
		end
		if sAction ~= nil then
			modifyEffect(nodeEffect, sAction);			
		end
	end
end

function customOnDamage(rSource, rTarget, rRoll)
	local nodeTarget = ActorManager.getCTNode(rTarget);
	local nodeSource = ActorManager.getCTNode(rSource);

	if rTarget == nil then
		onDamage(rSource, rTarget, rRoll);
	else

		-- save off temp hp and wounds before damage
		local nTempHPPrev, nWoundsPrev = getTempHPAndWounds(rTarget);

		-- Play nice with others
		-- Do damage first then modify any effects
		onDamage(rSource, rTarget, rRoll);

		if rTarget == nil then
			return;
		end
		-- get temp hp and wounds after damage
		local nTempHP, nWounds = getTempHPAndWounds(rTarget);
		
		if OptionsManager.isOption("TEMP_IS_DAMAGE", "on") then
			-- If no damage was applied then return
			if nWoundsPrev >= nWounds and nTempHPPrev <= nTempHP then
				return;
			end
			else
				if nWoundsPrev >= nWounds then
					return;
			end
		end

		-- Loop through effects on the target of the damage
		for _,nodeEffect in pairs(DB.getChildren(nodeTarget, "effects")) do
			local sEffect = DB.getValue(nodeEffect, "label", "");
			local sAction = nil;
			-- TODO --
			-- Add support for only trigger on specific damage types.
			if sEffect:match("DMGAT") then
				sAction = "Activate";
			elseif sEffect:match("DMGDT") then
				sAction = "Deactivate";
			elseif sEffect:match("DMGRT") then	
				sAction = "Remove";
			end

			if sEffect:match("TDMGADDT") or sEffect:match("TDMGADDS") then
				local rEffect = matchEffect(sEffect);
				if rEffect.sName ~= nil then
					-- Set the node that applied the effect
					rEffect.sSource = ActorManager.getCTNodeName(rTarget);
					nodeTarget = ActorManager.getCTNode(rTarget);
					rEffect.nInit  = DB.getValue(nodeTarget, "initresult", 0);
					if sEffect:match("TDMGADDT") then
						EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), rEffect, true);
					elseif sEffect:match("TDMGADDS") then
						EffectManager.addEffect("", "", ActorManager.getCTNode(rSource), rEffect, true);
					end
				end
			end
			if sAction ~= nil then
				modifyEffect(nodeEffect, sAction);		
			end
		end
		-- Loop though the effects on the source of the damage
		for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
			local sEffect = DB.getValue(nodeEffect, "label", "");
			if sEffect:match("SDMGADDT") or sEffect:match("SDMGADDS") then
				local rEffect = matchEffect(sEffect);
				if rEffect.sName ~= nil then
					rEffect.sSource = ActorManager.getCTNodeName(sSource);
					nodeSource = ActorManager.getCTNode(rSource);
					rEffect.nInit  = DB.getValue(nodeSource, "initresult", 0);
					if sEffect:match("SDMGADDT") then
						EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), rEffect, true);
					elseif sEffect:match("SDMGADDS") then
						EffectManager.addEffect("", "", ActorManager.getCTNode(rSource), rEffect, true);
					end
				end
			end
		end
	end
end

-- Add the ability to replace the dice description with a roll and the value
function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return;
	end

	local nodeEffectsList = nodeCT.createChild("effects");
	if not nodeEffectsList then
		return;
	end

	-- Any effect that modifies ability score and is coded with -X
	-- has the -X replaced with the targets ability score and then calculated
	-- The following should be done with a customOnEffectAddStart if the handlers worked properly
	if User.getRulesetName() == "5E" then
		-- check contains -X to see if this is interesting enough to continue
		if rNewEffect.sName:match("%-X") then
			local aEffectComps = EffectManager.parseEffect(rNewEffect.sName);
			for _,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
				local rActor = ActorManager.resolveActor(nodeCT);
				local nAbility = 0;

				if rEffectComp.type == "STR" then			
					nAbility = ActorManager5E.getAbilityScore(rActor, "strength");
				elseif rEffectComp.type  == "DEX" then
					nAbility = ActorManager5E.getAbilityScore(rActor, "dexterity");
				elseif rEffectComp.type  == "CON" then
					nAbility = ActorManager5E.getAbilityScore(rActor, "constitution");
				elseif rEffectComp.type  == "INT" then
					nAbility = ActorManager5E.getAbilityScore(rActor, "intelligence");
				elseif rEffectComp.type  == "WIS" then
					nAbility = ActorManager5E.getAbilityScore(rActor, "wisdom");
				elseif rEffectComp.type  == "CHA" then
					nAbility = ActorManager5E.getAbilityScore(rActor, "charisma");
				end

				if(rEffectComp.remainder[1]:match("%-X")) then
					local sMod = rEffectComp.remainder[1]:gsub("%-X", "");
					local nMod = tonumber(sMod);
					if nMod ~= nil then
						if(nMod > nAbility) then
							nAbility = nMod - nAbility;
						else
							nAbility = 0;
						end
						local sReplace = rEffectComp.type ..": " .. tostring(nAbility);
						local sMatch =  rEffectComp.type ..":%s-%d+%-X";
						rNewEffect.sName = rNewEffect.sName:gsub(sMatch, sReplace);
					end
				end
			end
		end
	end

	-- The custom effects handlers are dangerous because they set the function to the last extension/ruleset that calls it
	-- and therefore there is not really a good way to play nice with other extensions.
	-- The following should be done with a setCustomOnEffectAddIgnoreCheck if the handlers worked properly.
	-- CoreRPG ignores duplicate effects but if setCustomOnEffectAddIgnoreCheck is invoked, like by 5E ruleset, 
	-- the ignore duplicates is bypassed. 5E ignores immunities but never added the duplicate check back in
	-- We've added the STACK option to allow for duplicate effects if needed.
	if OptionsManager.isOption("ALLOW_DUPLICATE_EFFECT", "off") then
		local sDuplicateMsg = nil;
		for k, v in pairs(nodeEffectsList.getChildren()) do
			if not rNewEffect.sName:match("STACK") then
				if (DB.getValue(v, "label", "") == rNewEffect.sName) and
						(DB.getValue(v, "init", 0) == rNewEffect.nInit) and
						(DB.getValue(v, "duration", 0) == rNewEffect.nDuration) then
					sDuplicateMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_exists"));
					break;
				end
			end
		end
		if sDuplicateMsg then
			EffectManager.message(sDuplicateMsg, nodeCT, false, sUser);
			return;
		end
	end

	-- The following should be done with a customOnEffectAddStart if the handlers worked properly
	
	local rRoll = {};
	rRoll = isDie(rNewEffect.sName);
	if next(rRoll) ~= nil then
		local rActor = ActorManager.resolveActor(nodeCT);
		rRoll.rActor = rActor;
		if rNewEffect.nGMOnly  then
			rRoll.bSecret = true;
		else
			rRoll.bSecret = false;
		end
		performRoll(nil, rActor, rRoll);
	end

	-- Play nice with others
	addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
end

function isDie(sEffect)
	local rRoll = {};
	local aEffectComps = EffectManager.parseEffect(sEffect);
	local nMatch = 0;
	for kEffectComp,sEffectComp in ipairs(aEffectComps) do
		local aWords = StringManager.parseWords(sEffectComp, "%.%[%]%(%):");
		local bNegative = 0;
		if #aWords > 0 then
			sType = aWords[1]:match("^([^:]+):");
			-- Only roll dice for ability score mods
			if sType and (sType == "STR" or sType == "DEX" or sType == "CON" or sType == "INT" or sType == "WIS" or sType == "CHA") then
				nRemainderIndex = 2;

				local sValueCheck = "";
				local sTypeRemainder = aWords[1]:sub(#sType + 2);
				if sTypeRemainder == "" then
					sValueCheck = aWords[2] or "";
					nRemainderIndex = nRemainderIndex + 1;
				else
					sValueCheck = sTypeRemainder;
				end
				-- Check to see if negative
				if sValueCheck:match("%-^[d%.%dF%+%-]+$") then
					sValueCheck = sValueCheck:gsub("%-", "", 1);
				end
				if StringManager.isDiceString(sValueCheck) then		
					local aDice, nMod = StringManager.convertStringToDice(sValueCheck);
					rRoll.sType = "effectbce";
					
					rRoll.sDesc = "[EFFECT " .. sEffect .. "] ";
					rRoll.aDice = aDice;
					rRoll.nMod = nMod;
					rRoll.sEffect = sEffect;
					rRoll.sValue = sValueCheck;
				end
			end
		end
	end
	return rRoll;
end

function getTempHPAndWounds(rTarget)
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local nTempHP = 0;
	local nWounds = 0;
	if not nodeTarget then
		return;
	end
	if sTargetNodeType == "pc" then
		nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0);
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0);
	elseif sTargetNodeType == "ct" then
		nTempHP = DB.getValue(nodeTarget, "hptemp", 0);
		nWounds = DB.getValue(nodeTarget, "wounds", 0);
	end
	return nTempHP, nWounds;
end

function matchEffect(sEffect)
	local rEffect = {};
	local sEffectLookup = ""
	local aEffectComps = EffectManager.parseEffect(sEffect);
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);

		-- Parse out individual componets 
		if rEffectComp.type == "TDMGADDT" or rEffectComp.type == "TDMGADDS" or rEffectComp.type == "SDMGADDT" or rEffectComp.type == "SDMGADDS" then	
			local aEffectLookup = rEffectComp.remainder;
			sEffectLookup = EffectManager.rebuildParsedEffect(aEffectLookup);
			sEffectLookup = sEffectLookup:gsub("%;", "");
		end	
	end
	--Find the effect name in our custom effects list
	for _,v in pairs(DB.getChildrenGlobal("effects")) do
		local sEffect = DB.getValue(v, "label", "");
		aEffectComps = EffectManager.parseEffect(sEffect);
		-- Is this the effeect we are looking for?
		-- Name is parsed to index 1 in the array
		if aEffectComps[1]:lower() == sEffectLookup:lower() then
			local nGMOnly =  0;
			local nodeGMOnly = DB.getChild(v, "isgmonly");	
			if nodeGMOnly then
				nGMOnly = nodeGMOnly.getValue();
			end

			local nEffectDuration = 0;
			local nodeEffectDuration = DB.getChild(v, "duration");
			if nodeEffectDuration then
				nEffectDuration = nodeEffectDuration.getValue();
			end
			
			if User.getRulesetName() == "5E" then
				local sUnits = nil;
				local nodeUnits = DB.getChild(v, "unit");
				if nodeUnits then
					sUnits = nodeUnits.getValue();
					rEffect.sUnits = sUnits;
				end
			end

			rEffect.sName = sEffect;
			rEffect.nGMOnly = nGMOnly;
			rEffect.nDuration = nEffectDuration;
			break;
		end
	end
	return rEffect;
end

function modifyEffect(nodeEffect, sAction)
	local nActive = DB.getValue(nodeEffect, "isactive", 0);
	
	-- Activate turn start/end/damage taken
	if sAction == "Activate" then
		if nActive == 1 then
			return;
		else
			sendOOB(nodeEffect, OOB_MSGTYPE_BCEACTIVATE);
		end
	end
	-- Deactivate turn start/end/damage taken
	if sAction == "Deactivate" then
		if nActive == 0 then
			return;
		else
			sendOOB(nodeEffect, OOB_MSGTYPE_BCEDEACTIVATE);
		end
	end
	-- Remove turn start/end/damage take
	if sAction == "Remove" then
		sendOOB(nodeEffect, OOB_MSGTYPE_BCEREMOVE);
	end
end

-- CoreRPG has no function to activate effect. If it did it would likely look this this
function activateEffect(nodeActor, nodeEffect)
	if not nodeEffect then
		return false;
	end

	local sEffect = DB.getValue(nodeEffect, "label", "");
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
	
	DB.setValue(nodeEffect, "isactive", "number", 1);

	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_activated"));
	EffectManager.message(sMessage, nodeActor, bGMOnly);
end

function handleActivateEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor);

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")");
		return;
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectapplyfail") .. " (" .. msgOOB.sNodeEffect .. ")");
		return;
	end
	
	activateEffect(nodeActor, nodeEffect);
end

function handleDeactivateEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor);

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")");
		return;
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sNodeEffect .. ")");
		return;
	end

	EffectManager.deactivateEffect(nodeActor, nodeEffect);
end

function handleRemoveEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor);

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")");
		return;
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sNodeEffect .. ")");
		return;
	end

	local sEffect = DB.getValue(nodeEffect, "label", "");
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_expired"));
	
	EffectManager.removeEffect(nodeActor, sEffect);
	EffectManager.message(sMessage, nodeActor, bGMOnly);
end

function sendOOB(nodeEffect,type)
	local msgOOB = {};

	msgOOB.type = type;
	msgOOB.sNodeActor = nodeEffect.getParent().getParent().getPath();
	msgOOB.sNodeEffect = nodeEffect.getPath();

	Comm.deliverOOBMessage(msgOOB, "");
end