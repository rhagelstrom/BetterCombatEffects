-- luacheck: globals setValue

function onInit()
    local sText = 'Migrate campaign effects to Better Combat Effects Change State format.<p></p><b><u>WARNING:</u></b> ' ..
     'This is a destructive operation with no undo. Back up your data before you proceed.<p></p>' ..
     'It is <b>highly suggested</b> you run a preview first to verify the proposed changes.\r\r';
    setValue(sText);
end