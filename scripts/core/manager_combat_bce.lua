--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals CombatManagerBCE BCEManager EffectManagerBCE MigrationManagerBCE
-- luacheck: globals onInit onTabletopInit turnStart turnEnd
-- luacheck: globals setCustomProcessTurnStart removeCustomProcessTurnStart onCustomProcessTurnStart
-- luacheck: globals setCustomProcessTurnEnd removeCustomProcessTurnEnd onCustomProcessTurnEnd RulesetEffectManager
------------------ CUSTOM BCE FUNTION HOOKS ------------------
local aCustomProcessTurnStartHandlers = {};
local aCustomProcessTurnEndHandlers = {};
------------------ END CUSTOM BCE FUNTION HOOKS ------------------

RulesetEffectManager = nil;

function onInit()
    if Session.IsHost then
        CombatManager.setCustomTurnStart(turnStart);
        CombatManager.setCustomTurnEnd(turnEnd);
    end
end

function onTabletopInit()
    RulesetEffectManager = BCEManager.getRulesetEffectManager();
    EffectManagerBCE.registerEffectCompType('TURNAS', {bIgnoreDisabledCheck = true});
    EffectManagerBCE.registerEffectCompType('TURNAE', {bIgnoreDisabledCheck = true});
    EffectManagerBCE.registerEffectCompType('TURNRS', {bIgnoreDisabledCheck = true});
    EffectManagerBCE.registerEffectCompType('TURNRE', {bIgnoreDisabledCheck = true});
end

function turnStart(sourceNodeCT)
    BCEManager.chat('Turn Start: ', sourceNodeCT);
    if not sourceNodeCT then
        return;
    end
    EffectManagerBCE.changeState(sourceNodeCT, true);

    local rSource = ActorManager.resolveActor(sourceNodeCT);

    if OptionsManager.isOption('DEPRECATE_CHANGE_STATE', 'on') then
        onCustomProcessTurnStart(rSource);
    else
        local ctEntries = CombatManager.getCombatantNodes();
        if not onCustomProcessTurnStart(rSource) then
            local aTags = {'TURNAS', 'TURNDS', 'TURNRS'};
            for _, sTag in pairs(aTags) do
                local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag);
                for _, tEffect in pairs(tMatch) do
                    if sTag == 'TURNAS' then
                        BCEManager.chat('ACTIVATE: ');
                        BCEManager.modifyEffect(tEffect.sEffectNode, 'Activate');
                    elseif sTag == 'TURNDS' then
                        BCEManager.chat('DEACTIVATE: ');
                        BCEManager.modifyEffect(tEffect.sEffectNode, 'Deactivate');
                    elseif sTag == 'TURNRS' then
                        BCEManager.chat('REMOVE: ');
                        local nDuration = DB.getValue(tEffect.sEffectNode .. '.duration', 0);
                        if nDuration == 1 then
                            BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
                        end
                    end
                    MigrationManagerBCE.deprecateTagMsg(sTag);
                end
            end
        end

        for _, nodeCT in pairs(ctEntries) do
            local rActor = ActorManager.resolveActor(nodeCT);
            if rActor.sCTNode ~= rSource.sCTNode then
                local tMatch = RulesetEffectManager.getEffectsByType(rActor, 'STURNRS');
                for _, tEffect in pairs(tMatch) do
                    BCEManager.chat('REMOVE: ');
                    local nDuration = DB.getValue(tEffect.sEffectNode .. '.duration', 0);
                    local sSource = DB.getValue(tEffect.sEffectNode .. '.source_name', 0);
                    if nDuration == 1 and sSource == DB.getPath(sourceNodeCT) then
                        BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
                    end
                    MigrationManagerBCE.deprecateTagMsg('STURNRS');
                end
            end
        end
    end
end

function turnEnd(sourceNodeCT)
    BCEManager.chat('Turn End: ', sourceNodeCT);

    if not sourceNodeCT then
        return;
    end

    local rSource = ActorManager.resolveActor(sourceNodeCT);
    if OptionsManager.isOption('DEPRECATE_CHANGE_STATE', 'on') then
        onCustomProcessTurnEnd(rSource)
    else
        local ctEntries = CombatManager.getCombatantNodes();
        if not onCustomProcessTurnEnd(rSource) then
            local aTags = {'TURNAE', 'TURNDE', 'TURNRE'};
            for _, sTag in pairs(aTags) do
                local tMatch = RulesetEffectManager.getEffectsByType(rSource, sTag);
                for _, tEffect in pairs(tMatch) do
                    if sTag == 'TURNAE' then
                        BCEManager.chat('ACTIVATE: ');
                        BCEManager.modifyEffect(tEffect.sEffectNode, 'Activate');
                    elseif sTag == 'TURNDE' then
                        BCEManager.chat('DEACTIVATE: ');
                        BCEManager.modifyEffect(tEffect.sEffectNode, 'Deactivate');
                    elseif sTag == 'TURNRE' then
                        BCEManager.chat('REMOVE: ');
                        local nDuration = DB.getValue(tEffect.sEffectNode .. '.duration', 0);
                        if nDuration == 1 then
                            BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
                        end
                    end
                    MigrationManagerBCE.deprecateTagMsg(sTag);
                end
            end

            for _, nodeCT in pairs(ctEntries) do
                local rActor = ActorManager.resolveActor(nodeCT);
                if rActor.sCTNode ~= rSource.sCTNode then
                    local tMatch = RulesetEffectManager.getEffectsByType(rActor, 'STURNRE');
                    for _, tEffect in pairs(tMatch) do
                        BCEManager.chat('REMOVE: ');
                        local nDuration = DB.getValue(tEffect.sEffectNode .. '.duration', 0);
                        local sSource = DB.getValue(tEffect.sEffectNode .. '.source_name', 0);
                        if nDuration == 1 and sSource == DB.getPath(sourceNodeCT) then

                            BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
                        end
                        MigrationManagerBCE.deprecateTagMsg('STURNRE');
                    end
                end
            end
        end
    end
    EffectManagerBCE.changeState(sourceNodeCT, false);
end

------------------ CUSTOM BCE FUNTION HOOKS ------------------
function setCustomProcessTurnStart(f)
    table.insert(aCustomProcessTurnStartHandlers, f);
end

function removeCustomProcessTurnStart(f)
    for kCustomProcess, fCustomProcess in ipairs(aCustomProcessTurnStartHandlers) do
        if fCustomProcess == f then
            table.remove(aCustomProcessTurnStartHandlers, kCustomProcess);
            return false; -- success
        end
    end
    return true;
end

function onCustomProcessTurnStart(rSource)
    for _, fCustomProcess in ipairs(aCustomProcessTurnStartHandlers) do
        if fCustomProcess(rSource) == true then
            return true;
        end
    end
    return false; -- success
end

function setCustomProcessTurnEnd(f)
    table.insert(aCustomProcessTurnEndHandlers, f);
end

function removeCustomProcessTurnEnd(f)
    for kCustomProcess, fCustomProcess in ipairs(aCustomProcessTurnEndHandlers) do
        if fCustomProcess == f then
            table.remove(aCustomProcessTurnEndHandlers, kCustomProcess);
            return false; -- success
        end
    end
    return true;
end

function onCustomProcessTurnEnd(rSource)
    for _, fCustomProcess in ipairs(aCustomProcessTurnEndHandlers) do
        if fCustomProcess(rSource) == true then
            return true;
        end
    end
    return false; -- success
end
------------------ END CUSTOM BCE FUNTION HOOKS ------------------
