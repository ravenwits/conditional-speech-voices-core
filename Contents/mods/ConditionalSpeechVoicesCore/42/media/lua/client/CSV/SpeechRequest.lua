-- Captures observer evidence and commits it only after engine playback starts.
-- SpeechManager owns scheduling; this adapter owns observer lifetime/context access.
local R={}
local V=require 'CSV/Core'
local S=require 'CSV/State'
local A=require 'CSV/Actors'
function R.withContext(e,fn)
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
function R.capture(fn,p,g,i,max,args,serial)
 local recovery=require('CSV/Recovery').players[p];local loot=require('CSV/Loot').players[p]
 local outcome=S.outcome and S.outcome[p];local psych=require('CSV/Psychology').context[p]
 local injury=require('CSV/Injury').context[p]
 local reload=S.reload and S.reload[p]
 local healthEvent=g=='Injured' and require('CSV/CriticalHealth').pending(p)
 local token=healthEvent or reload or outcome or psych or injury or recovery and recovery.pending[g] or loot and loot.pending[g] or g
 local now=V.now();local event={player=p,group=g,intensity=i,maximum=max,args=args,fn=fn,token=token,at=now,serial=serial,
 healthEvent=healthEvent,reload=reload,outcome=outcome,psychology=psych,injury=injury,alert=S.nativeAlert and S.nativeAlert[p],loot=S.loot and S.loot[p],
 recovery=recovery and recovery.pending[g],lootEvent=loot and loot.pending[g],trace=require('CSV/Trace').request(p,g)}
 if g=='GunJammed' or g=='OutOfAmmo' then event.firearm=A.call(p,'getPrimaryHandItem')end
 event.expires=healthEvent and healthEvent.expires or outcome and outcome.expires or event.recovery and event.recovery.at+12000 or event.lootEvent and event.lootEvent.at+90000 or psych and psych.at+(require('CSV/PsychologyRules').defer(psych) and require('CSV/PsychologyPolicy').aftermathLifetime or require('CSV/PsychologyPolicy').eventLifetime) or now+(g=='AcutePain' and 1000 or g=='Startle' and 1500 or psych and 8000 or 2000)
 return event
end
function R.valid(e)
 local p=e.player
 if not V.config.enabled or not V.languageSupported() or A.call(p,'isDead')~=false or A.call(p,'isLocalPlayer')~=true then return false end
 if e.healthEvent and not require('CSV/CriticalHealth').valid(p,e.healthEvent,S.capture(p)) then return false end
 if e.group=='Threat' or e.group=='Panic' or e.group=='PanicCallback' then
  local f=S.capture(p)
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
  local loot=require('CSV/Loot');local owner=loot.players[p]
  if not owner or owner.pending[e.group]~=e.lootEvent then return false end
  if not loot.owned(p,e.lootEvent.item) then e.invalidReason='loot_no_longer_owned';return false end
  return require('CSV/LootRules').allowed(e.group,V.client.preferences())
 end
 return true
end
-- Full inventory facts are read only when a loot request can be considered.
-- Nothing is cached across attempts, so new ammunition/medicine is visible immediately.
function R.waitReason(e)
 if not e.lootEvent then return end
 local allowed=require('CSV/VoiceOwnership').check(e.player,{priority=1,group=e.group})
 if not allowed then return 'loot_wait_for_voice' end
 local f=S.capture(e.player)
 if f.near~=0 or f.visible~=0 or f.recentThreat~=false then return 'loot_wait_for_safety' end
end
function R.refresh(e)
 if not e.lootEvent then return true end
 e.loot=require('CSV/Loot').snapshot(e.player,e.lootEvent.item)
 if require('CSV/LootRules').classify(e.loot)~=e.group then e.invalidReason='loot_need_resolved';return false end
 return true
end
function R.accept(e)
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
return R
