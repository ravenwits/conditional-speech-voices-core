local T={players=setmetatable({},{__mode='k'}),nextScan=0}
local V=require 'CSV/Core'
local S=require 'CSV/State'
local Speech=require 'ConditionalSpeech_Core'
local Trace=require 'CSV/Trace'
-- One local observation per second; source cooldowns and phrase disables still apply.
function T.observe(player,facts)
 if not player or not player:isLocalPlayer() or player:isDead() or not V.voice(player) then return end
 if require('CSV/VehicleCombat').ownsThreat(player) then return end
 local now=V.now();local state=T.players[player] or {nextAttempt=0};T.players[player]=state
 local s=facts or S.capture(player)
 local encounter=require 'CSV/Encounter'
 encounter.observe(player,s)
 if s.encounterThreat==false then state.phase=nil;state.delivery=nil;state.nextAttempt=0 end
 if encounter.blocked(player,'Threat',s) then Trace.block(state,player,'Threat','threat_observer','encounter_already_reacted',s);return end
 local concealment=require 'CSV/Concealment';local engaged=concealment.active(s)
 local escalation=engaged and state.delivery~='engaged'
 local function blocked(reason)
  if reason~='no_nearby_threat' or state.phase then Trace.block(state,player,(s.panic or 0)>=3 and 'Panic' or 'Threat','threat_observer',reason,s)end
  if s.sneaking==true then require('CSV/ProductionReport').observe('whisper_block_'..reason,s)end
 end
 require('CSV/ProductionReport').observe('threat_'..require('CSV/ThreatEvidence').kind(s),s)
 if s.near==0 and not engaged then
  blocked('no_nearby_threat')
  state.clearSince=state.clearSince or now
  if s.visible==0 and s.recentThreat==false then state.phase=nil;state.delivery=nil;state.nextAttempt=0 end
  return
 end
 if s.near==nil and not engaged then blocked('unknown_distance');return end
 state.clearSince=nil
 if s.fire==true then blocked('fire_priority');return end
 local whisper=s.sneaking==true and not engaged and not concealment.open(s) and V.client.preferences().whisper and require('CSV/Extras').pick(V,V.voice(player),'ThreatWhisper')
 if s.sneaking~=false and not whisper and not engaged and not concealment.open(s) then blocked('disabled_or_no_recording');return end
 if (s.accessibleNear or s.near)==0 and not engaged then blocked('adjacent_barrier');return end
 if not Speech.enabledPhraseSet('Panic') then blocked('panic_group_disabled');return end
 local group
 if type(s.panic)=='number' and s.panic<3 then group='Threat' elseif (s.panic or 0)>=3 then group='Panic' else blocked('panic_unknown');return end
 local C=V.client
 local kind=require('CSV/ThreatEvidence').kind(s)
 if (kind=='observed_only' or kind=='blocked') and group=='Panic' and not engaged then blocked('no_active_threat');return end
 local phase=group=='Threat' and (s.panic==0 and 'calm' or 'tense') or 'high'
 local delivery=engaged and 'engaged' or whisper and 'whisper' or 'spoken'
 if state.delivery==delivery and (state.phase==phase or state.phase=='high') then blocked('already_reacted');return end
 if not escalation and now<state.nextAttempt then blocked('observer_retry_cooldown');return end
 for _,active in ipairs(C.active)do if active.player==player and (active.preview or (group~='Panic' and not engaged) or (active.priority or 1)>=3) then blocked('already_speaking');return end end
 state.nextAttempt=now+5000
 state.traceBlock=nil
 local trace=Trace.begin(player,group,'threat_observer',s)
 Trace.call(trace,player,Speech.generateSpeechFrom,player,group,math.max(1,s.panic or 0),4,false,true)
 if C.lastThreat[player] and C.lastThreat[player]>=now then state.phase=phase;state.delivery=delivery end
end
function T.tick()
 local now=V.now();if now<T.nextScan then return end;T.nextScan=now+1000
 for i=0,getNumActivePlayers()-1 do T.observe(getSpecificPlayer(i)) end
end
return T
