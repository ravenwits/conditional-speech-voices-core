local D={players=setmetatable({},{__mode='k'}),nextTick=0}
local V=require 'CSV/Core'
local function number(value)return type(value)=='number' and value==value end
function D.snapshot(player)
 local square=player:getSquare()
 if not square then return {} end
 local light=square:getLightLevel(player:getPlayerNum())
 local torch=player:getTorchStrength()
 if not number(light) or not number(torch) then return {} end
 light=math.max(light,math.min(1,torch))
 if square:isOutside() then
  local daylight=getClimateManager():getDayLightStrength()
  if not number(daylight) then return {} end
  light=math.max(light,daylight)
 end
 return {light=light,awake=not player:isAsleep()}
end
function D.advance(state,facts,now)
 if not facts.awake or not number(facts.light) then state.darkSince=nil;state.brightSince=nil;return false end
 if facts.light>=.35 then
  state.darkSince=nil;state.brightSince=state.brightSince or now
  if now-state.brightSince>=10000 then state.announced=false end
  return false
 end
 state.brightSince=nil
 if facts.light>.18 then state.darkSince=nil;return false end
 state.darkSince=state.darkSince or now
 return not state.announced and now-state.darkSince>=5000 and (not state.lastQueued or now-state.lastQueued>=300000)
end
function D.tick()
 local now=V.now();if now<D.nextTick then return end;D.nextTick=now+1000
 for i=0,getNumActivePlayers()-1 do
  local player=getSpecificPlayer(i)
  if player and player:isLocalPlayer() and not player:isDead() and V.extended(V.voice(player)) then
   local state=D.players[player] or {};D.players[player]=state
   local facts=D.snapshot(player)
   if D.advance(state,facts,now) then
    local event={kind='darkness',player=player,obj=player,completed=true,before={},after=facts}
    if require('CSV/Outcomes').queue(event,'Darkness') then state.announced=true;state.lastQueued=now end
   end
  end
 end
end
return D
