if not isServer() or not Events.OnWorldSound then return end
local V=require 'CSV/Core'
local T=require 'CSV/ShelterThump'

Events.OnWorldSound.Add(function(x,y,z,radius,volume,source)
 if not V.config.enabled then return end
 local ox,oy,oz,north=T.impact(x,y,z,radius,volume,source,T.square)
 if not ox then return end
 local players=getOnlinePlayers()
 for i=0,players:size()-1 do
  local p=players:get(i)
  if T.near(p,ox,oy,oz,north,T.square) then
   sendServerCommand(p,'CSV','shelterThump',{playerId=p:getOnlineID(),x=ox,y=oy,z=oz,north=north})
  end
 end
end)
