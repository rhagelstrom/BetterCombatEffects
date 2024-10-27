--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
--
-- luacheck: globals PowerActionManagerCoreDnDBCE BCEManager
-- luacheck: globals onInit onClose customGetActionEffectText
local getActionEffectText = nil;

function onInit()
    getActionEffectText = PowerActionManagerCore.getActionEffectText;
    PowerActionManagerCore.getActionEffectText = customGetActionEffectText;
end

function onClose()
    PowerActionManagerCore.getActionEffectText = getActionEffectText;
end

function customGetActionEffectText(node, tData)
    local sReturn = getActionEffectText(node, tData);
    if not (tData and tData.sSubRoll == 'duration') then
        local sLabel = DB.getValue(node, 'label', '');

        if sLabel ~= '' then
            local sApply = DB.getValue(node, 'apply', '');
            if sApply == 'duse' then
                sReturn = sReturn .. '; [DUSE]';
            end
        end
        local sChangeState = DB.getValue(node, 'changestate', '');
        if sChangeState ~= '' then
            sReturn = sReturn .. '; [' .. sChangeState:upper() .. ']';
        end
    end
    return sReturn;
end
