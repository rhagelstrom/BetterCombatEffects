--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
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
