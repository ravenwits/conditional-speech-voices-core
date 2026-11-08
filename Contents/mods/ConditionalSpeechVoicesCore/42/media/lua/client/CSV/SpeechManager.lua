-- All gameplay requests enter here. Observation histories remain with their owners;
-- this is the only queue allowed to dispatch speech.
local M={enabled=false,dispatching=false,queue={},serial=0,metrics={submitted=0,played=0,expired=0,cancelled=0,blocked=0}}
local V=require 'CSV/Core'
local S=require 'CSV/State'
local A=require 'CSV/Actors'
local function report(e,reason)
 require('CSV/Trace').step(e.trace,'manager',reason,{group=e.group})
end
local function contexts(e,fn)
 local p=e.player;local psychology=require('CSV/Psychology');local injury=require('CSV/Injury')
 S.outcome=S.outcome or {};S.loot=S.loot or {};S.nativeAlert=S.nativeAlert or {}
 local a,b,c,d,f=S.outcome[p],S.loot[p],S.nativeAlert[p],psychology.context[p],injury.context[p]
 S.outcome[p]=e.outcome;S.loot[p]=e.loot;S.nativeAlert[p]=e.alert;psychology.context[p]=e.psychology;injury.context[p]=e.injury
 S.reload=S.reload or {};local savedReload=S.reload[p];S.reload[p]=e.reload
 local result={pcall(fn)}
 S.outcome[p]=a;S.loot[p]=b;S.nativeAlert[p]=c;psychology.context[p]=d;injury.context[p]=f
 S.reload[p]=savedReload
 if not result[1] then error(result[2])end
 return unpack(result,2)
end
function M.submit(fn,p,g,i,max,args)
 local recovery=require('CSV/Recovery').players[p];local loot=require('CSV/Loot').players[p]
 local outcome=S.outcome and S.outcome[p];local psych=require('CSV/Psychology').context[p]
 local injury=require('CSV/Injury').context[p]
 local reload=S.reload and S.reload[p]
 local healthEvent=g=='Injured' and require('CSV/CriticalHealth').pending(p)
 local token=healthEvent or reload or outcome or psych or injury or recovery and recovery.pending[g] or loot and loot.pending[g] or g
 for _,old in ipairs(M.queue)do if old.player==p and old.token==token then return end end
 M.serial=M.serial+1
 local now=V.now();local event={player=p,group=g,intensity=i,maximum=max,args=args,fn=fn,token=token,at=now,serial=M.serial,
 healthEvent=healthEvent,reload=reload,outcome=outcome,psychology=psych,injury=injury,alert=S.nativeAlert and S.nativeAlert[p],loot=S.loot and S.loot[p],
 recovery=recovery and recovery.pending[g],lootEvent=loot and loot.pending[g],trace=require('CSV/Trace').request(p,g)}
 if g=='GunJammed' or g=='OutOfAmmo' then event.firearm=A.call(p,'getPrimaryHandItem')end
 event.expires=healthEvent and healthEvent.expires or outcome and outcome.expires or event.recovery and event.recovery.at+12000 or event.lootEvent and event.lootEvent.at+90000 or psych and psych.at+(require('CSV/PsychologyRules').defer(psych) and require('CSV/PsychologyPolicy').aftermathLifetime or require('CSV/PsychologyPolicy').eventLifetime) or now+(g=='AcutePain' and 1000 or g=='Startle' and 1500 or psych and 8000 or 2000)
 if #M.queue>=128 then M.metrics.cancelled=M.metrics.cancelled+1;report(event,'queue_full');return end
 M.queue[#M.queue+1]=event;M.metrics.submitted=M.metrics.submitted+1
 V.client.lastAttempt[p]={group=g,outcome='manager_pending'};report(event,'submitted')
end
function M.valid(e)
 local p=e.player
 if not V.config.enabled or not V.languageSupported() or A.call(p,'isDead')~=false or A.call(p,'isLocalPlayer')~=true then return false end
 if e.healthEvent and not require('CSV/CriticalHealth').valid(p,e.healthEvent,S.capture(p)) then return false end
 if e.group=='Threat' or e.group=='Panic' or e.group=='PanicCallback' then
  local f=S.capture(p)
  if e.healthEvent and not require('CSV/CriticalHealth').valid(p,e.healthEvent,S.capture(p)) then return false end
 if e.group=='Threat' and not ((f.near or 0)>0 or require('CSV/Concealment').active(f)) then e.invalidReason='threat_cleared';return false end
  if require('CSV/Encounter').blocked(p,e.group,f) then e.invalidReason='encounter_already_reacted';return false end
 end
 if e.group=='GunJammed' or e.group=='OutOfAmmo' then
  if e.firearm and A.call(p,'getPrimaryHandItem')~=e.firearm then return false end
  local facts=S.capture(p)
  if e.group=='GunJammed' and facts.jammed==false or e.group=='OutOfAmmo' and facts.empty==false then return false end
 end
 if e.reload then return require('CSV/Reload').valid(e.reload) and require('CSV/ReloadRules').group(S.capture(p))==e.group end
 if e.outcome then e.outcome.after=require('CSV/Outcomes').snapshot(e.outcome.kind,e.outcome.obj,p);return not e.outcome.consumed and not e.outcome.cancelled and require('CSV/Outcomes').valid(e.outcome) and require('CSV/OutcomeRules').classify(e.outcome)==e.group end
 if e.psychology then
  if e.psychology.consumed then return false end
  local owner=require('CSV/Psychology').players[p];if not owner then return false end
  for _,q in ipairs(owner.queue)do if q==e.psychology then return true end end;return false
 end
 if e.recovery then
  local owner=require('CSV/Recovery').players[p];local rule=require('CSV/RecoveryRules')[e.group];local f=S.capture(p)
  return owner and owner.pending[e.group]==e.recovery and (rule and f[rule.field]==0 or e.group=='ReliefThreat' and require('CSV/Safety').settled(f))
 end
 if e.lootEvent then
  local owner=require('CSV/Loot').players[p]
  if not owner or owner.pending[e.group]~=e.lootEvent then return false end
  e.loot=require('CSV/Loot').snapshot(p,e.lootEvent.item)
  return require('CSV/LootRules').classify(e.loot)==e.group
 end
 return true
end
function M.accept(e)
 local p=e.player;local now=V.now()
 if e.healthEvent then require('CSV/CriticalHealth').accept(p,e.healthEvent) end
 if e.reload then e.reload.consumed=true end
 if e.outcome then
  e.outcome.consumed=true
  local o=require('CSV/Outcomes');local owner=o.players[p]
  if owner then owner.last[e.group]=now;owner.lastAny=now end
  if e.outcome.kind=='vehicle_combat' then require('CSV/VehicleCombat').accepted(e.outcome)end
 elseif e.psychology then
  e.psychology.consumed=true;local owner=require('CSV/Psychology').players[p]
  if owner then owner.last[e.psychology.kind]=now;for i=#owner.queue,1,-1 do if owner.queue[i]==e.psychology then table.remove(owner.queue,i)end end end
 elseif e.recovery then
  local owner=require('CSV/Recovery').players[p]
  if owner then for g,q in pairs(owner.pending)do if q.at==e.recovery.at then owner.pending[g]=nil end end end
 elseif e.lootEvent then
  local owner=require('CSV/Loot').players[p];if owner and owner.pending[e.group]==e.lootEvent then owner.pending[e.group]=nil;owner.last[e.group]=now end
 end
end
function M.flush()
 if not M.enabled then return end
 local candidates={};local now=V.now()
 for i=#M.queue,1,-1 do
  local e=M.queue[i]
  if e.playback and not e.playback.finishedReason then
   -- Reserved: no duplicate dispatch while the engine is starting or playing.
  elseif now>e.expires or not M.valid(e) then
   local why=now>e.expires and 'expired' or 'cancelled';M.metrics[why]=M.metrics[why]+1;report(e,why=='cancelled' and e.invalidReason or why);table.remove(M.queue,i)
  elseif e.nextTry and now<e.nextTry then
   M.metrics.retrySkipped=(M.metrics.retrySkipped or 0)+1
   if e.blocked~='retry_wait' then e.blocked='retry_wait';report(e,'retry_wait')end
  else
   local line,policy=contexts(e,function()return V.client.plan(e.player,V.voice(e.player),e.group,e.intensity,e.maximum,nil,V.client.preferences())end)
   local channel=require('CSV/Channel').resolve(policy,require('CSV/Activity').read(e.player),V.client.preferences())
   if (not e.nextTry or now>=e.nextTry) and line and channel.allowed and channel.channel~='none' then e.rank=policy.priority or 1;candidates[#candidates+1]=e
   else
    local reason=e.nextTry and now<e.nextTry and 'retry_wait' or not line and 'no_eligible_recording' or channel.reason
    if e.blocked~=reason then e.blocked=reason;M.metrics.blocked=M.metrics.blocked+1;report(e,reason)end
   end
  end
 end
 table.sort(candidates,function(a,b)if a.rank~=b.rank then return a.rank>b.rank end;if a.at~=b.at then return a.at<b.at end;if a.group~=b.group then return a.group<b.group end;return a.serial<b.serial end)
 local spoken={}
 for _,e in ipairs(candidates)do
 local busy=false
 for _,active in ipairs(V.client.active)do if active.player==e.player and (active.preview or not require('CSV/Priority').interrupt(e.rank,active.priority or 1) and not require('CSV/Priority').startle(e.group,e.alert,active.priority or 1,active.preview,active.group)) then busy=true;break end end
 if not spoken[e.player] and not busy then
  e.nextTry=now+250
  M.dispatching=true
  local ok,err=pcall(contexts,e,function()return require('CSV/Trace').call(e.trace,e.player,e.fn,e.player,e.group,e.intensity,e.maximum,unpack(e.args,1,e.args.n))end)
  M.dispatching=false
  if not ok then report(e,'dispatch_error');for i=#M.queue,1,-1 do if M.queue[i]==e then table.remove(M.queue,i)end end;error(err)end
  local attempt=V.client.lastAttempt[e.player]
  if require('CSV/Pending').accepted(attempt,e.group) then
   local function accept()
    M.accept(e);M.metrics.played=M.metrics.played+1;report(e,'started')
    for i=#M.queue,1,-1 do if M.queue[i]==e then table.remove(M.queue,i);break end end
   end
   spoken[e.player]=true
   local entry=attempt.playbackEntry
   if entry and not entry.started then
    e.playback=entry;e.tries=(e.tries or 0)+1
    local started,failed=entry.onStarted,entry.onFailed
    entry.onStarted=function() if started then started() end;accept() end
    entry.onFailed=function(reason)
     if failed then failed(reason) end
     e.nextTry=V.now()+250
     if e.tries>=2 or (reason~='start_timeout' and reason~='ended_before_start' and reason~='emitter_check_error') then e.expires=0 end
     report(e,'start_failed_'..tostring(reason))
    end
   else accept() end
  end
 end end
end
return M
