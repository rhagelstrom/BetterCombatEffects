--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
-- luacheck: globals BCEManager
OOB_MSGTYPE_BCEACTIVATE = 'activateeffect';
OOB_MSGTYPE_BCEDEACTIVATE = 'deactivateeffect';
OOB_MSGTYPE_BCEREMOVE = 'removeeffect';
OOB_MSGTYPE_BCEUPDATE = 'updateeffect';
OOB_MSGTYPE_BCEADD = 'addeffectbce';

local tExtensions = {};
local tGlobalEffects = {};
local tEffectsLookup = {};

local bDebug = false;

function onInit()
    OptionsManager.registerOption2('DEPRECATE_CHANGE_STATE', false, 'option_Better_Combat_Effects', 'option_Deprecate_Change_State', 'option_entry_cycler',
                                   {labels = 'option_val_on', values = 'on', baselabel = 'option_val_off', baseval = 'off', default = 'off'});
    if Session.IsHost then
        OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEACTIVATE, handleActivateEffect);
        OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEDEACTIVATE, handleDeactivateEffect);
        OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEREMOVE, handleRemoveEffect);
        OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEUPDATE, handleUpdateEffect);
        OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_BCEADD, handleAddEffect);

        BCEManager.initGlobalEffects();
        DB.addHandler('effects', 'onChildAdded', effectAdded);
        Module.onModuleLoad = onModuleLoad;
        Module.onModuleUnload = onModuleUnload;
    end

    tExtensions = BCEManager.getExtensions();
end

function onClose()
    if Session.IsHost then
        BCEManager.removeEffectHandlers();
        CombatManager.removeCustomDeleteCombatantEffectHandler(expireAdd);
    end
end

------------------ DEBUG ------------------
function chat(...)
    if bDebug then
        Debug.chat(...);
    end
end

function console(...)
    if bDebug then
        Debug.console(...);
    end
end
------------------ END DEBUG ------------------

------------------ EXTENSION HELPERS ------------------
function getExtensions()
    local tReturn = {};
    for _, sName in pairs(Extension.getExtensions()) do
        tReturn[sName] = Extension.getExtensionInfo(sName);
    end
    return tReturn;
end

-- Matches on the filname minus the .ext or on the name in defined in the extension.xml
function hasExtension(sName)
    local bReturn = false;

    if tExtensions[sName] then
        bReturn = true;
    else
        for _, tExtension in pairs(tExtensions) do
            if tExtension.name == sName then
                bReturn = true;
                break
            end
        end
    end
    return bReturn;
end
------------------ END EXTENSION HELPERS ------------------

------------------ BINARY SEARCH ------------------
function getEffectName(sLabel)
    local aEffectComps = EffectManager.parseEffect(sLabel:lower());
    if next(aEffectComps) then
        return aEffectComps[1];
    else
        return '';
    end
end

-- function effectAdded(nodeRoot, nodeEffect)
function effectAdded(_, nodeEffect)
    local tSearchEffect = BinarySearchManager.constructSearch(BCEManager.getEffectName(DB.getValue(nodeEffect, 'label', '')), 'insert', DB.getPath(nodeEffect));
    tSearchEffect = BinarySearchManager.binarySearch(tGlobalEffects, tSearchEffect, 1, #tGlobalEffects);
    if not tSearchEffect then
        BCEManager.chat('Problem added effect: ' .. DB.getValue(nodeEffect, 'label', ''));
    else
        addNodeHandlers(tSearchEffect.sPath, tSearchEffect.sName);
    end
end

function effectDeleted(nodeEffect)
    DB.getValue(nodeEffect, 'label', '');
    local tSearchEffect = BinarySearchManager.constructSearch(BCEManager.getEffectName(DB.getValue(nodeEffect, 'label', '')), 'remove', DB.getPath(nodeEffect));
    tSearchEffect = BinarySearchManager.binarySearch(tGlobalEffects, tSearchEffect, 1, #tGlobalEffects);
    if not tSearchEffect then
        BCEManager.chat('Problem deleting effect: ' .. DB.getValue(nodeEffect, 'label', ''));
    else
        tEffectsLookup[tSearchEffect.sPath] = nil;
        BCEManager.removeNodeHandlers(tSearchEffect.sPath);
    end
end

function effectIntegrityChange(nodeEffect)
    BCEManager.chat('Integrity Change for: ', DB.getChild(nodeEffect, 'label'));
    BCEManager.effectUpdated(DB.getChild(nodeEffect, 'label'));
end

-- Updates need a lookup table because we dont' know what the label of the node was prior to change
function effectUpdated(nodeLabel)
    local nodeEffect = DB.getParent(nodeLabel);
    local sPath = DB.getPath(nodeEffect);
    local tSearchEffect = BinarySearchManager.constructSearch(BCEManager.getEffectName(tEffectsLookup[sPath]), 'update', sPath);
    tSearchEffect = BinarySearchManager.binarySearch(tGlobalEffects, tSearchEffect, 1, #tGlobalEffects);
    if not tSearchEffect then
        BCEManager.chat('Problem updating effect: ' .. tEffectsLookup[sPath]);
    else
        tEffectsLookup[sPath] = DB.getValue(nodeEffect, 'label', '');
    end
end

function matchEffect(sEffect)
    local rEffect = {};
    local tSearchEffect = BinarySearchManager.constructSearch(BCEManager.getEffectName(sEffect), 'search');
    tSearchEffect = BinarySearchManager.binarySearch(tGlobalEffects, tSearchEffect, 1, #tGlobalEffects);
    BCEManager.chat('MatchEffect: ', tSearchEffect)
    if tSearchEffect then
        local nodeEffect = DB.findNode(tSearchEffect.sPath);
        if nodeEffect then
            rEffect = EffectManager.getEffect(nodeEffect);
        end
    elseif StringManager.contains(DataCommon.conditions, sEffect:lower()) then
        rEffect.sName = sEffect;
        rEffect.nDuration = 0;
        rEffect.nGMOnly = 0;
        rEffect.sUnits = '';
        rEffect.sApply = '';

    end
    return rEffect;
end

function onModuleLoad(sModule)
    local nodeRoot = DB.getRoot(sModule);
    if nodeRoot then
        BCEManager.chat('Module Load: ' .. sModule)
        for _, nodeEffect in ipairs(DB.getChildList(nodeRoot, 'effects')) do
            BCEManager.effectAdded(nodeRoot, nodeEffect);
        end
    end
end

function onModuleUnload(sModule)
    local nodeRoot = DB.getRoot(sModule);
    if nodeRoot then
        BCEManager.chat('Module Unload: ' .. sModule)
        for _, nodeEffect in ipairs(DB.getChildList(nodeRoot, 'effects')) do
            BCEManager.effectDeleted(nodeEffect);
        end
    end
end

function initGlobalEffects()
    for _, nodeEffect in pairs(DB.getChildrenGlobal('effects')) do
        local tSearchEffect = BinarySearchManager.constructSearch(BCEManager.getEffectName(DB.getValue(nodeEffect, 'label', '')), 'insert',
                                                                  DB.getPath(nodeEffect));
        BinarySearchManager.binarySearch(tGlobalEffects, tSearchEffect, 1, #tGlobalEffects);
    end
    BCEManager.printGlobalEffects();
end

function printGlobalEffects()
    local sOutput = '';
    for _, tSearchEffect in pairs(tGlobalEffects) do
        sOutput = sOutput .. ' | ' .. tSearchEffect.sName;
    end
    BCEManager.chat(sOutput);
end

function removeEffectHandlers()
    for _, tSearchEffect in pairs(tGlobalEffects) do
        BCEManager.removeNodeHandlers(tSearchEffect.sPath);
    end
end

function addNodeHandlers(sPath, sName)
    local node = DB.findNode(sPath);
    tEffectsLookup[sPath] = sName;
    if node then
        local nodeLabel = DB.getChild(node, 'label');
        if nodeLabel then
            local sLabelPath = DB.getPath(DB.getChild(node), 'label');
            DB.addHandler(sLabelPath, 'onUpdate', effectUpdated);
            DB.addHandler(sLabelPath, 'onIntegrityChange', effectUpdated);
        else
            DB.addHandler(sPath, 'onChildAdded', addNodeLabelHandlers);
        end
    end
    DB.addHandler(sPath, 'onDelete', effectDeleted);
end

-- function addNodeLabelHandlers(root, child)
function addNodeLabelHandlers(root, _)
    local nodeLabel = DB.getChild(DB.getPath(root, 'label'));
    if nodeLabel then
        local sLabelPath = DB.getPath(DB.getChild(root), 'label');
        DB.removeHandler(DB.getPath(root), 'onChildAdded', addNodeLabelHandlers);
        DB.addHandler(sLabelPath, 'onUpdate', effectUpdated);
        DB.addHandler(sLabelPath, 'onIntegrityChange', effectUpdated);
    end
end

function removeNodeHandlers(sPath)
    local nodeEffect = DB.findNode(sPath);
    if nodeEffect then
        local nodeLabel = DB.getChild(nodeEffect, 'label');
        if nodeLabel then
            local sLabelPath = DB.getPath(nodeLabel);
            DB.removeHandler(sLabelPath, 'onUpdate', effectUpdated);
            DB.removeHandler(sLabelPath, 'onIntegrityChange', effectUpdated);
        else
            BCEManager.chat('Custom Effect with no label: ' .. sPath);
        end
    end
    DB.removeHandler(sPath, 'onDelete', effectDeleted);
end
------------------ END BINARY SEARCH ------------------

------------------ RULESET MANAGERS ------------------
-- luacheck: globals ActorManager5E
-- luacheck: globals ActorManager4E
-- luacheck: globals ActorManager35E
-- luacheck: globals ActorManager
function getRulesetActorManager()
    local Manager;
    if User.getRulesetName() == '5E' then
        Manager = ActorManager5E;
    elseif User.getRulesetName() == '4E' then
        Manager = ActorManager4E;
    elseif User.getRulesetName() == '3.5E' or User.getRulesetName() == 'PFRPG' then
        Manager = ActorManager35E;
    else
        Manager = ActorManager;
    end
    return Manager;
end

-- luacheck: globals EffectManager5E
-- luacheck: globals EffectManager4E
-- luacheck: globals EffectManager35E
-- luacheck: globals EffectManager
function getRulesetEffectManager()
    local Manager;
    if User.getRulesetName() == '5E' then
        Manager = EffectManager5E;
    elseif User.getRulesetName() == '4E' then
        Manager = EffectManager4E;
    elseif User.getRulesetName() == '3.5E' or User.getRulesetName() == 'PFRPG' then
        Manager = EffectManager35E;
    else
        Manager = EffectManager;
    end
    return Manager;
end
------------------ END RULESET MANAGERS ------------------

------------------ EFFECT STATE CHANGE OOB ------------------

function notifyAddEffect(nodeTarget, nodeSource, sLabel)
    local msgOOB = {};
    msgOOB.type = OOB_MSGTYPE_BCEADD;
    msgOOB.sSource = DB.getPath(nodeSource);
    msgOOB.sTarget = DB.getPath(nodeTarget);
    msgOOB.sLabel = sLabel;
    if Session.IsHost then
        BCEManager.handleAddEffect(msgOOB);
    else
        Comm.deliverOOBMessage(msgOOB, '');
    end
end

function modifyEffect(sNodeEffect, sAction, sEffect)
    -- Must be database node, if not it is probably marked for deletion from one-shot
    local nodeEffect;
    if type(sNodeEffect) == 'databasenode' then
        nodeEffect = sNodeEffect;
    else
        nodeEffect = DB.findNode(sNodeEffect);
    end

    if not nodeEffect or type(nodeEffect) ~= 'databasenode' then
        return;
    end

    local sOOB = '';
    local nActive = DB.getValue(nodeEffect, 'isactive', 0);

    if sAction == 'Activate' and nActive ~= 1 then
        sOOB = OOB_MSGTYPE_BCEACTIVATE;
    elseif sAction == 'Deactivate' and nActive ~= 0 then
        sOOB = OOB_MSGTYPE_BCEDEACTIVATE;
    elseif sAction == 'Remove' then
        sOOB = OOB_MSGTYPE_BCEREMOVE;
    elseif sAction == 'Update' then
        sOOB = OOB_MSGTYPE_BCEUPDATE;
    end

    if sOOB ~= '' then
        BCEManager.sendOOB(nodeEffect, sOOB, sEffect);
    end
end

-- CoreRPG has no function to activate effect. If it did it would likely look this this
function activateEffect(nodeActor, nodeEffect)
    if not nodeEffect then
        return true;
    end
    local sEffect = DB.getValue(nodeEffect, 'label', '');
    local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
    DB.setValue(nodeEffect, 'isactive', 'number', 1);
    local sMessage = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), sEffect, Interface.getString('effect_status_activated'));
    EffectManager.message(sMessage, nodeActor, bGMOnly);
end

function updateEffect(nodeActor, nodeEffect, sLabel)
    if not nodeEffect then
        return true;
    end
    local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
    local sMessage = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), sLabel, Interface.getString('effect_status_updated'));
    DB.setValue(nodeEffect, 'label', 'string', sLabel);
    EffectManager.message(sMessage, nodeActor, bGMOnly);
end

function handleActivateEffect(msgOOB)
    if not handlerCheck(msgOOB) then
        local nodeActor = DB.findNode(msgOOB.sNodeActor);
        local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
        BCEManager.activateEffect(nodeActor, nodeEffect);
    end
end

function handleAddEffect(msgOOB)
    local rEffect = BCEManager.matchEffect(msgOOB.sLabel);
    if next(rEffect) then
        local nodeTarget = DB.findNode(msgOOB.sTarget);
        local nodeSource = DB.findNode(msgOOB.sSource);
        if msgOOB.sTarget ~= msgOOB.sSource then
            rEffect.sSource = msgOOB.sSource;
            rEffect.nInit = DB.getValue(nodeSource, 'initresult', 0)
        else
            rEffect.nInit = DB.getValue(nodeTarget, 'initresult', 0)
        end
        if not ActorManager.isPC(nodeSource) then
            rEffect.nGMOnly = 1;
        end
        if nodeTarget then
            EffectManager.addEffect('', '', nodeTarget, rEffect, true);
        end
    end
end

function handleDeactivateEffect(msgOOB)
    if not handlerCheck(msgOOB) then
        local nodeActor = DB.findNode(msgOOB.sNodeActor);
        local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
        EffectManager.deactivateEffect(nodeActor, nodeEffect);
    end
end

function handleRemoveEffect(msgOOB)
    if not handlerCheck(msgOOB) then
        local nodeActor = DB.findNode(msgOOB.sNodeActor);
        local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
        EffectManager.expireEffect(nodeActor, nodeEffect, 0);
    end
end

function handleUpdateEffect(msgOOB)
    if not handlerCheck(msgOOB) then
        local nodeActor = DB.findNode(msgOOB.sNodeActor);
        local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
        BCEManager.updateEffect(nodeActor, nodeEffect, msgOOB.sLabel);
    end
end

function handlerCheck(msgOOB)
    local nodeActor = DB.findNode(msgOOB.sNodeActor);
    if not nodeActor then
        ChatManager.SystemMessage(Interface.getString('ct_error_effectmissingactor') .. ' (' .. msgOOB.sNodeActor .. ')');
        return true;
    end
    local nodeEffect = DB.findNode(msgOOB.sNodeEffect);
    if not nodeEffect then
        ChatManager.SystemMessage(Interface.getString('ct_error_effectdeletefail') .. ' (' .. msgOOB.sNodeEffect .. ')');
        return true;
    end
    return false;
end

function sendOOB(nodeEffect, type, sEffect)
    local msgOOB = {};

    msgOOB.type = type;
    msgOOB.sNodeActor = DB.getPath(DB.getChild(nodeEffect, '...'));
    msgOOB.sNodeEffect = DB.getPath(nodeEffect);
    if type == OOB_MSGTYPE_BCEUPDATE then
        msgOOB.sLabel = sEffect;
    end
    BCEManager.chat('Send OOB: ', msgOOB);
    if Session.IsHost then
        if msgOOB.type == OOB_MSGTYPE_BCEACTIVATE then
            BCEManager.handleActivateEffect(msgOOB);
        elseif msgOOB.type == OOB_MSGTYPE_BCEDEACTIVATE then
            BCEManager.handleDeactivateEffect(msgOOB);
        elseif msgOOB.type == OOB_MSGTYPE_BCEREMOVE then
            BCEManager.handleRemoveEffect(msgOOB);
        elseif msgOOB.type == OOB_MSGTYPE_BCEUPDATE then
            BCEManager.handleUpdateEffect(msgOOB);
        elseif msgOOB.type == OOB_MSGTYPE_BCEADD then
            BCEManager.handleAddEffect(msgOOB);
        end
    else
        Comm.deliverOOBMessage(msgOOB, '');
    end
end
------------------ END EFFECT STATE CHANGE OOB ------------------
