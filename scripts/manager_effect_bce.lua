--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

OOB_MSGTYPE_BCEACTIVATE = "activateeffect"
OOB_MSGTYPE_BCEDEACTIVATE = "deactivateeffect"
OOB_MSGTYPE_BCEREMOVE = "removeeffect"
OOB_MSGTYPE_BCEUPDATE = "updateeffect"

local bMadNomadCharSheetEffectDisplay
local RulesetEffectManager
local RulesetActorManager

function customRoundStart()
	--Readjust init for effects if we are re-rolling inititive each round
	if Session.IsHost and OptionsManager.isOption("HRIR", "on") and (User.getRulesetName() == "5E" or User.getRulesetName() == "4E" or User.getRulesetName() == "3.5E")  then
		local ctEntries = CombatManager.getSortedCombatantList()
		for _, nodeCT in pairs(ctEntries) do
			for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
				if (DB.getValue(nodeEffect, "duration", "") ~= 0) then
					sSource = DB.getValue(nodeEffect, "source_name", "")
					if sSource == "" then
						sSource	= ActorManager.getCTPathFromActorNode(nodeCT)
					end
					local nodeSource = ActorManager.getCTNode(sSource)
					local nInit = DB.getValue(nodeSource, "initresult", 0)
					DB.setValue(nodeEffect, "init", "number", nInit)
				end
			end
		end
	end
end

--5E only. Deletes effets on long/short rest with tags to do so
function exhaustionRest(nodeEffect)
	local bDelete = true
	if User.getRulesetName() == "5E" then
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local aEffectComps = EffectManager.parseEffect(sEffect)
		for i,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type == "EXHAUSTION" and processEffect(rSource,nodeEffect,"EXHAUSTION") then
				if rEffectComp.mod == nil then
					break
				end
				local exhaustionLevel = tonumber(rEffectComp.mod)	
				if  exhaustionLevel > 1 then
					rEffectComp.mod =  exhaustionLevel - 1
					--rebuild the comp
					aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)							
					bDelete = false;
					sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
					local sActor = nodeEffect.getParent().getParent().getPath() -- Node this effect is on
					local rActor = ActorManager.resolveActor(DB.findNode(sActor))
					local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);					
					sEffect = exhaustionText(sEffect, nodeActor, rEffectComp.mod)
					modifyEffect(nodeEffect, "Update", sEffect)
				end
			end
		end
	end
	return bDelete
end

function customRest(bLong)
	for _,nodeActor in pairs(CombatManager.getCombatantNodes()) do
		local rSource = ActorManager.resolveActor(nodeActor)
		for _,nodeEffect in pairs(DB.getChildren(nodeActor, "effects")) do
			sEffect = DB.getValue(nodeEffect, "label", "")
			if sEffect:match("RESTL") or sEffect:match("RESTS") then
				if bLong == false and processEffect(rSource,nodeEffect,"RESTS") then
					modifyEffect(nodeEffect, "Remove", sEffect)
				end
				if bLong == true and (processEffect(rSource,nodeEffect,"RESTS") or processEffect(rSource,nodeEffect,"RESTL") and exhaustionRest(nodeEffect)) then
					modifyEffect(nodeEffect, "Remove", sEffect)
				end
			end
		end
	end
	rest(bLong)
end

function performRoll(draginfo, rActor, rRoll)
	ActionsManager.performAction(draginfo, rActor, rRoll)
end

function onEffectRollHandler(rSource, rTarget, rRoll)
	if not Session.IsHost then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectclient"))
		return
	end
	local nodeSource = ActorManager.getCTNode(rSource)	
	if rRoll.sType == "effectbce" then
		local sEffect = ""
		local sEffectOriginal = ""
		for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
			sEffect = DB.getValue(nodeEffect, "label", "")
			if sEffect == rRoll.sEffect then
				sEffectOriginal = sEffect
				local nResult = tonumber(ActionsManager.total(rRoll))
				local sResult = tostring(nResult)
				local sValue = rRoll.sValue
				local sReverseValue = string.reverse(sValue)
				---Needed to get creative with patern matching - to correctly process
				-- if the negative is to total, or do we have a negative modifier
				if sValue:match("%+%d+") then
					sValue = sValue:gsub("%+%d+", "") .. "%+%d+"
				elseif  (sReverseValue:match("%d+%-") and rRoll.nMod ~= 0) then
					sReverseValue = sReverseValue:gsub("%d+%-", "", 1)
					sValue = "%-?" .. string.reverse(sReverseValue) .. "%-*%d?"
				elseif (sReverseValue:match("%d+%-") and rRoll.nMod == 0) then
					sValue = "%-*" .. sValue:gsub("%-", "")
				end
				sEffect = sEffect:gsub(sValue, sResult)
				DB.setValue(nodeEffect, "label", "string", sEffect)
				break
			end
		end
	elseif rRoll.sType == "savebce" then
		local nodeEffect = DB.findNode(rRoll.sEffectPath)
		if not nodeEffect then
			return
		end
		local sName = ActorManager.getDisplayName(nodeSource);		
		ActionSave.onSave(rTarget, rSource, rRoll) -- Reverse target/source because the target of the effect is making the save
		local nResult = ActionsManager.total(rRoll);
		if nResult >= tonumber(rRoll.nTarget) then
			if rRoll.sSaveType == "Save"  then
				if rRoll.bDisableOnSave then
					modifyEffect(nodeEffect, "Deactivate")
				else
					modifyEffect(nodeEffect, "Remove")
				end
			elseif rRoll.sSaveType == "SaveOngoing" and rRoll.sDesc:match( " %[HALF ON SAVE%]") then
				applyOngoingDamage(rSource, rTarget, nodeEffect)
				if rRoll.bDisableOnSave then
					modifyEffect(nodeEffect, "Deactivate")
				end
			end
		elseif rRoll.sSaveType == "SaveOngoing" then
			applyOngoingDamage(rSource, rTarget, nodeEffect)
		end
	end
end

function applyOngoingDamage(rSource, rTarget, nodeEffect)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local rAction = {}
	rAction.label =  ""
	rAction.clauses = {}
	for _,sEffectComp in ipairs(aEffectComps) do 
		local rEffectComp = RulesetEffectManager.parseEffectComp(sEffectComp)
		if rEffectComp.type == "SAVEDMG" then	
			local aClause = {}
			local rDmgInfo = RulesetEffectManager.parseEffectComp(rEffectComp.original)
			aClause.dice = rDmgInfo.dice;
			aClause.modifier = rDmgInfo.mod
			aClause.dmgtype = string.lower(table.concat(rDmgInfo.remainder, ","))
			table.insert(rAction.clauses, aClause)
		elseif rEffectComp.type == "" and rAction.label == "" then
			rAction.label = sEffectComp
		end
	end
	if rAction.label == "" then
		rAction.label = "Ongoing Effect"
	end
	if next(rAction.clauses) ~= nil then
		local rRoll = ActionDamage.getRoll(rTarget, rAction)
		ActionsManager.actionRoll(rSource, {{rTarget}}, {rRoll})
	end	
end

--Do sanity checks to see if we should process this effect any further
function processEffect(rSource, nodeEffect, sBCETag, rTarget, bIgnoreDeactive)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	if sEffect:match(sBCETag) == nil  then -- Does it contain BCE Tag
		return false
	end

	local nActive = DB.getValue(nodeEffect, "isactive", 0)
	--is it active
	if  ((nActive == 0 and bIgnoreDeactive == nil) or nActive == 2) then
		if nActive == 2 and Session.IsHost then -- Don't think we need to check if is host 
			DB.setValue(nodeEffect, "isactive", "number", 1);
		end
		return false
	end
	-- is there a conditional that prevents us from processing
	local aEffectComps = EffectManager.parseEffect(sEffect)
	for _,sEffectComp in ipairs(aEffectComps) do -- Check conditionals
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "IF" then
			if not RulesetEffectManager.checkConditional(rSource, nodeEffect, rEffectComp.remainder) then
				return false
			end
		elseif rEffectComp.type == "IFT" then
			if not RulesetEffectManager.checkConditional(rSource, nodeEffect, rEffectComp.remainder, rTarget) then
				return false
			end
		end
	end	
	return true -- Everything looks good to continue processing
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
			local sEffect = DB.getValue(nodeEffect, "label", "")
			if nodeCT == sourceNodeCT then
				if processEffect(rSource,nodeEffect,"TURNRS") and not sEffect:match("STURNRS") and (DB.getValue(nodeEffect, "duration", "") == 1) then
					modifyEffect(nodeEffect, "Remove")
					break
				end
				 if processEffect(rSource,nodeEffect,"TURNAS", nil, true) then
					modifyEffect(nodeEffect, "Activate")
				 end
				if processEffect(rSource,nodeEffect,"TURNDS") then
					sAction = "Deactivate"
					modifyEffect(nodeEffect, "Deactivate")
				end
				if processEffect(rSource,nodeEffect,"SAVES") then -- Check if something might be interesting
					saveEffect(nodeEffect, sourceNodeCT, "Save")
				end
				if processEffect(rSource,nodeEffect,"SAVEOS") then -- Check if something might be interesting
					saveEffect(nodeEffect, sourceNodeCT, "SaveOngoing")
				end
			else
				local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
				if sEffectSource ~= nil  and sSourceName == sEffectSource then
					if processEffect(rSource,nodeEffect,"STURNRS") and (DB.getValue(nodeEffect, "duration", "") == 1) then
						modifyEffect(nodeEffect, "Remove")
						break
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
			local sEffect = DB.getValue(nodeEffect, "label", "")
			local sAction = nil
			if nodeCT == sourceNodeCT then
				if processEffect(rSource,nodeEffect,"TURNRE") and not sEffect:match("STURNRE") and (DB.getValue(nodeEffect, "duration", "") == 1) then	
					modifyEffect(nodeEffect, "Remove")
					break
				end
				if processEffect(rSource,nodeEffect,"TURNAE", nil, true) then
					modifyEffect(nodeEffect, "Activate")
				end
				if processEffect(rSource,nodeEffect,"TURNDE") then
					sAction = "Deactivate"
				end
				if processEffect(rSource,nodeEffect,"SAVEE") then -- Check if something might be interesting
					saveEffect(nodeEffect, sourceNodeCT, "Save")
				end
				if processEffect(rSource,nodeEffect,"SAVEOE") then -- Check if something might be interesting
					saveEffect(nodeEffect, sourceNodeCT, "SaveOngoing")
				end
			else
				local sEffectSource = DB.getValue(nodeEffect, "source_name", "")
				if sEffectSource ~= nil  and sSourceName == sEffectSource then
					if processEffect(rSource,nodeEffect,"STURNRE")  and (DB.getValue(nodeEffect, "duration", "") == 1) then
						modifyEffect(nodeEffect, "Remove")
						break
					end
				end
			end
		end
	end
end

function customOnDamage(rSource, rTarget, rRoll)
	if not rTarget or not rSource or not rRoll  then
		return onDamage(rSource, rTarget, rRoll)
	end
	
	local nodeTarget = ActorManager.getCTNode(rTarget)
	local nodeSource = ActorManager.getCTNode(rSource)	
	-- save off temp hp and wounds before damage
	local nTempHPPrev, nWoundsPrev = getTempHPAndWounds(rTarget)

	-- Play nice with others
	-- Do damage first then modify any effects
	onDamage(rSource, rTarget, rRoll)

	-- get temp hp and wounds after damage
	local nTempHP, nWounds = getTempHPAndWounds(rTarget)
	
	if OptionsManager.isOption("TEMP_IS_DAMAGE", "on") then
		-- If no damage was applied then return
		if nWoundsPrev >= nWounds and nTempHPPrev <= nTempHP then
			return
		end
		else
			if nWoundsPrev >= nWounds then
				return
		end
	end
	-- Loop through effects on the target of the damage
	for _,nodeEffect in pairs(DB.getChildren(nodeTarget, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
	
		-- TODO --
		-- Add support for only trigger on specific damage types.
		if processEffect(rTarget,nodeEffect,"DMGRT", rSource) then	
			modifyEffect(nodeEffect, "Remove")
			break
		end
		if processEffect(rTarget,nodeEffect,"DMGAT", rSource, true) then
			modifyEffect(nodeEffect, "Activate")		
		end
		if processEffect(rTarget,nodeEffect,"DMGDT", rSource) then
			modifyEffect(nodeEffect, "Deactivate")
		end
		if sEffect:match("TDMGADDT") or sEffect:match("TDMGADDS") then
			local rEffect = matchEffect(sEffect)
			if rEffect.sName ~= nil then
				-- Set the node that applied the effect
				rEffect.sSource = ActorManager.getCTNodeName(rTarget)
				rEffect.nInit  = DB.getValue(nodeTarget, "initresult", 0)
				if processEffect(rSource,nodeEffect,"TDMGADDT", rTarget) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), rEffect, true)
				end
				if processEffect(rSource,nodeEffect,"TDMGADDS", rTarget) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rSource), rEffect, true)
				end
			end
		end
	end
	-- Loop though the effects on the source of the damage
	for _,nodeEffect in pairs(DB.getChildren(nodeSource, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		if sEffect:match("SDMGADDT") or sEffect:match("SDMGADDS") then
			local rEffect = matchEffect(sEffect)
			if rEffect.sName ~= nil then
				rEffect.sSource = ActorManager.getCTNodeName(sSource)
				rEffect.nInit  = DB.getValue(nodeSource, "initresult", 0)
				if processEffect(rTarget,nodeEffect,"SDMGADDT", rSource) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), rEffect, true)
				end
				if processEffect(rTarget,nodeEffect,"SDMGADDS", rSource) then
					EffectManager.addEffect("", "", ActorManager.getCTNode(rSource), rEffect, true)
				end
			end
		end
	end
end

function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return
	end
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return
	end

	local nDuration = rNewEffect.nDuration
	local rActor = ActorManager.resolveActor(nodeCT)
	
	-- The following should be done with a customOnEffectAddStart if the handlers worked properly
	if User.getRulesetName() == "5E" or User.getRulesetName() == "4E" or User.getRulesetName() == "3.5E" then
		if rNewEffect.sUnits == "minute" then
			nDuration = nDuration * 10
		elseif rNewEffect.sUnits == ("hour" or "day") then
			nDuration = 0
		end

		if rNewEffect.sSource ~= nil  and rNewEffect.sSource ~= "" then
			replaceSaveDC(rNewEffect, ActorManager.resolveActor(rNewEffect.sSource))
		else
			replaceSaveDC(rNewEffect, rActor)
		end
		replaceAbilityScores(rNewEffect, rActor)
		replaceAbilityModifier(rNewEffect, rActor)
		if OptionsManager.isOption("RESTRICT_CONCENTRATION", "on") then
			dropConcentration(rNewEffect, nDuration)
		end
	end
	if User.getRulesetName() == "5E" and sumExhaustion(rNewEffect, nodeEffectsList) then
		return
	end

	-- The custom effects handlers are dangerous because they set the function to the last extension/ruleset that calls it
	-- and therefore there is not really a good way to play nice with other extensions.
	-- The following should be done with a setCustomOnEffectAddIgnoreCheck if the handlers worked properly.
	-- CoreRPG ignores duplicate effects but if setCustomOnEffectAddIgnoreCheck is invoked, like by 5E ruleset, 
	-- the ignore duplicates is bypassed. 5E ignores immunities but never added the duplicate check back in
	-- We've added the STACK option to allow for duplicate effects if needed.
	-- 4E and 3.5E don't allow stack so this will enable it
	if OptionsManager.isOption("ALLOW_DUPLICATE_EFFECT", "off") then
		local sDuplicateMsg = nil
		if not rNewEffect.sName:match("STACK") then
			for k, nodeEffect in pairs(nodeEffectsList.getChildren()) do
				if rNewEffect.nInit == nil then
					rNewEffect.nInit = 0
				end
				if (DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) and
						(DB.getValue(nodeEffect, "init", 0) == rNewEffect.nInit) and
						(DB.getValue(nodeEffect, "duration", 0) == nDuration) and
						(DB.getValue(nodeEffect,"source_name", "") == rNewEffect.sSource) then
					sDuplicateMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_exists"))
					break
				end
			end
		end
		if sDuplicateMsg then
			EffectManager.message(sDuplicateMsg, nodeCT, false, sUser)
			return
		end
	end
	-- The following should be done with a customOnEffectAddStart if the handlers worked properly
	local rRoll = {}
	rRoll = isDie(rNewEffect.sName)
	if next(rRoll) ~= nil then
		rRoll.rActor = rActor
		if rNewEffect.nGMOnly  then
			rRoll.bSecret = true
		else
			rRoll.bSecret = false
		end
		performRoll(nil, rActor, rRoll)
	end

	-- Play nice with others
	addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)

	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		if (DB.getValue(nodeEffect, "label", "") == rNewEffect.sName) and
			(DB.getValue(nodeEffect, "init", 0) == rNewEffect.nInit) and
			(DB.getValue(nodeEffect, "duration", 0) == nDuration) and
			(DB.getValue(nodeEffect,"source_name", "") == rNewEffect.sSource) then

			local nodeSource = DB.findNode(rNewEffect.sSource)
			local rSource = ActorManager.resolveActor(nodeSource)
			local rTarget = rActor
			if processEffect(rSource, nodeEffect, "SAVEA", rTarget) then
				saveEffect(nodeEffect, nodeCT, "Save")
			end
			if processEffect(rSource, nodeEffect, "TURNRS", rTarget) and (User.getRulesetName() == "5E" or User.getRulesetName() == "4E" or User.getRulesetName() == "3.5E") then
				nDuration = DB.getValue(nodeEffect, "duration", 0)
				if nDuration > 0 then
					DB.setValue(nodeEffect, "duration", "number", nDuration + 1)
				end
			end
		end
	end
end

function replaceSaveDC(rNewEffect, rActor)
	if rNewEffect.sName:match("%[SDC]") and  
			(rNewEffect.sName:match("SAVEE") or 
			rNewEffect.sName:match("SAVES") or 
			rNewEffect.sName:match("SAVEOS") or 
			rNewEffect.sName:match("SAVEOE") or
			rNewEffect.sName:match("SAVEA")) then
		local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor)
		local nSpellcastingDC = 8; 
		if sNodeType == "pc" then
			nSpellcastingDC = nSpellcastingDC +  RulesetActorManager.getAbilityBonus(rActor, "prf");
			for _,nodeFeature in pairs(DB.getChildren(nodeActor, "featurelist")) do
				local sFeatureName = StringManager.trim(DB.getValue(nodeFeature, "name", ""):lower())
				if sFeatureName == "spellcasting" then
					local sDesc = DB.getValue(nodeFeature, "text", ""):lower();
					local sStat = sDesc:match("(%w+) is your spellcasting ability") or ""
					nSpellcastingDC = nSpellcastingDC + RulesetActorManager.getAbilityBonus(rActor, sStat) 
					break
				end
			end 			
		elseif sNodeType == "ct" then
			nSpellcastingDC = nSpellcastingDC+  RulesetActorManager.getAbilityBonus(rActor, "prf");
			for _,nodeTrait in pairs(DB.getChildren(nodeActor, "traits")) do
				local sTraitName = StringManager.trim(DB.getValue(nodeTrait, "name", ""):lower())
				if sTraitName == "spellcasting" then
					local sDesc = DB.getValue(nodeTrait, "desc", ""):lower();
					local sStat = sDesc:match("its spellcasting ability is (%w+)") or ""
					nSpellcastingDC = nSpellcastingDC + RulesetActorManager.getAbilityBonus(rActor, sStat)
					break
				end
			end
		end
		rNewEffect.sName = rNewEffect.sName:gsub("%[SDC]", tostring(nSpellcastingDC))	
	end
end

-- Any effect that modifies ability score and is coded with -X
-- has the -X replaced with the targets ability score and then calculated
function replaceAbilityScores(rNewEffect, rActor)
	-- check contains -X to see if this is interesting enough to continue
	if rNewEffect.sName:match("%-X") then
		local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
		for _,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = RulesetEffectManager.parseEffectComp(sEffectComp)
			local nAbility = 0

			if rEffectComp.type == "STR" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "STRMNM") then			
				nAbility = RulesetActorManager.getAbilityScore(rActor, "strength")
			elseif rEffectComp.type  == "DEX"  or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "DEXMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "dexterity")
			elseif rEffectComp.type  == "CON" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "CONMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "constitution")
			elseif rEffectComp.type  == "INT" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "INTMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "intelligence")
			elseif rEffectComp.type  == "WIS" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "WISMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "wisdom")
			elseif rEffectComp.type  == "CHA" or (bMadNomadCharSheetEffectDisplay and rEffectComp.type == "CHAMNM") then
				nAbility = RulesetActorManager.getAbilityScore(rActor, "charisma")
			end

			if(rEffectComp.remainder[1]:match("%-X")) then
				local sMod = rEffectComp.remainder[1]:gsub("%-X", "")
				local nMod = tonumber(sMod)
				if nMod ~= nil then
					if(nMod > nAbility) then
						nAbility = nMod - nAbility
					else
						nAbility = 0
					end
					--Exception for Mad Nomads effects display extension
					local sReplace = rEffectComp.type .. ":" ..tostring(nAbility)
					local sMatch =  rEffectComp.type ..":%s-%d+%-X"
					rNewEffect.sName = rNewEffect.sName:gsub(sMatch, sReplace)
				end
			end
		end
	end
end

function replaceAbilityModifier(rNewEffect, rActor)
	if rNewEffect.sName:match("%[STR]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[STR]", tostring(RulesetActorManager.getAbilityBonus(rActor, "strength")))
	elseif rNewEffect.sName:match("%[DEX]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[DEX]", tostring(RulesetActorManager.getAbilityBonus(rActor, "dexterity")))
	elseif rNewEffect.sName:match("%[CON]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[CON]", tostring(RulesetActorManager.getAbilityBonus(rActor, "constitution")))
	elseif rNewEffect.sName:match("%[WIS]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[WIS]", tostring(RulesetActorManager.getAbilityBonus(rActor, "wisdom")))
	elseif rNewEffect.sName:match("%[INT]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[INT]", tostring(RulesetActorManager.getAbilityBonus(rActor, "intelligence")))
	elseif rNewEffect.sName:match("%[CHA]") then
		rNewEffect.sName = rNewEffect.sName:gsub("%[CHA]", tostring(RulesetActorManager.getAbilityBonus(rActor, "charisma")))
	end
end

--5E Only -Check if added effect is EXHAUSTION and sums the exhaustion level with existing exhaustion
function sumExhaustion(rNewEffect, nodeEffectsList)
	local bSummed = nil
	if(rNewEffect.sName:match("EXHAUSTION")) then
		local exhaustionLevel = 0;
		local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
		for i,sEffectComp in ipairs(aEffectComps) do
			if sEffectComp == "EXHAUSTION" then
				sEffectComp = sEffectComp .. ": 1"
				aEffectComps[i] = sEffectComp
				rNewEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
			end
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type == "EXHAUSTION" then
				exhaustionLevel = tonumber(rEffectComp.mod)
			end
		end
		-- Adding exhaustion, do we have exhaustion to combine?
		if exhaustionLevel >= 1 then
			for k, nodeEffect in pairs(nodeEffectsList.getChildren()) do
				local sEffect = DB.getValue(nodeEffect, "label", "");
				if sEffect:match("EXHAUSTION") then
					local aEffectComps = EffectManager.parseEffect(sEffect)
					for i,sEffectComp in ipairs(aEffectComps) do
						local sActor = nodeEffect.getParent().getParent().getPath() -- Node this effect is on
						local rActor = ActorManager.resolveActor(DB.findNode(sActor))
						local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
						if rEffectComp.type == "EXHAUSTION" and rEffectComp.mod ~= nil and processEffect(rActor,nodeEffect,"EXHAUSTION") then
							rEffectComp.mod = tonumber(rEffectComp.mod) + exhaustionLevel
							aEffectComps[i] = rEffectComp.type .. ": " .. rEffectComp.mod							
							sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
							local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor)
							sEffect = exhaustionText(sEffect, nodeActor, rEffectComp.mod)
							modifyEffect(nodeEffect, "Update", sEffect)
							bSummed = true
							break
						end
					end					
				end	
			end	
		end
	end
	return bSummed
end

--Add extra text and also comptibility with Mad Nomads Character Sheet Effects Display
function exhaustionText(sEffect, nodeActor,  nLevel)
	local nSpeed = DB.getValue(nodeActor, "speed.base", 0)
	local nHPMax = DB.getValue(nodeActor, "hp.base", 0)
	local sSpeed = "; Speed-"
	local sHPMax = "; MAXHP: -"
	sEffect = sEffect:gsub(";%s?Speed%-?%+?%d+;?", "")
	sEffect = sEffect:gsub(";%s?MAXHP%:%s?%-?%+?%d+;?", "")

	if (nLevel == 2 or nLevel == 3) then
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2)) 
	elseif (nLevel == 4) then
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2)) 
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2)) 
	elseif (nLevel >= 5) then
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2))
		sEffect = sEffect .. sSpeed .. tostring(nSpeed)
	end
	return sEffect
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
		if rEffectComp.type == "SAVEE" or rEffectComp.type == "SAVES" or rEffectComp.type == "SAVEOE" or rEffectComp.type == "SAVEOS" or rEffectComp.type == "SAVEA" then
			local sAbility = DataCommon.ability_stol[rEffectComp.remainder[1]]
			local nDC = tonumber(rEffectComp.remainder[2])
			if  (nDC and sAbility) ~= nil then		
				local sNodeEffectSource  = DB.getValue(nodeEffect, "source_name", "")
				local rAction = {}
				if sLabel == "" then
					sLabel = "Ongoing Effect"
				end
				rAction.savemod = nDC
				rAction.save =  sAbility -- save ability
				rAction.label = sLabel--sEffect
				if rEffectComp.original:match("%(H%)") then
					rAction.onmissdamage =  "half"
				end
				rAction.magic =  rEffectComp.original:match("%(M%)")
				local rSaveVsRoll = ActionPower.getSaveVsRoll(nodeTarget, rAction)
				rSaveVsRoll.sSaveDesc = rSaveVsRoll.sDesc;
--				rSaveVsRoll.sDesc =  "[SAVE] " .. sAbility .. rSaveVsRoll.sDesc:gsub("%[SAVE VS%]", "") 
				if EffectManager.isGMEffect(sourceNodeCT, nodeEffect) or CombatManager.isCTHidden(sourceNodeCT) then
					rSaveVsRoll.bSecret = true
				end
				if rEffectComp.original:match("%(D%)") then
					rSaveVsRoll.bDisableOnSave = true
				end
				rSaveVsRoll.sType = "savebce"
				rSaveVsRoll.sSaveType = sSaveBCE
				rSaveVsRoll.nTarget = nDC -- Save DC
				rSaveVsRoll.sSource = sNodeEffectSource
				local rRoll = ActionSave.getRoll(nodeTarget,sAbility) -- call to get the modifiers
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
					modifyEffect(nodeEffect, "Remove", sEffect)
				end
			end
		end
	end
end

function isDie(sEffect)
	local rRoll = {}
	local aEffectComps = EffectManager.parseEffect(sEffect)
	local nMatch = 0
	for kEffectComp,sEffectComp in ipairs(aEffectComps) do
		local aWords = StringManager.parseWords(sEffectComp, "%.%[%]%(%):")
		local bNegative = 0
		if #aWords > 0 then
			sType = aWords[1]:match("^([^:]+):")
			-- Only roll dice for ability score mods
			if sType and (sType == "STR" or sType == "DEX" or sType == "CON" or sType == "INT" or sType == "WIS" or sType == "CHA") then
				local nRemainderIndex = 2

				local sValueCheck = ""
				local sTypeRemainder = aWords[1]:sub(#sType + 2)
				if sTypeRemainder == "" then
					sValueCheck = aWords[2] or ""
					nRemainderIndex = nRemainderIndex + 1
				else
					sValueCheck = sTypeRemainder
				end
				-- Check to see if negative
				if sValueCheck:match("%-^[d%.%dF%+%-]+$") then
					sValueCheck = sValueCheck:gsub("%-", "", 1)
				end
				if StringManager.isDiceString(sValueCheck) then		
					local aDice, nMod = StringManager.convertStringToDice(sValueCheck)
					rRoll.sType = "effectbce"
					rRoll.sDesc = "[EFFECT " .. sEffect .. "] "
					rRoll.aDice = aDice
					rRoll.nMod = nMod
					rRoll.sEffect = sEffect
					rRoll.sValue = sValueCheck
				end
			end
		end
	end
	return rRoll
end

function getTempHPAndWounds(rTarget)
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget)
	if not nodeTarget then
		return 0,0
	end

	local nTempHP = 0
	local nWounds = 0

	if sTargetNodeType == "pc" then
		nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0)
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
	elseif sTargetNodeType == "ct" then
		nTempHP = DB.getValue(nodeTarget, "hptemp", 0)
		nWounds = DB.getValue(nodeTarget, "wounds", 0)
	end
	return nTempHP, nWounds
end

function matchEffect(sEffect)
	local rEffect = {}
	local sEffectLookup = ""
	local aEffectComps = EffectManager.parseEffect(sEffect)
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)

		-- Parse out individual componets 
		if rEffectComp.type == "TDMGADDT" or rEffectComp.type == "TDMGADDS" or rEffectComp.type == "SDMGADDT" or rEffectComp.type == "SDMGADDS" then	
			local aEffectLookup = rEffectComp.remainder
			sEffectLookup = EffectManager.rebuildParsedEffect(aEffectLookup)
			sEffectLookup = sEffectLookup:gsub("%;", "")
		end	
	end
	--Find the effect name in our custom effects list
	for _,v in pairs(DB.getChildrenGlobal("effects")) do
		local sEffect = DB.getValue(v, "label", "")
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
			
			if User.getRulesetName() == "5E" then
				local nodeUnits = DB.getChild(v, "unit")
				if nodeUnits then
					rEffect.sUnits = nodeUnits.getValue()
				end
			end
			rEffect.sName = sEffect
			break
		end
	end
	return rEffect
end

-- Needed for ongoing save. Have to flip source/target to get the correct mods
function onModSaveHandler(rSource, rTarget, rRoll)
	ActionSave.modSave(rTarget, rSource, rRoll);
end

function modifyEffect(nodeEffect, sAction, sEffect)
	local nActive = DB.getValue(nodeEffect, "isactive", 0)
	-- Activate turn start/end/damage taken
	if sAction == "Activate" then
		if nActive == 1 then
			return
		else
			sendOOB(nodeEffect, OOB_MSGTYPE_BCEACTIVATE)
		end
	end
	-- Deactivate turn start/end/damage taken
	if sAction == "Deactivate" then
		if nActive == 0 then
			return
		else
			sendOOB(nodeEffect, OOB_MSGTYPE_BCEDEACTIVATE)
		end
	end
	-- Remove turn start/end/damage taken
	if sAction == "Remove" then
		sendOOB(nodeEffect, OOB_MSGTYPE_BCEREMOVE)
	end
	-- Update the effect string to something different
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
	
	DB.setValue(nodeEffect, "isactive", "number", 1)

	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_activated"))
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

function updateEffect(nodeActor, nodeEffect, sLabel)
	if not nodeEffect then
		return false
	end
	DB.setValue(nodeEffect, "label", "string", sLabel)
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sLabel, Interface.getString("effect_status_updated"))
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

function handleActivateEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor)

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")")
		return
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectapplyfail") .. " (" .. msgOOB.sNodeEffect .. ")")
		return
	end
	activateEffect(nodeActor, nodeEffect)
end

function handleDeactivateEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor)

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")")
		return
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sNodeEffect .. ")")
		return
	end
	EffectManager.deactivateEffect(nodeActor, nodeEffect)
end

function handleRemoveEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor)

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")")
		return
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sNodeEffect .. ")")
		return
	end
	EffectManager.expireEffect(nodeActor, nodeEffect, 0)
end

function handleUpdateEffect(msgOOB)
	local nodeActor = DB.findNode(msgOOB.sNodeActor)

	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sNodeActor .. ")")
		return
	end

	local nodeEffect = DB.findNode(msgOOB.sNodeEffect)
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sNodeEffect .. ")")
		return
	end
	updateEffect(nodeActor, nodeEffect, msgOOB.sLabel)
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

function onInit()
	OptionsManager.registerOption2("ALLOW_DUPLICATE_EFFECT", false, "option_Better_Combat_Effects", 
	"option_Allow_Duplicate", "option_entry_cycler", 
	{ labels = "option_val_on", values = "on",
	  baselabel = "option_val_off", baseval = "off", default = "off" })

	OptionsManager.registerOption2("TEMP_IS_DAMAGE", false, "option_Better_Combat_Effects", 
	"option_Temp_Is_Damage", "option_entry_cycler", 
	{ labels = "option_val_on", values = "on",
		baselabel = "option_val_off", baseval = "off", default = "off" })  
	
	if User.getRulesetName() == "5E" then 
		OptionsManager.registerOption2("RESTRICT_CONCENTRATION", false, "option_Better_Combat_Effects", 
		"option_Concentrate_Restrict", "option_entry_cycler", 
		{ labels = "option_val_on", values = "on",
			baselabel = "option_val_off", baseval = "off", default = "off" })  
	
		RulesetActorManager = ActorManager5E
		RulesetEffectManager = EffectManager5E
	end
	if User.getRulesetName() == "4E" then
		RulesetActorManager = ActorManager4E
		RulesetEffectManager = EffectManager4E
	end
	if User.getRulesetName() == "35E" then
		RulesetActorManager = ActorManager35E
		RulesetEffectManager = EffectManager35E
	end

	if User.getRulesetName() == "5E" or User.getRulesetName() == "4E" or User.getRulesetName() == "3.5E" then
		rest = CombatManager2.rest
		CombatManager2.rest = customRest
	end
	-- save off the originals so we play nice with others
	onDamage = ActionDamage.onDamage
	addEffect = EffectManager.addEffect

	ActionDamage.onDamage = customOnDamage
	EffectManager.addEffect = customAddEffect

	ActionsManager.registerResultHandler("damage", customOnDamage)
	ActionsManager.registerResultHandler("effectbce", onEffectRollHandler)
	ActionsManager.registerResultHandler("savebce", onEffectRollHandler)
	ActionsManager.registerModHandler("savebce", onModSaveHandler)

	CombatManager.setCustomTurnStart(customTurnStart)
	CombatManager.setCustomTurnEnd(customTurnEnd)
	CombatManager.setCustomRoundStart(customRoundStart)
	
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEACTIVATE, handleActivateEffect)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEDEACTIVATE, handleDeactivateEffect)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEREMOVE, handleRemoveEffect)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEUPDATE, handleUpdateEffect)

	aExtensions = Extension.getExtensions()
	for _,sExtension in ipairs(aExtensions) do
		tExtension = Extension.getExtensionInfo(sExtension)
		if (tExtension.name == "MNM Charsheet Effects Display") then
			bMadNomadCharSheetEffectDisplay = true
		end
	end
end

function onClose()
	ActionDamage.onDamage = onDamage
	EffectManager.addEffect = addEffect
	if User.getRulesetName() == "5E" or User.getRulesetName() == "4E" or User.getRulesetName() == "3.5E" then
		CombatManager2.rest = rest
	end

	ActionsManager.unregisterResultHandler("damage")
	ActionsManager.unregisterResultHandler("effectbce")
	ActionsManager.unregisterResultHandler("savebce")
	ActionsManager.unregisterModHandler("savebce")
end