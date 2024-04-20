--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2024
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals PowerManager5EBCE BCEManager ActionSaveDnDBCE
-- luacheck: globals onInit onClose customEvalAction customGetPCPowerAction moddedParseEffects getTurnModifier
local parseEffects = nil;
local evalAction = nil;
local getPCPowerAction = nil;

function onInit()
    evalAction = PowerManager.evalAction;
    parseEffects = PowerManager.parseEffects;
    getPCPowerAction = PowerManager.getPCPowerAction;

    PowerManager.evalAction = customEvalAction;
    PowerManager.parseEffects = moddedParseEffects;
    PowerManager.getPCPowerAction = customGetPCPowerAction;
end

function onClose()
    PowerManager.evalAction = evalAction;
    PowerManager.parseEffects = parseEffects;
    PowerManager.getPCPowerAction = getPCPowerAction;
end

-- Replace SDC when applied from a power
function customEvalAction(rActor, nodePower, rAction)
    BCEManager.chat('customEvalAction : ');
    if rAction.type == 'effect' and (rAction.sName:match('%[SDC]') or rAction.sName:match('%(SDC%)')) then
        local aNodeActionChild = DB.getChildList(DB.getChild(nodePower, 'actions'));
        local rSave = {saveMod = 0, saveBase = 'group', saveStat = '', saveProf = 0};
        local nDC = 0;
        local tMatch = EffectManager5E.getEffectsByType(rActor, 'SDC');
        local nSDCBonus = 0;
        for _, tEffect in pairs(tMatch) do
            nSDCBonus = nSDCBonus + tEffect.mod;
        end
        for _, nodeChild in pairs(aNodeActionChild) do
            local sSaveType = DB.getValue(nodeChild, 'type', '');
            if sSaveType == 'cast' then
                rSave.saveMod = DB.getValue(nodeChild, 'savedcmod', 0);
                rSave.saveBase = DB.getValue(nodeChild, 'savedcbase', 'group');
                if rSave.saveBase == '' then
                    rSave.saveBase = 'group';
                end
                if rSave.saveBase == 'ability' then
                    rSave.saveStat = DB.getValue(nodeChild, 'savedcstat', '');
                    rSave.saveProf = DB.getValue(nodeChild, 'savedcprof', 1);
                end
                break
            end
        end
        if rSave.saveBase == 'group' then
            local aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower);
            if aPowerGroup and aPowerGroup.sSaveDCStat then
                nDC =
                    8 + aPowerGroup.nSaveDCMod + ActorManager5E.getAbilityBonus(rActor, aPowerGroup.sSaveDCStat) + rSave.saveMod +
                        nSDCBonus;
                if aPowerGroup.nSaveDCProf == 1 then
                    nDC = nDC + ActorManager5E.getAbilityBonus(rActor, 'prf');
                end
            end
        elseif rSave.saveBase == 'fixed' then
            nDC = rSave.saveMod + nSDCBonus;
        elseif rSave.saveBase == 'ability' then
            nDC = 8 + rSave.saveMod + ActorManager5E.getAbilityBonus(rActor, rSave.saveStat) + nSDCBonus;
            if rSave.saveProf == 1 then
                nDC = nDC + ActorManager5E.getAbilityBonus(rActor, 'prf');
            end
        else
            rAction = ActionSaveDnDBCE.replaceSaveDC(rAction, rActor);
        end
        rAction.sName = rAction.sName:gsub('%[SDC]', tostring(nDC));
        rAction.sName = rAction.sName:gsub('%(SDC%)', tostring(nDC));
    elseif rAction.type == 'effect' then
        rAction = ActionSaveDnDBCE.replaceSaveDC(rAction, rActor);
    end

    evalAction(rActor, nodePower, rAction);
end

function customGetPCPowerAction(nodeAction, sSubRoll)
    BCEManager.chat('customGetPCPowerAction : ');
    local rAction, rActor = getPCPowerAction(nodeAction, sSubRoll);
    if rAction and rAction.type == 'effect' then
        rAction.sChangeState = DB.getValue(nodeAction, 'changestate', '');
    end
    return rAction, rActor;
end

-- luacheck: push ignore 561
function moddedParseEffects(sPowerName, aWords)
    if OptionsManager.isOption('AUTOPARSE_EFFECTS', 'off') then
        return parseEffects(sPowerName, aWords)
    end
    local effects = {};
    local rCurrent = nil;
    local rPrevious = nil;
    local i = 1;
    local bStart = false;
    local bSource = false;
    while aWords[i] do
        if StringManager.isWord(aWords[i], 'damage') then
            i, rCurrent = PowerManager.parseDamagePhrase(aWords, i);
            if rCurrent then
                if StringManager.isWord(aWords[i + 1], 'at') and StringManager.isWord(aWords[i + 2], 'the') and
                    StringManager.isWord(aWords[i + 3], {'start', 'end'}) and StringManager.isWord(aWords[i + 4], 'of') then
                    if StringManager.isWord(aWords[i + 3], 'start') then
                        bStart = true;
                    end
                    local nTrigger = i + 4;
                    if StringManager.isWord(aWords[nTrigger + 1], 'each') and StringManager.isWord(aWords[nTrigger + 2], 'of') then
                        if StringManager.isWord(aWords[nTrigger + 3], 'its') then
                            nTrigger = nTrigger + 3;
                        else
                            nTrigger = nTrigger + 4;
                            bSource = true;
                        end
                    elseif StringManager.isWord(aWords[nTrigger + 1], 'its') then
                        nTrigger = i;
                    elseif StringManager.isWord(aWords[nTrigger + 1], 'your') then
                        nTrigger = nTrigger + 1;
                    end
                    if StringManager.isWord(aWords[nTrigger + 1], {'turn', 'turns'}) then
                        nTrigger = nTrigger + 1;
                    end
                    rCurrent.endindex = nTrigger;

                    if StringManager.isWord(aWords[rCurrent.startindex - 1], 'takes') and
                        StringManager.isWord(aWords[rCurrent.startindex - 2], 'and') and
                        StringManager.isWord(aWords[rCurrent.startindex - 3], DataCommon.conditions) then
                        rCurrent.startindex = rCurrent.startindex - 2;
                    end

                    local aName = {};
                    for _, v in ipairs(rCurrent.clauses) do
                        local sDmg = StringManager.convertDiceToString(v.dice, v.modifier);
                        if v.dmgtype and v.dmgtype ~= '' then
                            sDmg = sDmg .. ' ' .. v.dmgtype;
                        end
                        if bStart == true and bSource == false then
                            table.insert(aName, 'DMGO: ' .. sDmg);
                        elseif bStart == false and bSource == false then
                            table.insert(aName, 'DMGOE: ' .. sDmg);
                        elseif bStart == true and bSource == true then
                            table.insert(aName, 'SDMGOS: ' .. sDmg);
                        elseif bStart == false and bSource == true then
                            table.insert(aName, 'SDMGOE: ' .. sDmg);
                        end
                    end
                    rCurrent.clauses = nil;
                    rCurrent.sName = table.concat(aName, '; ');
                    rPrevious = rCurrent;
                elseif StringManager.isWord(aWords[rCurrent.startindex - 1], 'extra') then
                    rCurrent.startindex = rCurrent.startindex - 1;
                    rCurrent.sTargeting = 'self';
                    rCurrent.sApply = 'roll';

                    local aName = {};
                    for _, v in ipairs(rCurrent.clauses) do
                        local sDmg = StringManager.convertDiceToString(v.dice, v.modifier);
                        if v.dmgtype and v.dmgtype ~= '' then
                            sDmg = sDmg .. ' ' .. v.dmgtype;
                        end
                        table.insert(aName, 'DMG: ' .. sDmg);
                    end
                    rCurrent.clauses = nil;
                    rCurrent.sName = table.concat(aName, '; ');
                    rPrevious = rCurrent;
                else
                    rCurrent = nil;
                end
            end
            -- Handle ongoing saves
        elseif StringManager.isWord(aWords[i], 'repeat') and StringManager.isWord(aWords[i + 2], 'saving') and
            StringManager.isWord(aWords[i + 3], 'throw') then
            local tSaves = PowerManager.parseSaves(sPowerName, aWords, false, false);
            local aSave = tSaves[#tSaves];
            if not aSave then
                break
            end
            if not aSave.savemod then
                aSave.savemod = 0;
            end
            local j = i + 3;
            local bStartTurn = false;
            local bEndSuccess = false;
            local aName = {};
            local sClause;

            while aWords[j] do
                if StringManager.isWord(aWords[j], 'start') then
                    bStartTurn = true;
                end
                if StringManager.isWord(aWords[j], 'ending') then
                    bEndSuccess = true;
                end
                j = j + 1;
            end
            if bStartTurn == true then
                sClause = 'SAVES:';
            else
                sClause = 'SAVEE:';
            end

            sClause = sClause .. ' ' .. tostring(aSave.savemod);
            sClause = sClause .. ' ' .. DataCommon.ability_ltos[aSave.save];

            if bEndSuccess == true then
                sClause = sClause .. ' (R)';
            end

            table.insert(aName, aSave.label);
            if rPrevious then
                table.insert(aName, rPrevious.sName);
            end
            table.insert(aName, sClause);
            rCurrent = {};
            rCurrent.startindex = i;
            rCurrent.endindex = i + 3;
            rCurrent.sName = table.concat(aName, '; ');
        elseif (i > 1) and StringManager.isWord(aWords[i], DataCommon.conditions) then
            local bValidCondition = false;
            local nConditionStart = i;
            local j = i - 1;
            -- local sTurnModifier = PowerManager5EBCE.getTurnModifier(aWords, i);
            while aWords[j] do
                if StringManager.isWord(aWords[j], 'be') then
                    if StringManager.isWord(aWords[j - 1], 'or') then
                        bValidCondition = true;
                        nConditionStart = j;
                        break
                    end

                elseif StringManager.isWord(aWords[j], 'being') and StringManager.isWord(aWords[j - 1], 'against') then
                    bValidCondition = true;
                    nConditionStart = j;
                    break

                    -- elseif StringManager.isWord(aWords[j], { "also", "magically" }) then

                    -- Special handling: Blindness/Deafness
                elseif StringManager.isWord(aWords[j], 'or') and StringManager.isWord(aWords[j - 1], DataCommon.conditions) and
                    StringManager.isWord(aWords[j - 2], 'either') and StringManager.isWord(aWords[j - 3], 'is') then
                    bValidCondition = true;
                    break

                elseif StringManager.isWord(aWords[j], {'while', 'when', 'cannot', 'not', 'if', 'be', 'or'}) then
                    bValidCondition = false;
                    break

                elseif StringManager.isWord(aWords[j], {'target', 'creature', 'it'}) then
                    if StringManager.isWord(aWords[j - 1], 'the') then
                        j = j - 1;
                    end
                    nConditionStart = j;

                elseif StringManager.isWord(aWords[j], 'and') then
                    if #effects == 0 then
                        break
                    elseif effects[#effects].endindex ~= j - 1 then
                        if not StringManager.isWord(aWords[i], 'unconscious') and
                            not StringManager.isWord(aWords[j - 1], 'minutes') then
                            break
                        end
                    end
                    bValidCondition = true;
                    nConditionStart = j;

                elseif StringManager.isWord(aWords[j], 'is') then
                    if bValidCondition or StringManager.isWord(aWords[i], 'prone') or
                        (StringManager.isWord(aWords[i], 'invisible') and
                            StringManager.isWord(aWords[j - 1], {'wearing', 'wears', 'carrying', 'carries'})) then
                        break
                    end
                    bValidCondition = true;
                    nConditionStart = j;

                elseif StringManager.isWord(aWords[j], DataCommon.conditions) then
                    break

                elseif StringManager.isWord(aWords[i], 'poisoned') then
                    if (StringManager.isWord(aWords[j], 'instead') and StringManager.isWord(aWords[j - 1], 'is')) then
                        bValidCondition = true;
                        nConditionStart = j - 1;
                        break
                    elseif StringManager.isWord(aWords[j], 'become') then
                        bValidCondition = true;
                        nConditionStart = j;
                        break
                    end

                elseif StringManager.isWord(aWords[j], {'knock', 'knocks', 'knocked', 'fall', 'falls'}) and
                    StringManager.isWord(aWords[i], 'prone') then
                    bValidCondition = true;
                    nConditionStart = j;

                elseif StringManager.isWord(aWords[j], {'knock', 'knocks', 'fall', 'falls', 'falling', 'remain', 'is'}) and
                    StringManager.isWord(aWords[i], 'unconscious') then
                    if StringManager.isWord(aWords[j], 'falling') and StringManager.isWord(aWords[j - 1], 'of') and
                        StringManager.isWord(aWords[j - 2], 'instead') then
                        break
                    end
                    if StringManager.isWord(aWords[j], 'fall') and StringManager.isWord(aWords[j - 1], 'you') and
                        StringManager.isWord(aWords[j - 1], 'if') then
                        break
                    end
                    if StringManager.isWord(aWords[j], 'falls') and StringManager.isWord(aWords[j - 1], 'or') then
                        break
                    end
                    bValidCondition = true;
                    nConditionStart = j;
                    if StringManager.isWord(aWords[j], 'fall') and StringManager.isWord(aWords[j - 1], 'or') then
                        break
                    end

                elseif StringManager.isWord(aWords[j], {'become', 'becomes'}) and StringManager.isWord(aWords[i], 'frightened') then
                    bValidCondition = true;
                    nConditionStart = j;
                    break

                elseif StringManager.isWord(aWords[j], {'turns', 'become', 'becomes'}) and
                    StringManager.isWord(aWords[i], {'invisible'}) then
                    if StringManager.isWord(aWords[j - 1], {'can\'t', 'cannot'}) then
                        break
                    end
                    bValidCondition = true;
                    nConditionStart = j;

                    -- Special handling: Blindness/Deafness
                elseif StringManager.isWord(aWords[j], 'either') and StringManager.isWord(aWords[j - 1], 'is') then
                    bValidCondition = true;
                    break

                else
                    break
                end
                j = j - 1;
            end

            if bValidCondition then
                rCurrent = {};
                if not sPowerName then
                    rCurrent.sName = StringManager.capitalize(aWords[i]);
                else
                    rCurrent.sName = sPowerName .. '; ' .. StringManager.capitalize(aWords[i]);
                end
                rCurrent.startindex = nConditionStart;
                rCurrent.endindex = i;
                -- TODO: looks like a bug but not dealing with it now.
                -- if sRemoveTurn ~= '' then
                --     rCurrent.sName = rCurrent.sName .. '; ' .. sTurnModifier
                -- end
                rPrevious = rCurrent
            end
        end

        if rCurrent then
            PowerManager.parseEffectsAdd(aWords, i, rCurrent, effects);
            rCurrent = nil;
        end

        i = i + 1;
    end

    if rCurrent then
        PowerManager.parseEffectsAdd(aWords, i - 1, rCurrent, effects);
    end

    -- Handle duration field in NPC spell translations
    i = 1;
    while aWords[i] do
        if StringManager.isWord(aWords[i], 'duration') and StringManager.isWord(aWords[i + 1], ':') then
            local j = i + 2;
            local bConc = false;
            if StringManager.isWord(aWords[j], 'concentration') and StringManager.isWord(aWords[j + 1], 'up') and
                StringManager.isWord(aWords[j + 2], 'to') then
                bConc = true;
                j = j + 3;
            end
            if StringManager.isNumberString(aWords[j]) and
                StringManager.isWord(aWords[j + 1], {'round', 'rounds', 'minute', 'minutes', 'hour', 'hours', 'day', 'days'}) then
                local nDuration = tonumber(aWords[j]) or 0;
                local sUnits = '';
                if StringManager.isWord(aWords[j + 1], {'minute', 'minutes'}) then
                    sUnits = 'minute';
                elseif StringManager.isWord(aWords[j + 1], {'hour', 'hours'}) then
                    sUnits = 'hour';
                elseif StringManager.isWord(aWords[j + 1], {'day', 'days'}) then
                    sUnits = 'day';
                end

                for _, vEffect in ipairs(effects) do
                    if not vEffect.nDuration and (vEffect.sName ~= 'Prone') then
                        if bConc then
                            vEffect.sName = vEffect.sName .. '; (C)';
                        end
                        vEffect.nDuration = nDuration;
                        vEffect.sUnits = sUnits;
                    end
                end

                -- Add direct effect right from concentration text
                if bConc then
                    local rConcentrate = {};
                    rConcentrate.sName = sPowerName .. '; (C)';
                    rConcentrate.startindex = i;
                    rConcentrate.endindex = j + 1;

                    PowerManager.parseEffectsAdd(aWords, i, rConcentrate, effects);
                end
            end
        end
        i = i + 1;
    end

    return effects;
end
-- luacheck: pop

function getTurnModifier(aWords, i)
    local sRemoveTurn = '';
    while aWords[i] do
        if StringManager.isWord(aWords[i], 'until') and StringManager.isWord(aWords[i + 1], 'the') and
            StringManager.isWord(aWords[i + 2], {'start', 'end'}) and StringManager.isWord(aWords[i + 3], 'of') then
            if StringManager.isWord(aWords[i + 4], 'its') then
                if StringManager.isWord(aWords[i + 2], 'start') then
                    sRemoveTurn = 'TURNRS';
                else
                    sRemoveTurn = 'TURNRE';
                end
            else
                if StringManager.isWord(aWords[i + 2], 'start') then
                    sRemoveTurn = 'STURNRS';
                else
                    sRemoveTurn = 'STURNRE';
                end
            end
        end
        i = i + 1;
    end
    return sRemoveTurn;
end
