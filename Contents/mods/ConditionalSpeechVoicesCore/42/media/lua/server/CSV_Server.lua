local V=require 'CSV/Core'
local S={last=setmetatable({},{__mode='k'})}
function S.receive(module,command,player,p)
    if module~='CSV' or not V.config.enabled then return false end
    if command=='stop' then
        if not player or type(p)~='table' or p.actor~=player:getOnlineID() then return false end
        local prior=S.last[player]
        if not prior or prior.seq~=p.seq or prior.stopped then return false end
        prior.stopped=true
        local players=getOnlinePlayers()
        for i=0,players:size()-1 do local listener=players:get(i)
            if listener then sendServerCommand(listener,'CSV','stop',{actor=p.actor,seq=p.seq}) end
        end
        return true
    end
    if command~='speak' then return false end
    if not player or player:isDead() or not V.validPacket(p) then return false end
    if player:getOnlineID()~=p.actor or V.voice(player)~=p.voice then return false end
    if require('CSV/Actors').call(player,'isSneaking')==true and not V.allowStealth(p.line) and p.exposed~=true and p.engaged~=true then return false end
    if p.engaged==true and (p.radius>12 or V.maxPriority(p.line)<2 or not require('CSV/Concealment').active(require('CSV/State').capture(player))) then return false end
    if p.exposed==true and (p.radius>require('CSV/Hearing').quietRadius or not require('CSV/Concealment').open(require('CSV/State').capture(player))) then return false end
    local now=V.now()
    local previous=S.last[player]
    local priority=V.packetPriority(p)
    if previous and p.seq<previous.seq and not (previous.seq>2147483000 and p.seq<1000) then return false end
    if previous and (p.seq==previous.seq or (now-previous.at<1500 and not (priority>=3 and priority>(previous.priority or 1) and (now-previous.at>=200 or previous.stopped)))) then return false end
    S.last[player]={at=now,seq=p.seq,priority=priority}
    -- Use the authenticated player's position/voice/pitch, never client coordinates or sound names.
    local out={version=1,pack=V.pack.id,packRevision=V.pack.revision,actor=player:getOnlineID(),seq=p.seq,line=p.line,
        voice=V.voice(player),pitch=V.pitch(player),radius=math.min(25,p.radius),priority=priority,allowStealth=p.allowStealth==true and V.allowStealth(p.line),exposed=p.exposed==true,engaged=p.engaged==true}
    local players=getOnlinePlayers()
    for i=0,players:size()-1 do
        local listener=players:get(i)
        if listener and not listener:isDead() and V.near(listener,player,out.radius) then
            sendServerCommand(listener,'CSV','play',out)
        end
    end
    return true
end
Events.OnClientCommand.Add(function(...)
    local ok,err=pcall(S.receive,...)
    if not ok then print('[CSV] Rejected playback request: '..tostring(err)) end
end)
return S
