-- Overall body health is 0..100. These are speech thresholds, not diagnoses.
local H={players=setmetatable({},{__mode='k'})}
function H.stage(health)
 if type(health)~='number' or health~=health or health<=0 then return 0 end
 return health<=10 and 2 or health<=25 and 1 or 0
end
function H.pending(p)local s=H.players[p];return s and s.pending end
function H.observe(p,f,now)
 local s=H.players[p] or {requested=0};H.players[p]=s
 if type(f.health)~='number' or f.health~=f.health then return end
 if f.health<=0 then s.pending=nil;return end
 if f.health>35 then
  s.safeSince=s.safeSince or now
  if now-s.safeSince>=10000 then s.requested=0;s.announced=0;s.pending=nil;s.retryAt=nil end
 else s.safeSince=nil end
 local stage=H.stage(f.health)
 if s.pending and (stage<s.pending.stage or now>s.pending.expires) then s.pending=nil;s.retryAt=now+1000 end
 if stage>(s.announced or 0) and (not s.pending or stage>s.pending.stage) and now>=(s.retryAt or 0) then
  s.requested=stage;s.pending={stage=stage,at=now,expires=now+15000}
  local T=require('CSV/Trace');local t=T.begin(p,'Injured','critical_health_threshold',f)
  T.step(t,'critical_health','threshold_crossed',{health=f.health,stage=stage})
  T.call(t,p,require('ConditionalSpeech_Core').generateSpeechFrom,p,'Injured',4,4,false,false)
 end
end
function H.valid(p,event,f)return H.pending(p)==event and H.stage(f.health)>=event.stage end
function H.accept(p,event)
 local s=H.players[p];if s and s.pending==event then s.pending=nil;s.announced=event.stage end
end
return H
