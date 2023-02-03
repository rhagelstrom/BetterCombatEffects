--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local applyDamageOriginal = nil;
local notifyApplyDamage = nil;
local bAdvancedEffects = nil;

function onInit()
    applyDamageOriginal = ActionDamage.applyDamage;
    ActionDamage.applyDamage = customApplyDamage;
    bAdvancedEffects = BCEManager.hasExtension("FG-PFRPG-Advanced-Effects");
    if bAdvancedEffects then
        OOBManager.registerOOBMsgHandler(ActionDamage.OOB_MSGTYPE_APPLYDMG, handleApplyDamage);
        notifyApplyDamage = ActionDamage.notifyApplyDamage;
        ActionDamage.notifyApplyDamage = customNotifyApplyDamage;
    end
end

function onClose()
    ActionDamage.applyDamage = applyDamageOriginal;
    if bAdvancedEffects then
        ActionDamage.notifyApplyDamage = notifyApplyDamage;
    end
end

function customApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)
    local rRoll = {};
    rRoll.sType = sRollType;
    rRoll.sDesc = sDamage;
    rRoll.nTotal = nTotal;
    rRoll.bSecret = bSecret;
    ActionDamageDnDBCE.applyDamageBCE(rSource, rTarget, rRoll, ...);
end

function applyDamage(rSource, rTarget, rRoll, ...)
    applyDamageOriginal(rSource, rTarget, rRoll.bSecret, rRoll.sType, rRoll.sDesc, rRoll.nTotal, ...);
end

function handleApplyDamage(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	if rTarget then
		rTarget.nOrder = msgOOB.nTargetOrder;
	end

    rSource.nodeItem = msgOOB.nodeItem;
    rSource.nodeAmmo = msgOOB.nodeAmmo;
    rSource.nodeWeapon = msgOOB.nodeWeapon;

	local nTotal = tonumber(msgOOB.nTotal) or 0;
	ActionDamage.applyDamage(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), msgOOB.sRollType, msgOOB.sDamage, nTotal);
end

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
	msgOOB.sRollType = sRollType;
	msgOOB.nTotal = nTotal;
	msgOOB.sDamage = sDesc;
    msgOOB.nodeItem = rSource.nodeItem;
    msgOOB.nodeAmmo = rSource.nodeAmmo;
    msgOOB.nodeWeapon = rSource.nodeWeapon;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	msgOOB.nTargetOrder = rTarget.nOrder;

	Comm.deliverOOBMessage(msgOOB, "");
end