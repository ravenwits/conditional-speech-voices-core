local Packet={}
local version=1
local sequenceLimit=2147483647

local function packet(V,player,voice,line,seq,radius,pitch)
    local bank=V.bank(voice)
    return {version=version,pack=bank.id,packRevision=bank.revision,
        actor=math.max(0,player:getOnlineID()),seq=seq,line=line,voice=voice,
        pitch=pitch or V.pitch(player),radius=radius}
end

function Packet.forPlayback(V,client,player,voice,line,radius,pitch)
    client.sequence=client.sequence+1
    if client.sequence>=sequenceLimit then client.sequence=1 end
    return packet(V,player,voice,line,client.sequence,radius,pitch)
end

-- The server supplies the authenticated actor after accepting the request.
function Packet.forRelay(V,player,request,priority)
    local out=packet(V,player,V.voice(player),request.line,request.seq,math.min(25,request.radius))
    out.priority=priority
    out.allowStealth=request.allowStealth==true and V.allowStealth(request.line)
    out.exposed=request.exposed==true
    out.engaged=request.engaged==true
    return out
end

function Packet.valid(V,p)
    if type(p)~='table' or type(p.voice)~='string' then return false end
    local bank=V.pack.voiceBanks[p.voice]
    return bank~=nil and p.version==version and (p.pack==nil and p.packRevision==nil or p.pack==bank.id and p.packRevision==bank.revision) and V.clip(p.voice,p.line)~=nil
        and V.finite(p.actor) and p.actor>=0 and p.actor%1==0
        and V.finite(p.seq) and p.seq>=1 and p.seq<sequenceLimit and p.seq%1==0
        and V.finite(p.radius) and p.radius>0 and p.radius<=V.config.maxDistance
        and V.finite(p.pitch) and p.pitch>=-100 and p.pitch<=100
end
return Packet
