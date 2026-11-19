local V=require 'CSV/Core'
local T=require 'CSV/ShelterThump'
local seen=setmetatable({},{__mode='k'})

local function enqueue(p,x,y,z,north)
 if not V.config.enabled or not p or not p:isLocalPlayer() or not T.near(p,x,y,z,north,T.square) then return end
 local voice=V.voice(p)
 if not voice or not V.extended(voice) or not V.languageSupported() then return end
 if not T.first(seen,p,x,y,z,north,V.now()) then return end
 if not (V.clip(voice,'ShelterThump_1') or V.clip(voice,'ShelterThump_2') or V.clip(voice,'ShelterThump_3')) then return end
 require('CSV/Outcomes').queue({kind='shelter_thump',player=p,verified=true,completed=true,
  x=x,y=y,z=z,north=north},'ShelterThump')
end

local function observe(x,y,z,radius,volume,source)
 local ox,oy,oz,north=T.impact(x,y,z,radius,volume,source)
 if not ox then return end
 for i=0,getNumActivePlayers()-1 do enqueue(getSpecificPlayer(i),ox,oy,oz,north) end
end

local function receive(module,command,data)
 if module~='CSV' or command~='shelterThump' or type(data)~='table' then return end
 for i=0,getNumActivePlayers()-1 do
  local p=getSpecificPlayer(i)
  if p and p:getOnlineID()==data.playerId then enqueue(p,data.x,data.y,data.z,data.north);return end
 end
end

local O={}
function O.install()
 require('CSV/Connections').install('shelter-thump',function(t)
  if Events.OnWorldSound then t:event(Events.OnWorldSound,observe) end
  if isClient() then t:event(Events.OnServerCommand,receive) end
 end)
end

return O
