package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/client/?.lua;'..package.path
local now=0;getTimestampMs=function()return now end
-- Model the installed LuaFileWriter: opening truncates, writes buffer, closing publishes.
local disk={test='previous completed report',timed='old timed report'}
local opens,closes=0,0;local fail=false
getFileWriter=function(name)
 opens=opens+1;disk[name]='';local buffer=''
 return {write=function(_,s)if fail then error('disk error')end;buffer=buffer..s end,close=function()closes=closes+1;disk[name]=buffer end}
end
local W=require 'CSV/ReportWriter';local f=W.open('test');local formatted=0
for i=1,100 do local index=i;f:defer(function()formatted=formatted+1;return tostring(index)..'\n'end)end
f:close();assert(formatted==0 and opens==0 and disk.test=='previous completed report','scheduling cannot truncate the last completed report')
assert(not W.open('test'),'same output cannot be overwritten while pending')
W.tick();assert(formatted==32 and opens==0 and closes==0 and disk.test=='previous completed report','at most 32 rows prepared per slice; exit at this point preserves the prior report')
W.tick();W.tick();assert(opens==0 and disk.test=='previous completed report')
W.tick();assert(formatted==100 and opens==1 and closes==1 and W.metrics.completed==1,'one complete write and close in the same tick')
local expected={};for i=1,100 do expected[i]=tostring(i)..'\n'end;assert(disk.test==table.concat(expected),'all rows retained in order')
f=W.open('timed');for i=1,10 do f:defer(function()now=now+1;return 'slow'end)end;f:close()
W.tick();assert(W.jobs.timed.index==3 and disk.timed=='old timed report','time budget ends preparation before line budget')
while W.jobs.timed do W.tick()end;assert(disk.timed==string.rep('slow',10))
local previous=disk.test;local oldOpens=opens
f=W.open('test');f:defer(function()error('formatter error')end);f:close();W.tick()
assert(W.jobs.test==nil and disk.test==previous and opens==oldOpens,'format errors keep last completed report and release job')
f=W.open('test');f:close();W.tick();assert(disk.test==previous and opens==oldOpens,'empty export cannot erase prior report')
f=W.open('test');f:write('unready');f:abort();assert(W.jobs.test==nil and disk.test==previous,'aborting failed preparation preserves report')
f=W.open('failure');f:write('bad');f:close();fail=true
local oldCloses=closes;local completed=W.metrics.completed;W.tick()
assert(W.jobs.failure==nil and closes==oldCloses+1 and W.metrics.completed==completed,'write failure closes once and cannot claim completion')
assert(W.metrics.failed==3)
print('PASS report preparation budgets, previous report preservation, complete commit, errors, abort and empty reports')

-- The public export entry point must also preserve an older good report.
package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/shared/?.lua;'..package.path
package.loaded['CSV/Core']={version='test'}
package.loaded['CSV/ProductionReport']={export=function()error('section unavailable')end}
getSpecificPlayer=function()end
local debug=require 'CSV/Debug';fail=false
local oldCombined='completed combined report';disk['CSV-report.txt']=oldCombined
assert(not debug.export());W.tick()
assert(disk['CSV-report.txt']==oldCombined and not W.jobs['CSV-report.txt'],'failed combined preparation preserves the previous completed report')
package.loaded['CSV/ProductionReport'].export=function(f)f:write('complete section\n')end
assert(debug.export())
while W.jobs['CSV-report.txt']do W.tick()end
assert(disk['CSV-report.txt']:find('complete section',1,true),'export can retry after preparation failure')
print('PASS combined report entry point preserves previous export on section failure and recovers')
