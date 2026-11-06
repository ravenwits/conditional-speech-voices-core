local A={players=setmetatable({},{__mode='k'})}
local V=require 'CSV/Core'
local S=require 'CSV/State'
local E=require 'CSV/Encounter'
local Trace=require 'CSV/Trace'
function A.observe(p)
 if not p or not p:isLocalPlayer() or p:isDead() or not V.extended(V.voice(p)) then return end
 local state=A.players[p] or {};A.players[p]=state
 local ok,playing=pcall(function()return p:getEmitter():isPlaying('ZombieSurprisedPlayer')end)
 if not ok or type(playing)~='boolean' then
  if not state.unavailable then Trace.block(state,p,'Startle','native_alert_probe','native_alert_unavailable',{});state.unavailable=true;require('CSV/ProductionReport').observe('native_alert_unavailable',{})end
  return
 end
 E.sound(p,playing)
 local rising=playing and state.playing~=true;state.playing=playing
 if not rising then return end
 S.nativeAlert=S.nativeAlert or setmetatable({},{__mode='k'});S.nativeAlert[p]=true
 local facts=S.capture(p)
 require('CSV/ProductionReport').observe('native_alert_onset',facts)
 local trace=Trace.begin(p,'Startle','native_alert_onset',facts)
 local success,err=pcall(Trace.call,trace,p,require('ConditionalSpeech_Core').generateSpeechFrom,p,'Startle',1,1,false,false)
 S.nativeAlert[p]=nil
 if not success then error(err)end
end
function A.tick()
 -- One emitter query per local player; no additional world scan when no onset occurs.
 for i=0,getNumActivePlayers()-1 do A.observe(getSpecificPlayer(i))end
end
return A
