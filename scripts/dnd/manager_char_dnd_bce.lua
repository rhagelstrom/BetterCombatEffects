--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
-- luacheck: globals CharManagerDnDBCE
local rest = nil;
local RulesetEffectManager = nil;

function onInit()
    RulesetEffectManager = BCEManager.getRulesetEffectManager();

    rest = CharManager.rest
    CharManager.rest = customRest
end

function onClose()
    CharManager.rest = rest;
end

function customRest(nodeActor, bLong, bMilestone)
    BCEManager.chat('customRest : ');
    local rSource = ActorManager.resolveActor(nodeActor);

    local aTags = {'RESTS'};
    if bLong == true then
        table.insert(aTags, 'RESTL');
    end
    for _, sTag in pairs(aTags) do
        local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag);
        for _, tEffect in pairs(tMatch) do
            BCEManager.chat(sTag .. '  : ');
            BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
        end
    end
    rest(nodeActor, bLong, bMilestone);
end
