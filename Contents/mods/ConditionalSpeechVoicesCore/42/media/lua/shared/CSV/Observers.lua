local O={status={},modules={}}
function O.run(name,fn,...)
 local status=O.status[name] or {calls=0,errors=0};O.status[name]=status
 status.calls=status.calls+1
 local started=getTimestampMs()
 local result={pcall(fn,...)}
 local elapsed=math.max(0,getTimestampMs()-started)
 status.totalMs=(status.totalMs or 0)+elapsed;status.maxMs=math.max(status.maxMs or 0,elapsed)
 if not result[1] then
  status.errors=status.errors+1;status.lastError=tostring(result[2]);status.failed=true;status.lastFailure=getTimestampMs()
  local now=getTimestampMs()
  if not status.lastLog or now-status.lastLog>=10000 then
   status.lastLog=now;print('[CSV] observer '..name..' errors='..status.errors..' '..status.lastError)
  end
 else status.failed=false end
 return unpack(result)
end
function O.module(name,method)
 local status=O.status[name..'.'..method]
 if status and status.failed and getTimestampMs()-status.lastFailure<1000 then return false,status.lastError end
 return O.run(name..'.'..method,function()
  local m=O.modules[name]
  if not m then m=require('CSV/'..name);O.modules[name]=m end
  assert(type(m[method])=='function','missing method '..method)
  return m[method]()
 end)
end
function O.tick()
 local S=require 'CSV/State';if S.beginFrame then S.beginFrame()end
 for _,name in ipairs({'Injury','VehicleCombat','Startle','Threat','Recovery','Loot','Vehicles','Outcomes','Reload','Psychology','ProductionReport','Upstream'})do O.module(name,'tick')end
 O.module('SpeechManager','flush')
 if S.endFrame then S.endFrame()end
end
function O.install()
 require('CSV/SpeechManager').enabled=true
 for _,name in ipairs({'Observe','VehicleCombat','Vehicles','Outcomes','Reload','Psychology','Upstream'})do O.module(name,'install')end
end
return O
