--  	Author: Ryan Hagelstrom
--      Copyright © 2021-2024
--      Please see the license file included with this distribution for
--      attribution and copyright information.
--
-- BCEG
-- luacheck: globals AttackManager5EBCE BCEManager EffectManagerBCE EffectConditionalManagerDnDBCE ActorManager5EBCE
-- luacheck: globals EffectManagerDnDBCE
-- luacheck: globals onInit onClose customModAttack customOnAttack customOnPostAttackResolve customGetRoll
-- luacheck: globals customPerformRoll sneakAttack rakishAudacity sneakAttackDamage notifySneakAttack handleSneakAttack
-- luacheck: globals getVision checkObscured targetSeeInvisible cunningStrike
local onAttack = nil;
local onPostAttackResolve = nil;
local modAttack = nil;
local getRoll = nil;
local performRoll = nil;

OOB_MSGTYPE_BCESNEAKATTACK = 'sneakattack';

function onInit()
    if Session.IsHost then
        OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCESNEAKATTACK, handleSneakAttack);
    end
    onAttack = ActionAttack.onAttack;
    onPostAttackResolve = ActionAttack.onPostAttackResolve;
    modAttack = ActionAttack.modAttack;
    getRoll = ActionAttack.getRoll;
    performRoll = ActionAttack.performRoll;

    ActionAttack.performRoll = customPerformRoll;
    ActionAttack.onAttack = customOnAttack;
    ActionAttack.onPostAttackResolve = customOnPostAttackResolve;
    ActionAttack.modAttack = customModAttack;
    ActionAttack.getRoll = customGetRoll;
    EffectManagerBCE.registerEffectCompType('ATKADD', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKADDT', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKHADD', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKMADD', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKFADD', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKCADD', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKHADDT', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKMADDT', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKFADDT', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKCADDT', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('ATKA', {bNoDUSE = true, bIgnoreDisabledCheck = true});
    EffectManagerBCE.registerEffectCompType('ATKHA', {bNoDUSE = true, bIgnoreDisabledCheck = true});
    EffectManagerBCE.registerEffectCompType('ATKMA', {bNoDUSE = true, bIgnoreDisabledCheck = true});
    EffectManagerBCE.registerEffectCompType('SNEAKATK', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('RAKISH', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('OBSCURED', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('VISION', {bIgnoreOtherFilter = true});
    EffectManagerBCE.registerEffectCompType('CSTRIKE', {bIgnoreOtherFilter = true});

    ActionsManager.registerResultHandler('attack', customOnAttack);
    ActionsManager.registerModHandler('attack', customModAttack);

    VisionManager.addVisionType('tremorsense', 'blindsight', true);
end

function onClose()
    ActionAttack.onAttack = onAttack;
    ActionAttack.onPostAttackResolve = onPostAttackResolve;
    ActionAttack.modAttack = modAttack;
    ActionAttack.getRoll = getRoll;
    ActionAttack.performRoll = performRoll;
end

function getVision(rSource)
    local nodeSource = ActorManager.getCTNode(rSource);
    local nBlindSight;
    local nTrueSight;
    local nDevilsSight;
    local nTremorSense;
    local nDarkvision;
    if rSource then
        local sSenses = DB.getValue(nodeSource, 'senses', '');
        local aSenses = StringManager.split(sSenses:lower(), ',', false);
        for _, sSense in pairs(aSenses) do
            if sSense:match('darkvision') then
                nDarkvision = tonumber(string.match(sSense, '%d+'));
            elseif sSense:match('blindsight') then
                nBlindSight = tonumber(string.match(sSense, '%d+'));
            elseif sSense:match('truesight') then
                nTrueSight = tonumber(string.match(sSense, '%d+'));
            elseif sSense:match('devil\'s sight') or sSense:match('devilsight') then
                nDevilsSight = tonumber(string.match(sSense, '%d+'));
            elseif sSense:match('tremorsense') then
                nTremorSense = tonumber(string.match(sSense, '%d+'));
            end
        end
    end

    local tMatch = EffectManager5E.getEffectsByType(rSource, 'VISION');
    for _, tEffect in pairs(tMatch) do
        for _, sDescriptor in pairs(tEffect.remainder) do
            sDescriptor = sDescriptor:lower();
            if sDescriptor == 'darkvision' then
                nDarkvision = tEffect.mod;
            elseif sDescriptor == 'blindsight' then
                nBlindSight = tEffect.mod;
            elseif sDescriptor == 'truesight' then
                nTrueSight = tEffect.mod;
            elseif sDescriptor == 'devil\'s sight' or sDescriptor == 'devilsight' then
                nDevilsSight = tEffect.mod;
            elseif sDescriptor == 'tremoresense' then
                nBlindSight = tEffect.mod;
            end
        end
    end
    if nBlindSight and nTremorSense and nTremorSense > nBlindSight then
        nBlindSight = nTremorSense;
    elseif nTremorSense and not nBlindSight then
        nBlindSight = nTremorSense;
    elseif not nBlindSight then
        nBlindSight = 0;
    end
    if not nDarkvision then
        nDarkvision = 0
    end
    if not nBlindSight then
        nBlindSight = 0
    end
    if not nTrueSight then
        nTrueSight = 0
    end
    if not nDevilsSight then
        nDevilsSight = 0
    end

    return nDarkvision, nBlindSight, nTrueSight, nDevilsSight
end

function targetSeeInvisible(rSource, rTarget)
    local bReturn = false;
    if rSource and rTarget then
        local nodeCTSource = ActorManager.getCTNode(rSource);
        local tokenActor = CombatManager.getTokenFromCT(nodeCTSource);
        local nodeCTTarget = ActorManager.getCTNode(rTarget);
        local tokenTarget = CombatManager.getTokenFromCT(nodeCTTarget);
        local nRange;
        if tokenActor and tokenTarget then
            nRange = Token.getDistanceBetween(tokenActor, tokenTarget);
        end
        if nRange then
            nRange = tonumber(nRange);
            local _, nTargetBlindSight, nTargetTrueSight, _ = AttackManager5EBCE.getVision(rTarget);
            if (nTargetBlindSight >= nRange or nTargetTrueSight >= nRange) and
                EffectManager5E.hasEffectCondition(rSource, 'Invisible') then
                bReturn = true;
            end
        end
    end
    return bReturn;
end

-- luacheck: push ignore 561
function checkObscured(rSource, rTarget, rRoll)
    if rSource and rTarget then
        local nodeCTSource = ActorManager.getCTNode(rSource);
        local tokenActor = CombatManager.getTokenFromCT(nodeCTSource);
        local nodeCTTarget = ActorManager.getCTNode(rTarget);
        local tokenTarget = CombatManager.getTokenFromCT(nodeCTTarget);
        local nRange;
        if tokenActor and tokenTarget then
            nRange = Token.getDistanceBetween(tokenActor, tokenTarget);
        end
        if nRange then
            nRange = tonumber(nRange)

            local nSourceDarkvision, nSourceBlindSight, nSourceTrueSight, nSourceDevilsSight = AttackManager5EBCE.getVision(
                                                                                                   rSource);
            local nTargetDarkvision, nTargetBlindSight, nTargetTrueSight, nTargetDevilsSight = AttackManager5EBCE.getVision(
                                                                                                   rTarget);

            for i = 1, 2 do
                local tMatch
                if i == 1 then
                    tMatch = EffectManager5E.getEffectsByType(rTarget, 'OBSCURED', nil, rSource);
                elseif i == 2 then
                    tMatch = EffectManager5E.getEffectsByType(rSource, 'OBSCURED', nil, rTarget);
                end

                if next(tMatch) then
                    if not string.match(rRoll.sDesc, '%[OBSCURED%]') then
                        rRoll.sDesc = rRoll.sDesc .. ' [OBSCURED]';
                    end
                    for _, tEffect in pairs(tMatch) do
                        for _, sDescriptor in pairs(tEffect.remainder) do
                            sDescriptor = sDescriptor:lower();
                            if sDescriptor == 'magical darkness' then
                                -- Target cannot see the attacker
                                if (nTargetBlindSight <= nRange and nTargetTrueSight <= nRange and nTargetDevilsSight <= nRange) and
                                    not string.match(rRoll.sDesc, '%[ADV%]') then
                                    rRoll.sDesc = rRoll.sDesc .. ' [ADV]';
                                end
                                -- Attacker cannot see the Target
                                if (nSourceBlindSight <= nRange and nSourceTrueSight <= nRange and nSourceDevilsSight <= nRange) and
                                    not string.match(rRoll.sDesc, '%[DIS%]') then
                                    rRoll.sDesc = rRoll.sDesc .. ' [DIS]';
                                end
                            elseif sDescriptor == 'darkness' then
                                -- Target cannot see the attacker
                                if (nTargetBlindSight <= nRange and nTargetTrueSight <= nRange and nTargetDevilsSight <= nRange and
                                    nTargetDarkvision <= nRange) and not string.match(rRoll.sDesc, '%[ADV%]') then
                                    rRoll.sDesc = rRoll.sDesc .. ' [ADV]';
                                end
                                -- Attacker cannot see the Target
                                if (nSourceBlindSight <= nRange and nSourceTrueSight <= nRange and nSourceDevilsSight <= nRange and
                                    nSourceDarkvision <= nRange) and not string.match(rRoll.sDesc, '%[DIS%]') then
                                    rRoll.sDesc = rRoll.sDesc .. ' [DIS]';
                                end
                            elseif sDescriptor == 'physical' then
                                -- Target cannot see the attacker
                                if nTargetBlindSight <= nRange and not string.match(rRoll.sDesc, '%[ADV%]') then
                                    rRoll.sDesc = rRoll.sDesc .. ' [ADV]';
                                end
                                -- Attacker cannot see the Target
                                if nSourceBlindSight <= nRange and not string.match(rRoll.sDesc, '%[DIS%]') then
                                    rRoll.sDesc = rRoll.sDesc .. ' [DIS]';
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
-- luacheck: pop

function customModAttack(rSource, rTarget, rRoll)
    BCEManager.chat('customModAttack : ');
    EffectConditionalManagerDnDBCE.addConditionalHelper(rSource, rTarget, rRoll);
    if ActorManager5EBCE.hasTrait(rSource, 'Pack Tactics') and not string.match(rRoll.sDesc, '%[ADV%]') and
        EffectConditionalManagerDnDBCE.isRange(rTarget, '5,enemy', rSource) then
        rRoll.sDesc = rRoll.sDesc .. ' [PACK TACTICS] [ADV]';
    end

    AttackManager5EBCE.checkObscured(rSource, rTarget, rRoll);
    modAttack(rSource, rTarget, rRoll);

    EffectConditionalManagerDnDBCE.removeConditionalHelper(rSource, rTarget, rRoll);
end

function customOnAttack(rSource, rTarget, rRoll)
    BCEManager.chat('customOnAttack : ');
    local aRange = {};
    -- For whatever reason boolean is not copied over correctly
    -- somewhere between passing to the engine and returning.
    -- The engine makes the type an empty string. We will assume if these are here
    -- then they are true because we never set them if false
    -- Drag also converts to a string so handle that too
    if rRoll.bSpell and (rRoll.bSpell == '' or rRoll.bSpell == 'true') then
        rRoll.bSpell = true;
    end
    if rRoll.bWeapon and (rRoll.bWeapon == '' or rRoll.bWeapon == 'true') then
        rRoll.bWeapon = true;
    end
    if rRoll.sRange == 'M' then
        table.insert(aRange, 'melee');
    elseif rRoll.sRange == 'R' then
        table.insert(aRange, 'ranged');
    end
    if rSource then
        rSource.itemPath = rRoll.itemPath;
        rSource.ammoPath = rRoll.ammoPath;
    end
    local tMatch;
    local aTags = {'ATKD', 'ATKA', 'ATKR'};
    local nodeSource = ActorManager.getCTNode(rSource);
    EffectConditionalManagerDnDBCE.addConditionalHelper(rSource, rTarget, rRoll);

    for _, sTag in pairs(aTags) do
        tMatch = EffectManager5E.getEffectsByType(rSource, sTag, aRange, rTarget);
        for _, tEffect in pairs(tMatch) do
            if sTag == 'ATKA' then
                BCEManager.chat('ATKA : ');
                BCEManager.modifyEffect(tEffect.sEffectNode, 'Activate');
            elseif sTag == 'ATKD' then
                BCEManager.chat('ATKD : ');
                BCEManager.modifyEffect(tEffect.sEffectNode, 'Deactivate');
            elseif sTag == 'ATKR' then
                BCEManager.chat('ATKR : ');
                BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
            end
        end
    end
    tMatch = EffectManager5E.getEffectsByType(rSource, 'ATKADD', nil, rTarget);
    for _, tEffect in pairs(tMatch) do
        for _, remainder in pairs(tEffect.remainder) do
            BCEManager.notifyAddEffect(nodeSource, nodeSource, remainder);
        end
    end

    tMatch = EffectManager5E.getEffectsByType(rSource, 'ATKADDT', nil, rTarget);
    for _, tEffect in pairs(tMatch) do
        local nodeTarget = ActorManager.getCTNode(rTarget);
        for _, remainder in pairs(tEffect.remainder) do
            BCEManager.notifyAddEffect(nodeTarget, nodeSource, remainder);
        end
    end
    onAttack(rSource, rTarget, rRoll);
    EffectConditionalManagerDnDBCE.removeConditionalHelper(rSource, rTarget, rRoll);
end

function customOnPostAttackResolve(rSource, rTarget, rRoll, rMessage)
    BCEManager.chat('customOnPostAttackResolve : ');
    local tMatch;
    local aTags = {};
    local aAddTags = {};
    local aRange = {};
    if rRoll.sRange == 'M' then
        table.insert(aRange, 'melee');
    elseif rRoll.sRange == 'R' then
        table.insert(aRange, 'ranged');
    end
    if rRoll.sResult == 'hit' or rRoll.sResult == 'crit' then
        aTags = {'TATKHDMGS'};
    elseif rRoll.sResult == 'miss' or rRoll.sResult == 'fumble' then
        aTags = {'TATKMDMGS'};
    end
    for _, sTag in pairs(aTags) do
        tMatch = EffectManager5E.getEffectsByType(rTarget, sTag, aRange, rSource);
        for _, tEffect in pairs(tMatch) do
            if sTag == 'TATKHDMGS' or sTag == 'TATKMDMGS' then
                BCEManager.chat(tEffect.type .. ' : ');
                EffectManagerDnDBCE.applyOngoingDamage(rTarget, rSource, tEffect, false);
            end
        end
    end

    if rRoll.sResult == 'hit' or rRoll.sResult == 'crit' then
        aTags = {'ATKHA', 'ATKHD', 'ATKHR', 'SNEAKATK', 'RAKISH'};
        aAddTags = {'ATKHADD', 'ATKHADDT'};
    elseif rRoll.sResult == 'miss' or rRoll.sResult == 'fumble' then
        aTags = {'ATKMA', 'ATKMD', 'ATKMR'};
        aAddTags = {'ATKMADD', 'ATKMADDT'};
    end
    if rRoll.sResult == 'fumble' then
        table.insert(aAddTags, 'ATKFADD');
        table.insert(aAddTags, 'ATKFADDT');
    end
    if rRoll.sResult == 'crit' then
        table.insert(aAddTags, 'ATKCADD');
        table.insert(aAddTags, 'ATKCADDT');
    end
    for _, sTag in pairs(aTags) do
        tMatch = EffectManager5E.getEffectsByType(rSource, sTag, aRange, rTarget);
        for _, tEffect in pairs(tMatch) do
            if sTag == 'ATKHA' or sTag == 'ATKMA' then
                BCEManager.chat(tEffect.type .. ' : ');
                BCEManager.modifyEffect(tEffect.sEffectNode, 'Activate');
            elseif sTag == 'ATKHD' or sTag == 'ATKMD' then
                BCEManager.chat(tEffect.type .. ' : ');
                BCEManager.modifyEffect(tEffect.sEffectNode, 'Deactivate');
            elseif sTag == 'ATKHR' or sTag == 'ATKMR' then
                BCEManager.chat(tEffect.type .. ' : ');
                BCEManager.modifyEffect(tEffect.sEffectNode, 'Remove');
            elseif sTag == 'SNEAKATK' then
                AttackManager5EBCE.sneakAttack(rSource, tEffect, rTarget);
            elseif sTag == 'RAKISH' then
                AttackManager5EBCE.rakishAudacity(rSource, tEffect, rTarget);
            end
        end
    end
    local nodeSource = ActorManager.getCTNode(rSource);
    local nodeTarget = ActorManager.getCTNode(rTarget);
    for _, sTag in pairs(aAddTags) do
        tMatch = EffectManager5E.getEffectsByType(rSource, sTag, nil, rTarget);
        for _, tEffect in pairs(tMatch) do
            BCEManager.chat(tEffect.type .. ' : ');
            if sTag == 'ATKHADD' or sTag == 'ATKMADD' or sTag == 'ATKFADD' or sTag == 'ATKCADD' then
                for _, remainder in pairs(tEffect.remainder) do
                    BCEManager.notifyAddEffect(nodeSource, nodeSource, remainder);
                end
            else
                for _, remainder in pairs(tEffect.remainder) do
                    BCEManager.notifyAddEffect(nodeTarget, nodeSource, remainder);
                end
            end
        end
    end

    onPostAttackResolve(rSource, rTarget, rRoll, rMessage);
    EffectConditionalManagerDnDBCE.removeConditionalHelper(rSource, rTarget, rRoll);
end

function customGetRoll(rActor, rAction)
    BCEManager.chat('customGetRoll ActionAttack : ');
    local rRoll = getRoll(rActor, rAction);
    rRoll.bWeapon = (rAction.bWeapon or rAction.weapon);
    rRoll.bSpell = (rAction.bSpell or rAction.spell);
    rRoll.itemPath = rAction.itemPath;
    rRoll.ammoPath = rAction.ammoPath;
    return rRoll;
end

function customPerformRoll(draginfo, rActor, rAction)
    BCEManager.chat('customPerformRoll ActionAttack : ');
    if (draginfo and ((rAction.itemPath and rAction.itemPath ~= '') or (rAction.ammoPath and rAction.ammoPath ~= ''))) then
        draginfo.setMetaData('itemPath', rAction.itemPath);
        draginfo.setMetaData('ammoPath', rAction.ammoPath);
    end
    performRoll(draginfo, rActor, rAction);
end

function sneakAttack(rSource, tEffect, rTarget)
    local nodeCT = ActorManager.getCTNode(rSource);
    if ActorManager.isPC(nodeCT) then
        local bInsightfulFighting = EffectManager5E.hasEffect(rSource, 'INSIGHTFUL FIGHTING', rTarget, true);
        if rSource.tBCEG.bADV and not rSource.tBCEG.bDIS and rSource.tBCEG.bWeapon and
            ((EffectConditionalManagerDnDBCE.isWeapon(rSource, 'finesse') and rSource.tBCEG.sRange == 'melee') or
                rSource.tBCEG.sRange == 'ranged') then
            AttackManager5EBCE.sneakAttackDamage(rSource, tEffect, 'Sneak Attack;');
        elseif not rSource.tBCEG.bADV and not rSource.tBCEG.bDIS and rSource.tBCEG.bWeapon and
            ((rSource.tBCEG.sRange == 'melee' and EffectConditionalManagerDnDBCE.isWeapon(rSource, 'finesse')) or
                rSource.tBCEG.sRange == 'ranged') and EffectConditionalManagerDnDBCE.isRange(rTarget, '5,enemy', rSource) then
            AttackManager5EBCE.sneakAttackDamage(rSource, tEffect, 'Sneak Attack;');
        elseif bInsightfulFighting and not rSource.tBCEG.bDIS and rSource.tBCEG.bWeapon and
            ((EffectConditionalManagerDnDBCE.isWeapon(rSource, 'finesse') and rSource.tBCEG.sRange == 'melee') or
                rSource.tBCEG.sRange == 'ranged') then
            AttackManager5EBCE.sneakAttackDamage(rSource, tEffect, 'Sneak Attack (Insightful Fighting);');
        end
    else
        -- Don't need to check the trait because we explictly have the effect which we need to automate the once per turn
        if rSource.tBCEG.bADV and not rSource.tBCEG.bDIS and rSource.tBCEG.bWeapon then
            AttackManager5EBCE.sneakAttackDamage(rSource, tEffect, 'Sneak Attack;');
        elseif not rSource.tBCEG.bADV and not rSource.tBCEG.bDIS and rSource.tBCEG.bWeapon and
            EffectConditionalManagerDnDBCE.isRange(rTarget, '5,enemy', rSource) then
            AttackManager5EBCE.sneakAttackDamage(rSource, tEffect, 'Sneak Attack;');
        end
    end
end

function rakishAudacity(rSource, tEffect, rTarget)
    if ((not rSource.tBCEG.bADV and not rSource.tBCEG.bDIS) or (rSource.tBCEG.bADV and rSource.tBCEG.bDIS)) and
        rSource.tBCEG.bWeapon and
        ((rSource.tBCEG.sRange == 'melee' and EffectConditionalManagerDnDBCE.isWeapon(rSource, 'finesse')) or rSource.tBCEG.sRange ==
            'ranged') and EffectConditionalManagerDnDBCE.isRange(rSource, '5,target', nil, {rTarget}) and
        not EffectConditionalManagerDnDBCE.isRange(rTarget, '5,enemy', rSource) and
        not EffectConditionalManagerDnDBCE.isRange(rSource, '5,!target', rTarget) then
        AttackManager5EBCE.sneakAttackDamage(rSource, tEffect, 'Sneak Attack (Rakish Audacity);');
    else
        AttackManager5EBCE.sneakAttack(rSource, tEffect, rTarget);
    end
end

function sneakAttackDamage(rSource, tEffect, sLabel)
    local nodeSource = ActorManager.getCreatureNode(rSource);
    local nodeCT = ActorManager.getCTNode(rSource);
    local nDamage;
    if ActorManager.isPC(nodeCT) then
        for _, nodeClass in ipairs(DB.getChildList(nodeSource, 'classes')) do
            local sClassName = StringManager.trim(DB.getValue(nodeClass, 'name', '')):lower();
            if ((tEffect.type:upper() == 'SNEAKATK' or tEffect.type:upper() == 'RAKISH') and
                StringManager.contains(tEffect.remainder, sClassName)) or sClassName == 'rogue' then
                nDamage = math.ceil(DB.getValue(nodeClass, 'level', 0) / 2);
            end
        end
    else
        -- NPC get the cr
        local nCR = DB.getValue(nodeCT, 'cr', '0');
        if nCR == '1/2' then
            nCR = .5;
        elseif nCR == '1/4' then
            nCR = .25;
        elseif nCR == '1/8' then
            nCR = .125;
        end
        nCR = tonumber(nCR);
        if nCR then
            nDamage = math.ceil(nCR / 2);
        else
            nDamage = 0;
        end
    end

    if nDamage and nDamage > 0 then
        local sDamage = sLabel .. ' SNEAKDMG: ' .. tostring(nDamage) .. 'd6';
        local rEffect = {};
        rEffect.sName = sDamage;
        rEffect.sSource = DB.getPath(nodeCT);
        rEffect.nDuration = 0;
        rEffect.sUnits = '';
        rEffect.sApply = 'roll';
        rEffect.nInit = DB.getValue(nodeCT, 'initresult', 0);
        if not ActorManager.isPC(nodeCT) then
            rEffect.nGMOnly = 1;
        end
        AttackManager5EBCE.notifySneakAttack(rEffect);
        BCEManager.modifyEffect(tEffect.sEffectNode, 'Deactivate');
    end
end

function notifySneakAttack(rEffect)
    local msgOOB = {};
    msgOOB.type = OOB_MSGTYPE_BCESNEAKATTACK;
    msgOOB.sName = rEffect.sName;
    msgOOB.sSource = rEffect.sSource;
    msgOOB.nDuration = rEffect.nDuration;
    msgOOB.sUnits = rEffect.sUnits;
    msgOOB.sApply = rEffect.sApply;
    msgOOB.nInit = rEffect.nInit;
    msgOOB.nGMOnly = rEffect.nGMOnly;
    if Session.IsHost then
        AttackManager5EBCE.handleSneakAttack(msgOOB);
    else
        Comm.deliverOOBMessage(msgOOB, '');
    end
end

function handleSneakAttack(msgOOB)
    local rEffect = {};
    local nodeCTSource = DB.findNode(msgOOB.sSource);
    local nodeSource = ActorManager.getCreatureNode(nodeCTSource);
    local sOwner = DB.getOwner(nodeSource);

    rEffect.sName = msgOOB.sName;
    rEffect.nDuration = msgOOB.nDuration;
    rEffect.sUnits = msgOOB.sUnits;
    rEffect.sApply = msgOOB.sApply;
    rEffect.nInit = msgOOB.nInit;
    rEffect.nGMOnly = msgOOB.nGMOnly;
    EffectManager.addEffect(sOwner, '', nodeCTSource, rEffect, true);
end

function cunningStrike(rSource, rTarget, rRoll, tDmgEffects)
    if rRoll.sType == 'damage' then
        local bCunningStrike;
        if next(tDmgEffects.dice) then
            if OptionsManager.isOption('GAVE', '2024') then
                local tCStrike = EffectManager5E.getEffectsByType(rSource, 'CSTRIKE');
                if next(tCStrike) then
                    local bTrip;
                    local bPoison;
                    local bWithdraw;
                    local bDaze;
                    local bKnockout;
                    local bObscure;

                    local nDC = 8 + ActorManager5E.getAbilityBonus(rSource, DataCommon.ability_stol['DEX']) +
                                    ActorManager5E.getAbilityBonus(rSource, 'prf');
                    for _, rStrike in ipairs(tCStrike) do
                        if not bTrip and StringManager.contains(rStrike.remainder, 'trip') and #tDmgEffects.dice >= 1 then
                            bTrip = true;
                            bCunningStrike = true;
                            table.remove(tDmgEffects.dice, 1);
                            local nSize = ActorCommonManager.getCreatureSizeDnD5(rTarget);
                            local sDesc = '[SAVE VS] Cunning Strike Trip [DEX DC ' .. tostring(nDC) .. ']'

                            -- Large or smaller bigger
                            if nSize <= 1 then
                                sDesc = sDesc .. ' [CS:TRIP]';
                                ActionSave.performVsRoll(nil, rTarget, DataCommon.ability_stol['DEX'], nDC, 0, rSource, false,
                                                         sDesc);
                            else
                                sDesc = sDesc .. ' [AUTOSUCCESS] [TO LARGE]';
                                local rMessage = ActionsManager.createActionMessage(rTarget, {sDesc = sDesc, type = 'save'});
                                Comm.deliverChatMessage(rMessage);
                            end
                        end
                        if not bPoison and StringManager.contains(rStrike.remainder, 'poison') and #tDmgEffects.dice >= 1 then
                            bPoison = true;
                            bCunningStrike = true;
                            table.remove(tDmgEffects.dice, 1);
                            local sDesc = '[SAVE VS] Cunning Strike Poison [CON DC ' .. tostring(nDC) .. '] [CS:POISON]'

                            ActionSave.performVsRoll(nil, rTarget, DataCommon.ability_stol['CON'], nDC, 0, rSource, false, sDesc);
                        end
                        if not bWithdraw and StringManager.contains(rStrike.remainder, 'withdraw') and #tDmgEffects.dice >= 1 then
                            bWithdraw = true;
                            bCunningStrike = true;
                            table.remove(tDmgEffects.dice, 1);
                        end
                        if not bDaze and StringManager.contains(rStrike.remainder, 'daze') and #tDmgEffects.dice >= 2 then
                            bDaze = true;
                            bCunningStrike = true;
                            for _ = 1, 2 do
                                table.remove(tDmgEffects.dice, 1);
                            end
                            local sDesc = '[SAVE VS] Cunning Strike Daze [CON DC ' .. tostring(nDC) .. '] [CS:DAZE]'
                            ActionSave.performVsRoll(nil, rTarget, DataCommon.ability_stol['CON'], nDC, 0, rSource, false, sDesc);
                        end
                        if not bKnockout and StringManager.contains(rStrike.remainder, 'knockout') and #tDmgEffects.dice >= 6 then
                            bKnockout = true;
                            bCunningStrike = true;
                            for _ = 1, 6 do
                                table.remove(tDmgEffects.dice, 1);
                            end

                            local sDesc = '[SAVE VS] Cunning Strike Knock Out [CON DC ' .. tostring(nDC) .. '] [CS:KNOCKOUT]'
                            ActionSave.performVsRoll(nil, rTarget, DataCommon.ability_stol['CON'], nDC, 0, rSource, false, sDesc);
                        end
                        if not bObscure and StringManager.contains(rStrike.remainder, 'obscure') and #tDmgEffects.dice >= 3 then
                            bObscure = true;
                            bCunningStrike = true;
                            for  _ = 1, 3 do
                                table.remove(tDmgEffects.dice, 1);
                            end
                            local sDesc = '[SAVE VS] Cunning Strike Obscure [DEX DC ' .. tostring(nDC) .. '] [CS:OBSCURE]'
                            ActionSave.performVsRoll(nil, rTarget, DataCommon.ability_stol['DEX'], nDC, 0, rSource, false, sDesc);
                        end
                    end
                end
            end
            rRoll.sDesc = rRoll.sDesc .. ' [SNEAKATK ' .. tostring(#tDmgEffects.dice) .. 'd6]'
            if bCunningStrike then
                rRoll.sDesc = rRoll.sDesc .. ' [CUNNING STRIKE]'
            end

        end
    end
end
