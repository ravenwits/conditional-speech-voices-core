local R={players=setmetatable({},{__mode='k'}),nextScan=0}
local V=require 'CSV/Core'
local State=require 'CSV/State'
local Speech=require 'ConditionalSpeech_Core'
local Trace=require 'CSV/Trace'
function R.transitions(before,after)
 local events={};if not before then return events end
 for group,rule in pairs(require('CSV/RecoveryRules'))do
  if type(before[rule.field])=='number' and before[rule.field]>=rule.threshold and after[rule.field]==0 then events[#events+1]=group end
 end
 table.sort(events)
 return events
end
function R.observe(player,s)
 if not player or not player:isLocalPlayer() or player:isDead() or not V.voice(player) then return end
 s=s or State.capture(player)
 local now=V.now();local state=R.players[player] or {pending={}};R.players[player]=state
 state.peaks=state.peaks or {}
 for _,rule in pairs(require('CSV/RecoveryRules'))do
  local key=rule.field
  if type(s[key])=='number' then state.peaks[key]=math.max(state.peaks[key] or 0,s[key]) end
 end
 for _,group in ipairs(R.transitions(state.peaks,s))do if state.pending[group] then Trace.step(state.pending[group].trace,'cancelled','superseded_transition')end;state.pending[group]={at=now,trace=Trace.begin(player,group,'need_recovered',s)};local field=require('CSV/RecoveryRules')[group].field;if field then Trace.step(state.pending[group].trace,'transition','need_recovered',{field=field,before=state.peaks[field],after=s[field]});state.peaks[field]=0 end;require('CSV/ProductionReport').observe('before_'..group,state.before);require('CSV/ProductionReport').observe('transition_'..group,s) end
 if (s.near or 0)>0 then state.hadThreat=true;state.clearAt=nil
 elseif require('CSV/Safety').clear(s) then
  -- State already retains recentThreat for ten seconds after zombies disappear.
  -- Count the same clear interval here, not a second interval after it expires.
  state.clearAt=state.clearAt or now
  if state.hadThreat and s.recentThreat==false and now-state.clearAt>=10000 then state.pending.ReliefThreat={at=now,trace=Trace.begin(player,'ReliefThreat','threat_cleared',s)};state.hadThreat=false;require('CSV/ProductionReport').observe('transition_ReliefThreat',s) end
 else state.clearAt=nil end
 state.before=s
 local pending={};for group in pairs(state.pending)do pending[#pending+1]=group end
 local priority={ReliefBleeding=10,ReliefPain=9,ReliefThirst=8,ReliefHunger=7,ReliefThreat=6,ReliefEndurance=5,ReliefRest=4}
 table.sort(pending,function(a,b)
  local x,y=state.pending[a].at,state.pending[b].at
  if x~=y then return x>y end
  if (priority[a] or 1)~=(priority[b] or 1) then return (priority[a] or 1)>(priority[b] or 1)end
  return a<b
 end)
 for _,group in ipairs(pending)do
  local event=state.pending[group]
  -- Invalidate on every observation, including danger/concealment. Otherwise a need
  -- can return and disappear before the queue is eligible and revive an old relief.
  local rule=require('CSV/RecoveryRules')[group]
  local renewed=group=='ReliefThreat' and not require('CSV/Safety').settled(s)
   or rule and type(s[rule.field])=='number' and s[rule.field]>0
  local pendingStatus=require('CSV/Pending').status(now,not renewed,event.at+12000,state.nextAttempt)
  if pendingStatus=='cancelled' then Trace.step(event.trace,'cancelled','condition_returned');state.pending[group]=nil;require('CSV/ProductionReport').observe('cancelled_'..group,s)
  elseif pendingStatus=='expired' then Trace.step(event.trace,'expired','relief_window_elapsed');state.pending[group]=nil;require('CSV/ProductionReport').observe('expired_'..group,s)
  elseif (s.sneaking==false or (s.sneaking==true and V.client.preferences().whisper and V.extended(V.voice(player)))) and require('CSV/Safety').settled(s) and pendingStatus=='ready' then
   -- Recheck the healed condition. A queued relief must not survive renewed injury/thirst.
   local valid=group=='ReliefThreat' or (rule and s[rule.field]==0)
   if not valid then Trace.step(event.trace,'cancelled','recovery_not_confirmed');state.pending[group]=nil
   elseif require('CSV/Extras').pick(V,V.voice(player),group) then
    state.nextAttempt=now+5000
    Trace.call(event.trace,player,Speech.generateSpeechFrom,player,group,1,1,false,false)
    local attempt=V.client.lastAttempt[player]
    if require('CSV/Pending').accepted(attempt,group) then
     state.pending[group]=nil
     for other,queued in pairs(state.pending)do
      if queued.at==event.at then Trace.step(queued.trace,'cancelled','simultaneous_recovery_represented',{by=group});state.pending[other]=nil end
     end
    end
    break
   elseif not event.reported then
    Trace.step(event.trace,'waiting','no_eligible_recording');event.reported=true;V.client.debug.record('gameplay',group,require('CSV/Extras').approved and 'no_eligible_recording' or 'recording_awaiting_approval',{voice=V.voice(player),facts=s,intensity=1})
   end
  else
   local reason=not require('CSV/Safety').settled(s) and 'safety_not_confirmed' or now<(state.nextAttempt or 0) and 'observer_retry_cooldown' or 'concealment'
   Trace.step(event.trace,'waiting',reason)
  end
 end
end
function R.tick()
 local now=V.now();if now<R.nextScan then return end;R.nextScan=now+1000
 for i=0,getNumActivePlayers()-1 do R.observe(getSpecificPlayer(i)) end
end
function R.damage(player,kind,amount)
 return require('CSV/Injury').signal(player,kind,amount)
end
function R.onDamage(...)
 local ok,err=pcall(R.damage,...)
 if not ok then
  R.damageErrors=(R.damageErrors or 0)+1;R.lastDamageError=tostring(err)
  if V.client then V.client.errors=V.client.errors+1 end
  if R.damageErrors<=5 then print('[CSV] damage callback error '..R.lastDamageError) end
 end
end
if Events.OnPlayerGetDamage then Events.OnPlayerGetDamage.Add(R.onDamage) end
return R
