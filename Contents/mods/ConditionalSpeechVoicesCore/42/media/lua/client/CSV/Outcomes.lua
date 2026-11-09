local O={watch={},pending={},players=setmetatable({},{__mode='k'}),nextTick=0,hooks={}}
local V=require 'CSV/Core'
local S=require 'CSV/State'
local R=require 'CSV/OutcomeRules'
local function call(o,k,...)
 local ok,fn=pcall(function()return o and o[k]end)
 if ok and fn then local good,v=pcall(fn,o,...);if good then return v end end
end
O.call=call
local function eligible(p)
 return p and call(p,'isLocalPlayer')==true and call(p,'isDead')==false and V.config.enabled and V.extended(V.voice(p)) and require('CSV/Core').languageSupported()
end
function O.snapshot(kind,obj,p)
 if kind=='car_door' then
  local door=call(obj,'getDoor')
  return {open=call(door,'isOpen'),locked=call(door,'isLocked'),broken=call(door,'isLockBroken')}
 end
 if kind=='window' then return {open=call(obj,'IsOpen'),locked=call(obj,'isLocked')==true or call(obj,'isPermaLocked')==true,blocked=call(obj,'isBarricaded')==true,destroyed=call(obj,'isDestroyed')} end
 if kind=='trait' then return require('CSV/TraitReactions').snapshot(p) end
 if kind=='darkness' then return require('CSV/Darkness').snapshot(p) end
 if kind=='vehicle_combat' then return {occupied=call(p,'getVehicle')==obj} end
 if kind:match('^vehicle_') then return require('CSV/Vehicles').snapshot(obj,p) end
 if kind=='swing' or kind=='gun' then return {condition=call(obj,'getCondition'),jammed=call(obj,'isJammed'),rounds=call(obj,'getCurrentAmmoCount'),perShot=call(obj,'getAmmoPerShoot'),hasChamber=call(obj,'haveChamber'),chamber=call(obj,'isRoundChambered'),spent=call(obj,'isSpentRoundChambered')}
 elseif kind=='bandage' then return {bandaged=call(obj,'bandaged')}
 elseif kind=='disinfect' then return {alcohol=call(obj,'getAlcoholLevel')}
 elseif kind=='door' then
  local blocked=call(obj,'isObstructed');local barricaded=call(obj,'isBarricaded')
  return {open=call(obj,'IsOpen'),locked=call(obj,'isLocked')==true or call(obj,'isLockedByKey')==true,blocked=blocked==true or barricaded==true}
 else return {running=call(obj,'isEngineRunning'),starting=call(obj,'isStarting'),battery=call(obj,'getBatteryCharge'),fuel=call(obj,'getRemainingFuelPercentage')} end
end
function O.begin(kind,p,obj)
 if not eligible(p) or not obj then return end
 local e={kind=kind,player=p,obj=obj,before=O.snapshot(kind,obj,p),at=V.now()}
 if kind=='car_door' then
  local car=call(obj,'getVehicle');local x,y=call(car,'getX'),call(car,'getY')
  if type(x)=='number' and type(y)=='number' then e.offsetX=call(p,'getX')-x;e.offsetY=call(p,'getY')-y end
 end
 return e
end
function O.finish(e)
 if not e or e.cancelled or e.finished then return end
 if e.kind=='start' then e.sawStarting=O.snapshot('start',e.obj,e.player).starting==true end
 e.completed=true;e.finished=V.now();e.deadline=e.finished+(e.kind=='start' and 10000 or 5000);O.watch[#O.watch+1]=e
end
function O.queue(e,group)
 if e.consumed or e.queued then return false end
 local p=e.player;local s=O.players[p] or {last={}};O.players[p]=s
 local now=V.now();local gap=group=='FuelLow' and 300000 or group=='WeaponBroken' and 10000 or 45000
 if not require('CSV/VehicleRules').groups[group] and s.last[group] and now-s.last[group]<gap then return false end
 for i=#O.pending,1,-1 do
  local q=O.pending[i]
  if q.player==p and q.group==group then
   if now>q.expires or not O.valid(q) then table.remove(O.pending,i) else return false end
  end
 end
 e.group=group;e.queued=now;e.expires=now+(group=='WeaponBroken' and 5000 or R.urgent(group) and 8000 or 20000);O.pending[#O.pending+1]=e
 require('CSV/ProductionReport').observe('outcome_queued',{outcomeKind=e.kind,outcomeGroup=group,outcomeNativeSound=e.nativeSound})
 return true
end
function O.valid(e)
 if e.consumed or e.cancelled then return false end
 local p=e.player;if not eligible(p) then return false end
 if e.kind:match('^vehicle_') then return require('CSV/Vehicles').valid(e) end
 if e.kind=='gun' then return call(p,'getPrimaryHandItem')==e.obj end
 if e.kind=='start' or e.kind=='fuel' then return call(p,'getVehicle')==e.obj and call(e.obj,'isDriver',p)==true end
 if e.kind=='car_door' then
  local car=call(e.obj,'getVehicle');local x,y=call(car,'getX'),call(car,'getY')
  if type(x)~='number' or type(y)~='number' then return false end
  -- Keep the attempted door's position relative to the vehicle, including long vans.
  local d=call(p,'DistTo',x+(e.offsetX or 0),y+(e.offsetY or 0))
  return type(d)=='number' and d<=3
 end
 if e.kind=='door' or e.kind=='window' then local d=call(p,'DistTo',call(e.obj,'getX'),call(e.obj,'getY'));return type(d)=='number' and d<=3 end
 return true
end
function O.update()
 local now=V.now()
 for i=#O.watch,1,-1 do
  local e=O.watch[i]
  if not O.valid(e) or e.cancelled or now>e.deadline then table.remove(O.watch,i)
  elseif now-e.finished>=250 then
   e.after=O.snapshot(e.kind,e.obj,e.player)
   if e.kind=='start' then
    e.sawStarting=e.sawStarting or e.after.starting==true
    -- A real crank must end, or a verified dead battery must prevent it.
    e.settled=e.sawStarting and e.after.starting==false or e.after.battery==0 and now-e.finished>=2000
   end
   local group=R.classify(e)
   if group then
    if e.kind=='start' then require('CSV/Vehicles').failed(e) end
    O.queue(e,group);table.remove(O.watch,i)
   elseif e.kind=='door' or (e.kind=='window' or e.kind=='car_door') and e.after.open==true or e.kind=='start' and e.after.running==true then table.remove(O.watch,i) end
  end
 end
 require('CSV/Sort').sort(O.pending,function(a,b)return require('CSV/Priority').before(a,b,function(e)return require('CSV/Priority').rank(R.urgent(e.group))end,function(e)return e.queued end)end)
 for i=#O.pending,1,-1 do
  local e=O.pending[i];local p=e.player;local s=O.players[p]
  e.after=O.snapshot(e.kind,e.obj,p)
  local pendingStatus=require('CSV/Pending').status(now,O.valid(e) and R.classify(e)==e.group,e.expires,e.nextAttempt)
  if pendingStatus=='expired' or pendingStatus=='cancelled' then
   require('CSV/ProductionReport').observe('outcome_expired_or_changed',{outcomeKind=e.kind,outcomeGroup=e.group});table.remove(O.pending,i)
  elseif (not s.lastAny or now-s.lastAny>=15000 or R.urgent(e.group)) and pendingStatus=='ready' then
   local f=S.capture(p);f.outcome=e
   local line,policy=V.client.plan(p,V.voice(p),e.group,1,1,f,V.client.preferences())
   local channel=require('CSV/Channel').resolve(policy,require('CSV/Activity').read(p),V.client.preferences())
   if line and channel.allowed and channel.channel~='none' then
    e.nextAttempt=now+3000;S.outcome=S.outcome or setmetatable({},{__mode='k'});S.outcome[p]=e;V.client.lastAttempt[p]=nil
    local ok,err=pcall(require('ConditionalSpeech_Core').generateSpeechFrom,p,e.group,1,1,false,false);S.outcome[p]=nil
    if not ok then error(err)end
    local a=V.client.lastAttempt[p]
    if require('CSV/Pending').accepted(a,e.group) then
     if e.kind=='vehicle_combat' then require('CSV/VehicleCombat').accepted(e) end
     e.consumed=true;s.last[e.group]=now;s.lastAny=now;table.remove(O.pending,i)
     require('CSV/ProductionReport').observe('outcome_played',{outcomeKind=e.kind,outcomeGroup=e.group})
    end
   end
  end
 end
end
function O.fuel(p)
 if not eligible(p) then return end
 local car=call(p,'getVehicle');if not car or call(car,'isDriver',p)~=true then return end
 local s=O.players[p] or {last={}};O.players[p]=s
 if s.car~=car then s.car=car;s.lowFuel=false end
 local f=O.snapshot('fuel',car,p)
 if type(f.fuel)=='number' and f.fuel>=20 then s.lowFuel=false end
 if f.running==true and type(f.fuel)=='number' and f.fuel>=0 and f.fuel<15 and not s.lowFuel then
  local e=O.begin('fuel',p,car);e.completed=true;e.after=f
  if O.queue(e,'FuelLow') then s.lowFuel=true end
 end
end
function O.tick()
 local now=V.now();if now<O.nextTick then return end;O.nextTick=now+250
 O.update()
 if now>=(O.nextFuel or 0)then O.nextFuel=now+2000;for i=0,getNumActivePlayers()-1 do O.fuel(getSpecificPlayer(i))end end
end
function O.swing(p,weapon)
 local e=O.begin('swing',p,weapon);O.finish(e)
end
-- The keyboard interaction calls Java directly, bypassing ISOpenCloseDoor.
-- Native failure sound on THIS player's emitter confirms a real failed attempt.
-- Merely facing a locked door, or hearing another player, never qualifies.
function O.nativeDoor(p)
 if not eligible(p) then return end
 local s=O.players[p] or {last={}};O.players[p]=s
 local door=call(p,'getContextDoorOrWindowOrWindowFrame',call(p,'getDir'))
 local prefix=call(door,'getSoundPrefix');local emitter=call(p,'getEmitter')
 local window=call(door,'isPermaLocked')~=nil
 local kind=window and 'window' or 'door'
 local token
 if window and call(door,'IsOpen')==false and call(p,'getVariableBoolean','bOpenWindow')==true and (call(emitter,'isPlaying','WindowIsLocked')==true or call(emitter,'isPlaying','BreakLockOnWindow')==true) then token='locked'
 elseif type(prefix)=='string' and call(door,'IsOpen')==false then
  if call(emitter,'isPlaying',prefix..'Blocked')==true then token='blocked'
  elseif call(emitter,'isPlaying',prefix..'Locked')==true then token='locked' end
 end
 if token and (s.nativeDoor~=door or s.nativeToken~=token) then
  local e=O.begin(kind,p,door);e.completed=true;e.after=O.snapshot(kind,door,p);e.nativeSound=token
  local group=R.classify(e);if group then O.queue(e,group)end
 end
 s.nativeDoor=token and door or nil;s.nativeToken=token
end
local function safe(fn,...)
 local ok,err=pcall(fn,...);if not ok and not O.error then O.error=true;print('[CSV] outcome observer: '..tostring(err))end
end
function O.hook(path,name,kind,key)
 local loaded=pcall(require,path);local class=_G[name]
 if not loaded or not class or not class.start or not class.perform or not class.stop then O.hooks[name]=false;return end
 local installed=require('CSV/Connections').install('outcome.'..name,function(t)
 local start,perform,stop=class.start,class.perform,class.stop
 t:replace(class,'start',function(self,...)
  safe(function()
   if kind=='bandage' and self.doIt~=true then return end
   local obj=kind=='start' and call(self.character,'getVehicle') or self[key]
   self._csvOutcome=O.begin(kind,self.character,obj)
  end)
  return start(self,...)
 end)
 t:replace(class,'stop',function(self,...)
  if self._csvOutcome then self._csvOutcome.cancelled=true end
  return stop(self,...)
 end)
 t:replace(class,'perform',function(self,...)
  -- In single player perform can advance the queue and reuse objects. Preserve the snapshot first.
  local e=self._csvOutcome;local result={perform(self,...)};safe(O.finish,e);return unpack(result)
 end)
 end)
 O.hooks[name]=installed
end
function O.installVehicleLock()
 local loaded=pcall(require,'Vehicles/TimedActions/ISUnlockVehicleDoor')
 local class=_G.ISUnlockVehicleDoor
 if not loaded or not class or not class.start then return false end
 return require('CSV/Connections').install('outcome.vehicle-lock',function(t)
  local start=class.start
  t:replace(class,'start',function(self,...)
   local e;safe(function()e=O.begin('car_door',self.character,self.part)end)
   local result={start(self,...)}
   safe(function()
    if e and not isClient() and not isServer() then
     e.after=O.snapshot(e.kind,e.obj,e.player);e.completed=true;e.nativeSound='unlock_failed'
     local group=R.classify(e);if group then O.queue(e,group)end
    end
   end)
   return unpack(result)
  end)
 end)
end
function O.install()
 if O.installed then return true end
 O.hooks.ISUnlockVehicleDoor=O.installVehicleLock()
 for _,row in ipairs({{'TimedActions/ISRackFirearm','ISRackFirearm','gun','gun'},{'TimedActions/ISReloadWeaponAction','ISReloadWeaponAction','gun','gun'},{'TimedActions/ISInsertMagazine','ISInsertMagazine','gun','gun'},{'Vehicles/TimedActions/ISStartVehicleEngine','ISStartVehicleEngine','start'}, {'TimedActions/ISApplyBandage','ISApplyBandage','bandage','bodyPart'},{'TimedActions/ISDisinfect','ISDisinfect','disinfect','bodyPart'},{'TimedActions/ISOpenCloseDoor','ISOpenCloseDoor','door','item'},{'TimedActions/ISOpenCloseWindow','ISOpenCloseWindow','window','object'},{'Vehicles/TimedActions/ISOpenVehicleDoor','ISOpenVehicleDoor','car_door','part'}})do O.hook(unpack(row))end
 O.installed=require('CSV/Connections').install('outcome-events',function(t)
  if Events.OnWeaponSwing then t:event(Events.OnWeaponSwing,function(...)safe(O.swing,...)end)end
  if Events.OnPlayerUpdate then t:event(Events.OnPlayerUpdate,function(p)safe(O.nativeDoor,p)end)end
 end)
 return O.installed
end
return O
