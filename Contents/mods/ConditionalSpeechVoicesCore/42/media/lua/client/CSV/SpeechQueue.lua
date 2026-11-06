local Q={}
local V=require 'CSV/Core'
local R=require 'CSV/PsychologyRules'
local Policy=require 'CSV/PsychologyPolicy'
local call=require('CSV/Actors').call
function Q.update(P,p,s,f,now)
 table.sort(s.queue,function(a,b)return require('CSV/Priority').before(a,b,R.priority,function(e)return e.at end)end)
 for i=#s.queue,1,-1 do
  local e=s.queue[i]
  -- A kill that leaves known-clear surroundings is an aftermath, not an in-combat
  -- quip. Keep the same verified event while the threat memory settles.
  if e.kind=='zombieKill' and f.encounterThreat==false and f.near==0 and f.visible==0 and f.humanThreat==false
   and f.fire~=true and not require('CSV/Concealment').active(f) then e.aftermath=true end
  local renewed=e.aftermath==true and (f.encounterThreat==true or (f.near or 0)>0 or f.humanThreat==true or f.fire==true or require('CSV/Concealment').active(f))
  local stale=renewed or e.kind=='humanGroup' and s.visibleCount~=nil and s.visibleCount<2
  if e.subject then
   local seen=call(p,'CanSee',e.subject)==true
   stale=stale or call(e.subject,'isDead')==true
    or (e.kind=='lostTarget' or e.kind=='friendSearch' or e.kind=='hiddenPursuer') and seen
    or e.kind=='reacquired' and not seen
    or e.kind=='pursuit' and (not s.track or s.track.body~=e.subject)
  end
  local pendingStatus=require('CSV/Pending').status(now,not stale,e.at+(R.defer(e) and Policy.aftermathLifetime or Policy.eventLifetime),e.nextTry)
  if pendingStatus=='cancelled' or pendingStatus=='expired' then require('CSV/ProductionReport').observe(stale and 'psychology_state_changed' or 'psychology_expired',{psychologyKind=e.kind});table.remove(s.queue,i)
  elseif pendingStatus=='ready' then
   f=require('CSV/State').capture(p);f.psychology=e
   local line,decision=V.client.plan(p,V.voice(p),'Psychology',1,1,f,V.client.preferences())
   if line and decision.mode=='spoken' then
    e.nextTry=now+3000;P.context[p]=e;V.client.lastAttempt[p]=nil
    local ok,err=pcall(require('ConditionalSpeech_Core').generateSpeechFrom,p,'Psychology',1,1,false,false);P.context[p]=nil
    if not ok then error(err)end
    local attempt=V.client.lastAttempt[p]
    if require('CSV/Pending').accepted(attempt) then s.last[e.kind]=now;table.remove(s.queue,i);require('CSV/ProductionReport').observe('psychology_played',{psychologyKind=e.kind,actorKind=e.actorKind,experience=e.experience});break end
   end
  end
 end
end
return Q
