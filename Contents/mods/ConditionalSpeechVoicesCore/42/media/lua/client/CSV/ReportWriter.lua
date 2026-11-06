local W={jobs={},metrics={completed=0,failed=0,maxSliceMs=0,maxCommitMs=0}}
function W.open(name)
 if W.jobs[name] then return nil end
 -- getFileWriter(...,false) truncates immediately. Do not open the destination
 -- until all deferred rows are ready; quitting during preparation keeps the last report.
 local job={lines={},chunks={},count=0,index=1,ready=false};W.jobs[name]=job
 local proxy={}
 function proxy:write(text)job.count=job.count+1;job.lines[job.count]=text end
 function proxy:defer(fn)job.count=job.count+1;job.lines[job.count]=fn end
 function proxy:close()job.ready=true end
 function proxy:abort()if W.jobs[name]==job then W.jobs[name]=nil end end
 return proxy
end
local function commit(name,job)
 local text=table.concat(job.chunks)
 assert(#text>0,'empty report')
 local started=getTimestampMs()
 local f=getFileWriter(name,true,false)
 W.metrics.maxOpenMs=math.max(W.metrics.maxOpenMs or 0,getTimestampMs()-started)
 assert(f,'cannot open report')
 -- The game's LuaFileWriter has no flush/rename API. Keep write and close in
 -- one call, never leave its buffered PrintWriter open between game ticks.
 local ok,err=pcall(function()f:write(text)end)
 local closed,closeError=pcall(function()f:close()end)
 W.metrics.maxCommitMs=math.max(W.metrics.maxCommitMs,getTimestampMs()-started)
 if not ok then error(err)end
 if not closed then error(closeError)end
end
function W.tick()
 local started=getTimestampMs();local count=0
 for name,job in pairs(W.jobs)do if job.ready then
  local ok,err=pcall(function()
   while job.index<=job.count and count<32 and getTimestampMs()-started<2 do
    local value=job.lines[job.index]
    local text=type(value)=='function' and value() or value
    assert(type(text)=='string','report row must be text')
    job.chunks[#job.chunks+1]=text
    job.lines[job.index]=nil;job.index=job.index+1;count=count+1
   end
   if job.index>job.count then
    commit(name,job);W.jobs[name]=nil;W.metrics.completed=W.metrics.completed+1
    print('[CSV] report completed '..name..' rows='..job.count)
   end
  end)
  if not ok then W.jobs[name]=nil;W.metrics.failed=W.metrics.failed+1;print('[CSV] report failed '..name..': '..tostring(err))end
  if count>=32 or getTimestampMs()-started>=2 then break end
 end end
 W.metrics.maxSliceMs=math.max(W.metrics.maxSliceMs,getTimestampMs()-started)
end
return W
