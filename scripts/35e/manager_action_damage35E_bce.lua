--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local applyDamageOriginal = nil;

function onInit()
    applyDamageOriginal = ActionDamage.applyDamage;
    ActionDamage.applyDamage = customApplyDamage;
end

function onClose()
    ActionDamage.applyDamage = applyDamageOriginal;
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
