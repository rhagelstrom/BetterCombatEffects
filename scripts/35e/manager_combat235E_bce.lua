--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
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
	else
		rest(bShort);
	end
end
