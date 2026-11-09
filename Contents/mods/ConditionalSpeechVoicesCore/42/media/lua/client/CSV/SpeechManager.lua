-- All gameplay requests enter here. Observation histories remain with their owners;
-- this is the only queue allowed to dispatch speech.
local M={enabled=false,dispatching=false,queue={},serial=0,metrics={submitted=0,played=0,expired=0,cancelled=0,blocked=0}}
local V=require 'CSV/Core'
local Request=require 'CSV/SpeechRequest'
local contexts=Request.withContext
M.valid=Request.valid
M.accept=Request.accept
local function report(e,reason)
 require('CSV/Trace').step(e.trace,'manager',reason,{group=e.group})
end
function M.submit(fn,p,g,i,max,args)
 M.serial=M.serial+1
 local event=Request.capture(fn,p,g,i,max,args,M.serial)
 for _,old in ipairs(M.queue)do if old.player==p and old.token==event.token then return end end
 if #M.queue>=128 then M.metrics.cancelled=M.metrics.cancelled+1;report(event,'queue_full');return end
 M.queue[#M.queue+1]=event;M.metrics.submitted=M.metrics.submitted+1
 V.client.lastAttempt[p]={group=g,outcome='manager_pending'};report(event,'submitted')
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
   local waiting=Request.waitReason(e)
   if waiting then
    if e.blocked~=waiting then e.blocked=waiting;report(e,waiting)end
   elseif not Request.refresh(e) then
    M.metrics.cancelled=M.metrics.cancelled+1;report(e,e.invalidReason);table.remove(M.queue,i)
   else
    if e.lootEvent then e.nextTry=now+250 end
    local line,policy=contexts(e,function()return V.client.plan(e.player,V.voice(e.player),e.group,e.intensity,e.maximum,nil,V.client.preferences())end)
    local channel=require('CSV/Channel').resolve(policy,require('CSV/Activity').read(e.player),V.client.preferences())
    if line and channel.allowed and channel.channel~='none' then e.rank=policy.priority or 1;candidates[#candidates+1]=e
    else
     local reason=not line and 'no_eligible_recording' or channel.reason
     if e.blocked~=reason then e.blocked=reason;M.metrics.blocked=M.metrics.blocked+1;report(e,reason)end
    end
   end
  end
 end
 require('CSV/Sort').sort(candidates,function(a,b)if a.rank~=b.rank then return a.rank>b.rank end;if a.at~=b.at then return a.at<b.at end;if a.group~=b.group then return a.group<b.group end;return a.serial<b.serial end)
 local spoken={}
 for _,e in ipairs(candidates)do
 local allowed,ownershipReason=require('CSV/VoiceOwnership').check(e.player,{priority=e.rank,group=e.group,nativeAlert=e.alert})
 local busy=not allowed
 if busy and e.blocked~=ownershipReason then e.blocked=ownershipReason;M.metrics.blocked=M.metrics.blocked+1;report(e,ownershipReason)end
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
