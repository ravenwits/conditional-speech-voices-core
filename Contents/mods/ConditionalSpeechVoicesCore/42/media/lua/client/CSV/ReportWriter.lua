local W={jobs={},metrics={completed=0,failed=0,maxSliceMs=0}}
function W.open(name)
 if W.jobs[name] then return nil end
 local started=getTimestampMs()
 local f=getFileWriter(name,true,false)
 W.metrics.maxOpenMs=math.max(W.metrics.maxOpenMs or 0,getTimestampMs()-started)
 if not f then return nil end
 local job={file=f,lines={},index=1,ready=false};W.jobs[name]=job
 local proxy={}
 function proxy:write(text)job.lines[#job.lines+1]=text end
 function proxy:defer(fn)job.lines[#job.lines+1]=fn end
 function proxy:close()job.ready=true end
 return proxy
end
function W.tick()
 local started=getTimestampMs();local count=0
 for name,job in pairs(W.jobs)do if job.ready then
  local ok,err=pcall(function()
   while job.index<=#job.lines and count<32 and getTimestampMs()-started<2 do
    local value=job.lines[job.index];job.file:write(type(value)=='function' and value() or value)
    job.lines[job.index]=false;job.index=job.index+1;count=count+1
   end
   if job.index>#job.lines then job.file:close();W.jobs[name]=nil;W.metrics.completed=W.metrics.completed+1;print('[CSV] report completed '..name)end
  end)
  if not ok then pcall(function()job.file:close()end);W.jobs[name]=nil;W.metrics.failed=W.metrics.failed+1;print('[CSV] report failed '..name..': '..tostring(err))end
  if count>=32 or getTimestampMs()-started>=2 then break end
 end end
 W.metrics.maxSliceMs=math.max(W.metrics.maxSliceMs,getTimestampMs()-started)
end
return W
