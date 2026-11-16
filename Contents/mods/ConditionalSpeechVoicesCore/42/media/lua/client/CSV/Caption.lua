local Caption={}

function Caption.renderDebug(C,player,recording,volume)
    if not C.debugEnabled or not C.debugEnabled() or not player.addLineChatElement
        or type(recording)~='string' or not recording:match('^[A-Za-z][A-Za-z0-9_]*$') then return end
    -- Dialogue is the game's bold bitmap font. Use the chat API's own RGB and
    -- font arguments for the label, then let the caller render speech normally.
    player:addLineChatElement(recording,1,0.25,0.25,UIFont.Dialogue,volume,'default',false,false,false,false,false,true)
end

return Caption
