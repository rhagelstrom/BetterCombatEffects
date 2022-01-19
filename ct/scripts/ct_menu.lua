function onInit()
	if super and super.onInit then
		super.onInit();
	end
    if Session.IsHost then
        registerMenuItem("Re-parse Traits for ADV/DIS vs Condition", "shuffle", 6);
	end
end

function onClickDown(button, x, y)
    if super and super.onClickDown then
		 return super.onClickDown(button, x, y);
	end
end

function onClickRelease(button, x, y)
    if super and super.onClickRelease then
		return super.onClickRelease(button, x, y);
	end
end

function onMenuSelection(selection, subselection, subsubselection)
    if super and super.onMenuSelection then
		super.onMenuSelection(selection, subselection, subsubselection);
	end
    if Session.IsHost then
        if selection == 6 then
            EffectsManagerBCE5E.initTraitTables()
            local msg = {font = "narratorfont", icon = "BetterCombatEffectsGold"};
		    msg.text = "[ Traits Re-parsed for CT Actors ] ";
            msg.secret = true
            Comm.addChatMessage(msg);
        end
    end
end

function clearNPCs(bDeleteOnlyFoe)
    if super and super.clearNPCs then
		super.clearNPCs(bDeleteOnlyFoe);
	end
end
