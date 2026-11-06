local b='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/';package.path=b..'shared/?.lua;'..b..'client/?.lua;'..package.path
local now=10000;getTimestampMs=function()return now end
local O=require 'CSV/Observers';local count=0
for _,name in ipairs({'Injury','VehicleCombat','Startle','Threat','Recovery','Loot','Vehicles','Outcomes','Reload','Psychology','ProductionReport','Upstream'})do O.modules[name]={tick=function()count=count+1 end}end
O.modules.SpeechManager={flush=function()count=count+1 end}
O.modules.Threat.tick=function()error('injected early observer failure')end
O.tick();assert(count==12 and O.status['Threat.tick'].errors==1,'later observers survive early exception')
O.modules.Threat.tick=function()count=count+1 end;now=now+1001;O.tick();assert(count==25 and not O.status['Threat.tick'].failed,'failed observer can recover')
local H=require 'CSV/Connections';local original=function()return 1 end;local obj={run=original};local callbacks={}
local event={Add=function(f)callbacks[f]=true end,Remove=function(f)callbacks[f]=nil end};local callback=function()end
local ok=H.install('partial',function(t)t:replace(obj,'run',function()return 2 end);t:event(event,callback);error('injected install failure')end)
assert(not ok and obj.run==original and next(callbacks)==nil,'partial installation rolls back')
assert(H.install('partial',function(t)t:replace(obj,'run',function()return 3 end);t:event(event,callback)end),'failed installation retries')
assert(obj.run()==3 and callbacks[callback],'successful install')
assert(H.install('partial',function()error('must not reinstall')end),'idempotent install')
local anotherMod=function()return 4 end;obj.run=anotherMod;H.remove('partial')
assert(obj.run==anotherMod and next(callbacks)==nil,'uninstall preserves later mod changes')
local oldPool=require('CSV/PsychologyRules').pool
require('CSV/PsychologyRules').pool=function()return 'WRONG' end
for _,c in ipairs(require('CSV/PsychologyScenarios').cases())do assert(c.expect~='WRONG','scenario expectations independent of implementation')end
require('CSV/PsychologyRules').pool=oldPool
print('PASS isolated observers, recovery, transaction rollback/retry/ownership, independent scenario expectations')
