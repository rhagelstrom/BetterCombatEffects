--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals CombatManager235EBCE  CharManagerDnDBCE BCEManager
-- luacheck: globals onInit onClose customRest

local rest = nil;

function onInit()
    rest = CombatManager2.rest;
    CombatManager2.rest = customRest;

end

function onClose()
    CombatManager2.rest = rest;
end

function customRest(bShort)
    rest(bShort);

    if not bShort then
		for _,v in pairs(CombatManager.getCombatantNodes()) do
			local sClass, sRecord = DB.getValue(v, "link", "", "");
			if sClass == "charsheet" and sRecord ~= "" then
				local nodePC = DB.findNode(sRecord);
				if nodePC then
                    CharManagerDnDBCE.customRest(nodePC, true);
				end
			end
		end
	end
end
