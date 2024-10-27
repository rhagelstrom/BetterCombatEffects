--  	Author: Ryan Hagelstrom
--      Please see the license file included with this distribution for
--      attribution and copyright information.
--
-- luacheck: globals MigrationManagerBCE BCEManager
-- luacheck: globals migration migrateItems migrateSpells migrateCustomEffects migrateCombatTracker migrateCharSheet
-- luacheck: globals migrateNPC migratePowers  migrateAdvancedEffects migrateKnK  migrationHelper migrateEffect
-- luacheck: globals slashOpen onClose onTabletopInit onInit deprecateTagMsg
local aMigrate = {
    'DUSE',
    'ATURN',
    'TURNAS',
    'TURNDS',
    'TURNRS',
    'TURNAE',
    'TURNDE',
    'TURNRE',
    'STURNRS',
    'STURNRE',
    'SSAVEE',
    'SSAVES',
    'SAVEE',
    'SAVES',
    'SAVEONDMG',
    'SAVEA',
    'SAVERESTL'
};

local nodeStory = nil;
local bWrite = false;
local sDesc = '';

function onInit()
    if Session.IsHost then
        Comm.registerSlashHandler('migrate_effects', slashOpen);
    end
end
function onTabletopInit()
    if Session.IsHost then
        local nodeMigrate = DB.getRoot().createChild('bce_migrate');
        local nodeNoShow = DB.getChild(nodeMigrate, 'noshow');
        if not nodeNoShow then
            DB.setValue(nodeMigrate, 'noshow', 'number', 1);
            nodeNoShow = DB.getChild(nodeMigrate, 'noshow');
        end

        if nodeMigrate and DB.getValue(nodeNoShow, '', 0) == 0 then
            Interface.openWindow('bce_migrator', nodeMigrate);
        end
    end
end

function onClose()
end

function slashOpen()
    if Session.IsHost then
        local nodeMigrate = DB.getRoot().createChild('bce_migrate')
        Interface.openWindow('bce_migrator', nodeMigrate);
    end
end
function migration(bShouldWrite)
    if bShouldWrite and bShouldWrite ~= '' then
        bWrite = true;
    end
    nodeStory = DB.createChild('encounter');
    if nodeStory then
        local tDate = os.date('*t');
        local sDate = tDate.month .. '/' .. tDate.day .. '/' .. tDate.year .. ' ' .. tDate.hour .. ':' .. tDate.min .. ':' ..
                          tDate.sec;
        if bWrite then
            DB.setValue(nodeStory, 'name', 'string', '00 - Better Combat Effects Migration ' .. sDate);
        else
            DB.setValue(nodeStory, 'name', 'string', '00 - Better Combat Effects Migration Preview ' .. sDate);
        end
        sDesc = '';

        MigrationManagerBCE.migrateCustomEffects();
        MigrationManagerBCE.migrateCombatTracker();
        MigrationManagerBCE.migrateCharSheet();
        MigrationManagerBCE.migrateNPC();
        MigrationManagerBCE.migrateItems();
        MigrationManagerBCE.migrateSpells();
        DB.setValue(nodeStory, 'text', 'formattedtext', sDesc);
        Interface.openWindow('encounter', nodeStory);

    end
end

function migrateItems()
    sDesc = sDesc .. '<h>Items</h>';
    for _, nodeItem in pairs(DB.getChildren('item')) do
        local bFirst = true;
        local aEffectList = DB.getChildren(nodeItem, 'effectlist');
        for _, nodeEffect in pairs(aEffectList) do
            local sName = DB.getValue(nodeEffect, 'effect', '');
            local sNameMod, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeEffect, sName);
            if sNameMod ~= sName then
                if bFirst then
                    sDesc = sDesc .. '<link class="item" recordname=\"' .. DB.getPath(nodeItem) .. '\"><b>' ..
                                UtilityManager.encodeXML(DB.getValue(nodeItem, 'name', '')) .. '</b></link>';
                    sDesc =
                        sDesc .. '<table><tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b></td>' ..
                            '<td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                    bFirst = false;
                end
                if bWrite then
                    DB.setValue(nodeEffect, 'effect', 'string', sNameMod);
                end
                sDesc = sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(sName) .. '</td><td colspan=\"2\">' ..
                            UtilityManager.encodeXML(sNameMod) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState ..
                            '</td></tr>';
            end
        end
        if not bFirst then
            sDesc = sDesc .. '</table>'
        end
        MigrationManagerBCE.migrateAdvancedEffects(nodeItem);
    end
end

function migrateSpells()
    sDesc = sDesc .. '<h>Spells</h>';
    for _, nodeSpell in pairs(DB.getChildren('spell')) do
        local bFirst = true;
        for _, nodeAction in pairs(DB.getChildren(nodeSpell, 'actions')) do
            if DB.getValue(nodeAction, 'type', '') == 'effect' then
                local sName = DB.getValue(nodeAction, 'label', '');
                local sNameMod, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeAction, sName);
                if sNameMod ~= sName then
                    if bFirst then
                        sDesc = sDesc .. '<link class="power" recordname=\"' .. DB.getPath(nodeSpell) .. '\"><b>' ..
                                    UtilityManager.encodeXML(DB.getValue(nodeSpell, 'name', '')) .. '</b></link>';
                        sDesc = sDesc .. '<table><tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified' ..
                                    'end</b></td><td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                        bFirst = false;
                    end
                    if bWrite then
                        DB.setValue(nodeAction, 'label', 'string', sNameMod);
                    end
                    sDesc = sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(sName) .. '</td><td colspan=\"2\">' ..
                                UtilityManager.encodeXML(sNameMod) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState ..
                                '</td></tr>';
                end
            end
        end
        if not bFirst then
            sDesc = sDesc .. '</table>'
        end
    end
end

function migrateCustomEffects()
    local bFirst = true;
    for _, nodeEffect in pairs(DB.getChildren('effects')) do
        local rEffect = EffectManager.getEffect(nodeEffect);
        local sName, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeEffect, rEffect.sName);
        if sName ~= rEffect.sName then
            if bFirst then
                sDesc = sDesc .. '<h>Custom Effects List</h>';
                sDesc = sDesc .. '<table><tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b></td>' ..
                            '<td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                bFirst = false;
            end
            if bWrite then
                DB.setValue(nodeEffect, 'label', 'string', sName);
            end
            sDesc = sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(rEffect.sName) .. '</td><td colspan=\"2\">' ..
                        UtilityManager.encodeXML(sName) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState .. '</td></tr>';
        end
    end
    if not bFirst then
        sDesc = sDesc .. '</table>'
    end
end

function migrateCombatTracker()
    local bFirst = true;
    local ctEntries = CombatManager.getCombatantNodes();
    for _, nodeCT in pairs(ctEntries) do
        local bFirstActor = true
        -- Effects
        for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
            local rEffect = EffectManager.getEffect(nodeEffect);
            local sName, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeEffect, rEffect.sName);
            if sName ~= rEffect.sName then
                if bFirst then
                    sDesc = sDesc .. '<h>Combat Tracker</h>';
                    bFirst = false;
                end
                if bFirstActor then
                    if ActorManager.isPC(nodeCT) then
                        local rActor = ActorManager.resolveActor(nodeCT);
                        sDesc = sDesc .. '<link class="charsheet" recordname=\"' .. rActor.sCreatureNode .. '\"><b>' ..
                                    UtilityManager.encodeXML(rActor.sName) .. '</b></link>';
                    else
                        sDesc = sDesc .. '<link class="npc" recordname=\"' .. DB.getPath(nodeCT) .. '\"><b>' ..
                                    UtilityManager.encodeXML(DB.getValue(nodeCT, 'name', '')) .. '</b></link>';
                    end
                    sDesc = sDesc .. '<table><tr><td colspan=\"6\"><b>Effect</b></td></tr>'
                    sDesc = sDesc .. '<tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b></td>' ..
                                '<td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                    bFirstActor = false;
                end
                if bWrite then
                    DB.setValue(nodeEffect, 'label', 'string', sName);
                end
                sDesc =
                    sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(rEffect.sName) .. '</td><td colspan=\"2\">' ..
                        UtilityManager.encodeXML(sName) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState .. '</td></tr>';
            end
        end
        if not bFirstActor then
            sDesc = sDesc .. '</table>';
        end
        MigrationManagerBCE.migrateAdvancedEffects(nodeCT);
    end
end

function migrateCharSheet()
    sDesc = sDesc .. '<h>Character Sheet</h>';
    for _, nodeActor in pairs(DB.getChildren('charsheet')) do
        if ActorManager.isPC(nodeActor) then
            sDesc = sDesc .. '<link class="charsheet" recordname=\"' .. DB.getPath(nodeActor) .. '\"><b>' ..
                        UtilityManager.encodeXML(DB.getValue(nodeActor, 'name', '')) .. '</b></link>';
        else
            sDesc = sDesc .. '<link class="npc" recordname=\"' .. DB.getPath(nodeActor) .. '\"><b>' ..
                        UtilityManager.encodeXML(DB.getValue(nodeActor, 'name', '')) .. '</b></link>';
        end
        MigrationManagerBCE.migratePowers(nodeActor);
        MigrationManagerBCE.migrateAdvancedEffects(nodeActor);
    end
end

function migrateNPC()
    sDesc = sDesc .. '<h>NPC</h>';
    for _, nodeActor in pairs(DB.getChildren('npc')) do
        MigrationManagerBCE.migrateAdvancedEffects(nodeActor, true);
    end
end

function migratePowers(nodeActor)
    local bFirst = true;
    local aPowers = DB.getChildList(nodeActor, 'powers');
    for _, nodePower in ipairs(aPowers) do
        local aActions = DB.getChildren(nodePower, 'actions');
        for _, nodeAction in pairs(aActions) do
            local sType = DB.getValue(nodeAction, 'type', '');
            if sType == 'effect' then
                local sName = DB.getValue(nodeAction, 'label', '');
                local sNameMod, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeAction, sName);
                if sName ~= sNameMod then
                    if bFirst then
                        sDesc = sDesc .. '<table><tr><td colspan=\"6\"><b>Powers</b></td></tr>';
                        sDesc = sDesc .. '<tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b></td>' ..
                                    '<td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                        bFirst = false;
                    end
                    if bWrite then
                        DB.setValue(nodeAction, 'label', 'string', sNameMod);
                    end
                    sDesc = sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(sName) .. '</td><td colspan=\"2\">' ..
                                UtilityManager.encodeXML(sNameMod) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState ..
                                '</td></tr>';
                end
            end
        end
    end
    if not bFirst then
        sDesc = sDesc .. '</table>';
    end
end

function migrateAdvancedEffects(nodeActor, bPrintActor)
    local bFirst = true;
    -- Items on Actor
    -- Effect List on Actor
    local aEffectList = DB.getChildren(nodeActor, 'effectlist');
    for _, nodeEffect in pairs(aEffectList) do
        local sName = DB.getValue(nodeEffect, 'effect', '');
        local sNameMod, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeEffect, sName);
        if sName ~= sNameMod then
            if bFirst then
                if bPrintActor then
                    if ActorManager.isPC(nodeActor) then
                        sDesc = sDesc .. '<link class="charsheet" recordname=\"' .. DB.getPath(nodeActor) .. '\"><b>' ..
                                    UtilityManager.encodeXML(DB.getValue(nodeActor, 'name', '')) .. '</b></link>';
                    else
                        sDesc = sDesc .. '<link class="npc" recordname=\"' .. DB.getPath(nodeActor) .. '\"><b>' ..
                                    UtilityManager.encodeXML(DB.getValue(nodeActor, 'name', '')) .. '</b></link>';
                    end
                end
                sDesc = sDesc .. '<table><tr><td colspan=\"6\"><b>Advanced Effects</b></td></tr>';
                sDesc = sDesc .. '<tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b>' ..
                            '</td><td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                bFirst = false;
            end
            if bWrite then
                DB.setValue(nodeEffect, 'effect', 'string', sNameMod);
            end
            sDesc =
                sDesc .. '<tr><td colspan=\"2\">' .. sName .. '</td><td colspan=\"2\">' .. sNameMod .. '</td><td>' .. sApply ..
                    '</td><td>' .. sChangeState .. '</td></tr>';
        end
    end
    if not bFirst then
        sDesc = sDesc .. '</table>'
    end

    for _, nodeItem in ipairs(DB.getChildList(nodeActor, 'inventorylist')) do
        bFirst = true;
        for _, nodeEffect in pairs(DB.getChildren(nodeItem, 'effectlist')) do
            local sName = DB.getValue(nodeEffect, 'effect', '');
            local sNameMod, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeEffect, sName);
            if sName ~= sNameMod then
                if bFirst then
                    sDesc = sDesc .. '<link class=\"item\" recordname=\"' .. DB.getPath(nodeItem) .. '\"><b>' ..
                                UtilityManager.encodeXML(DB.getValue(nodeItem, 'name', '')) .. '[' ..
                                DB.getValue(nodeActor, 'name', '') .. ']' .. '</b></link>'
                    sDesc = sDesc .. '<table><tr><td colspan=\"6\"><b>Advanced Effects (Item)</b></td></tr>';
                    sDesc = sDesc .. '<tr><td  colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b>' ..
                                '</td><td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                    bFirst = false;
                end
                if bWrite then
                    DB.setValue(nodeEffect, 'effect', 'string', sNameMod);
                end
                sDesc = sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(sName) .. '</td><td colspan=\"2\">' ..
                            UtilityManager.encodeXML(sNameMod) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState ..
                            '</td></tr>';
            end
        end
        if not bFirst then
            sDesc = sDesc .. '</table>'
        end
        MigrationManagerBCE.migrateKnK(nodeItem);
    end
end

function migrateKnK(nodeItem)
    local bFirst = true;
    for _, nodePower in pairs(DB.getChildren(nodeItem, 'powers')) do
        for _, nodeAction in pairs(DB.getChildren(nodePower, 'actions')) do
            if DB.getValue(nodeAction, 'type', '') == 'effect' then
                local sName = DB.getValue(nodeAction, 'label', '');
                local sNameMod, sApply, sChangeState = MigrationManagerBCE.migrationHelper(nodeAction, sName);
                if sName ~= sNameMod then
                    if bFirst then
                        sDesc = sDesc .. '<table><tr><td colspan=\"6\"><b>Kit\'N\'Kaboddle</b></td></tr>';
                        sDesc = sDesc .. '<tr><td colspan=\"2\"><b>Original</b></td><td  colspan=\"2\"><b>Modified</b>' ..
                                    '</td><td><b>Apply</b></td><td><b>Change State</b></td></tr>';
                        bFirst = false;
                    end
                    if bWrite then
                        DB.setValue(nodeAction, 'label', 'string', sNameMod);
                    end
                    sDesc = sDesc .. '<tr><td colspan=\"2\">' .. UtilityManager.encodeXML(sName) .. '</td><td colspan=\"2\">' ..
                                UtilityManager.encodeXML(sNameMod) .. '</td><td>' .. sApply .. '</td><td>' .. sChangeState ..
                                '</td></tr>';
                end
            end
        end
    end
    if not bFirst then
        sDesc = sDesc .. '</table>'
    end
end

function migrationHelper(nodeEffect, sName)
    local aEffectComps = EffectManager.parseEffect(sName);
    local sApply = '';
    local sChangeState = '';
    for kEffectComp = #aEffectComps, 1, -1 do
        local sEffectComp = aEffectComps[kEffectComp];
        local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
        rEffectComp.original = StringManager.trim(rEffectComp.original:upper());
        rEffectComp.type = rEffectComp.type:upper();
        if StringManager.contains(aMigrate, rEffectComp.original) or StringManager.contains(aMigrate, rEffectComp.type) then
            local sRetApply, sRetChangeState = MigrationManagerBCE.migrateEffect(nodeEffect, aEffectComps, kEffectComp,
                                                                                 rEffectComp);
            if sRetApply ~= '' then
                sApply = sRetApply;
            end
            if sRetChangeState ~= '' then
                sChangeState = sRetChangeState;
            end

        end
    end
    local sRet = EffectManager.rebuildParsedEffect(aEffectComps);
    if sApply == 'DUSE' then
        sRet = sRet .. ';'
    end
    return sRet, sApply, sChangeState;
end

function migrateEffect(nodeEffect, aEffectComps, index, rEffectComp)
    local sApply = '';
    local sChangeState = ''
    if rEffectComp.original == 'DUSE' or rEffectComp.type == 'DUSE' then
        if bWrite then
            DB.setValue(nodeEffect, 'apply', 'string', 'duse');
        end
        sApply = 'duse';
        table.remove(aEffectComps, index);
    end
    if rEffectComp.original == 'ATURN' or rEffectComp.type == 'ATURN' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'ats');
        end
        sChangeState = 'ats';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'TURNAS' or rEffectComp.type == 'TURNAS' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'as');
        end
        sChangeState = 'as';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'TURNDS' or rEffectComp.type == 'TURNDS' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'ds');
        end
        sChangeState = 'ds';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'TURNRS' or rEffectComp.type == 'TURNRS' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'rs');
        end
        sChangeState = 'rs';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'TURNAE' or rEffectComp.type == 'TURNAE' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'ae');
        end
        sChangeState = 'ae';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'TURNDE' or rEffectComp.type == 'TURNDE' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'de');
        end
        sChangeState = 'de';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'TURNRE' or rEffectComp.type == 'TURNRE' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 're');
        end
        sChangeState = 're';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'STURNRS' or rEffectComp.type == 'STURNRS' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'srs');
        end
        sChangeState = 'srs';
        table.remove(aEffectComps, index);
    elseif rEffectComp.original == 'STURNRE' or rEffectComp.type == 'STURNRE' then
        if bWrite then
            DB.setValue(nodeEffect, 'changestate', 'string', 'sre');
        end
        sChangeState = 'sre';
        table.remove(aEffectComps, index);
        -- elseif rEffectComp.type == 'SSAVEE' or rEffectComp.type == 'SSAVES' or
        -- rEffectComp.type == 'SAVEE' or rEffectComp.type == 'SAVES' or rEffectComp.type ==
        -- 'SAVEONDMG' or rEffectComp.type == 'SAVEA' or rEffectComp.type == 'SAVERESTL' then
        -- if rEffectComp.mod == 0 and (isDiceString(rEffectComp.remainder[1]) or rEffectComp.remainder[1] == '[SDC]') then

        -- end
    end
    return sApply:upper(), sChangeState:upper();
end

function deprecateTagMsg(sTag)
    if sTag and sTag ~= '' then
        local msgData = {
            text = sTag .. ' is deprecated. Use /migrate_effects to migrate BCE effects to new format.',
            font = 'narratorfont',
            icon = 'BetterCombatEffects'
        }
        Comm.addChatMessage(msgData)
    end
end
