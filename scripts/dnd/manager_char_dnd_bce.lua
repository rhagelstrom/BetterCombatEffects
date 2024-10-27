--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
--
-- luacheck: globals CharManagerDnDBCE BCEManager
-- luacheck: globals onInit onClose customRest
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
    if bLong == true or User.getRulesetName() == 'SFRPG' then
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
