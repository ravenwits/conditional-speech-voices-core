local M={players=setmetatable({},{__mode='k'}),nextTick=0}
local V=require 'CSV/Core'
local R=require 'CSV/VehicleRules'
local call=require('CSV/Actors').call
local function eligible(p)
 return p and call(p,'isLocalPlayer')==true and call(p,'isDead')==false and V.config.enabled and V.extended(V.voice(p)) and V.languageSupported()
end
function M.snapshot(car,p)
 local square=call(p,'getSquare');local light=call(square,'getLightLevel',call(p,'getPlayerNum'))
 local emitter=call(car,'getEmitter')
 local cause
 if call(emitter,'isPlaying','VehicleRunningOutOfGas')==true then cause='fuel'
 elseif call(emitter,'isPlaying','VehicleEngineFailureDamage')==true then cause='damage' end
 return {running=call(car,'isEngineRunning'),starting=call(car,'isStarting'),fuel=call(car,'getRemainingFuelPercentage'),battery=call(car,'getBatteryCharge'),hotwired=call(car,'isHotwired'),alarm=call(car,'isAlarmActive'),lights=call(car,'getHeadlightsOn'),canLight=call(car,'getHeadlightCanEmmitLight'),dark=type(light)=='number' and light<.35 or false,nativeCause=cause}
end
function M.valid(e)
 if e.kind=='vehicle_combat' then return require('CSV/VehicleCombat').valid(e) end
 if not eligible(e.player) then return false end
 local car=call(e.player,'getVehicle')
 if e.kind=='vehicle_alarm' then
  if car and car~=e.obj then return false end
  local d=call(e.player,'DistTo',call(e.obj,'getX'),call(e.obj,'getY'))
  return car==e.obj or type(d)=='number' and d<=5
 end
 return car==e.obj and call(car,'isDriver',e.player)==true
end
local function event(kind,p,car,a,b)
 return {kind=kind,player=p,obj=car,before=a,after=b,completed=true,localAction=true}
end
function M.queue(e)
 local group=R.classify(e)
 require('CSV/ProductionReport').observe(group and 'vehicle_verified' or 'vehicle_unproven',{outcomeKind=e.kind,outcomeGroup=group,vehicleCause=e.nativeCause,vehicleManual=e.manual,vehicleSynchronous=e.synchronous})
 if group then return require('CSV/Outcomes').queue(e,group) end
end
function M.failed(e)
 if not e or not eligible(e.player) then return end
 local s=M.players[e.player]
 if s and s.car==e.obj then s.failedStart=true end
end
function M.poll(p)
 if not eligible(p) then M.players[p]=nil;return end
 local car=call(p,'getVehicle')
 if not car or call(car,'isDriver',p)~=true then M.players[p]=nil;return end
 local b=M.snapshot(car,p);local s=M.players[p]
 if not s or s.car~=car then M.players[p]={car=car,previous=b};return end
 local a=s.previous;local now=V.now()
 if s.manualUntil and now>s.manualUntil then s.manualUntil=nil end
 if a.running==false and b.running==true then
  if s.failedStart then local e=event('vehicle_recovered',p,car,a,b);e.failedStart=true;M.queue(e) end
  s.failedStart=nil;s.stop=nil;s.manualUntil=nil
 end
 if a.running==true and b.running==false then s.stop={before=a,expires=now+2000,manual=s.manualUntil~=nil} end
 if s.stop then
  if b.running==true or now>s.stop.expires then
   require('CSV/ProductionReport').observe(b.running==true and 'vehicle_stop_resolved' or 'vehicle_stop_unproven',{outcomeKind='vehicle_stop',vehicleManual=s.stop.manual,vehicleCause=b.nativeCause})
   s.stop=nil
  elseif b.nativeCause then
   local e=event('vehicle_stop',p,car,s.stop.before,b);e.manual=s.stop.manual;e.nativeCause=b.nativeCause;M.queue(e);s.stop=nil
  end
 end
 s.previous=b
end
function M.tick()
 local now=V.now();if now<M.nextTick then return end;M.nextTick=now+250
 for i=0,getNumActivePlayers()-1 do M.poll(getSpecificPlayer(i))end
end
local function safe(fn,...)
 return require('CSV/Observers').run('Vehicles.callback',fn,...)
end
function M.hook(path,name,kind)
 if not pcall(require,path) then return false end
 local class=_G[name];if not class or type(class.complete)~='function' then return false end
 return require('CSV/Connections').install('vehicle.'..name,function(t)
  local original=class.complete
  t:replace(class,'complete',function(self,...)
   local p=self.character;local car=self.vehicle or call(p,'getVehicle');local before
   if eligible(p) and car then safe(function()before=M.snapshot(car,p)end)end
   -- Read immediately around the actual mutation, never around queue advancement.
   local result={original(self,...)}
   if before and result[1]~=false and not self._csvVehicleCompleted then
    self._csvVehicleCompleted=true
    safe(function()
     local after=M.snapshot(car,p)
     if kind=='manual' then
      local s=M.players[p];if s and s.car==car then s.manualUntil=V.now()+2000 end
     else
      local alarm=event('vehicle_alarm',p,car,before,after);alarm.synchronous=true
      if R.classify(alarm) then M.queue(alarm)
      elseif kind=='vehicle_hotwire' then M.queue(event(kind,p,car,before,after)) end
     end
    end)
   end
   return unpack(result)
  end)
 end)
end
function M.install()
 M.hook('Vehicles/TimedActions/ISShutOffVehicleEngine','ISShutOffVehicleEngine','manual')
 M.hook('Vehicles/TimedActions/ISHotwireVehicle','ISHotwireVehicle','vehicle_hotwire')
 M.hook('Vehicles/TimedActions/ISOpenVehicleDoor','ISOpenVehicleDoor','vehicle_alarm')
 M.hook('Vehicles/TimedActions/ISSmashVehicleWindow','ISSmashVehicleWindow','vehicle_alarm')
 if pcall(require,'Vehicles/ISUI/ISVehicleMenu') and ISVehicleMenu and type(ISVehicleMenu.onToggleHeadlights)=='function' then
  require('CSV/Connections').install('vehicle.headlights',function(t)
   local original=ISVehicleMenu.onToggleHeadlights
   t:replace(ISVehicleMenu,'onToggleHeadlights',function(p,...)
    local car=call(p,'getVehicle');local e
    if eligible(p) and car and call(car,'isDriver',p)==true then safe(function()e=event('vehicle_lights',p,car,M.snapshot(car,p),{})end)end
    local result={original(p,...)}
    if e and e.before.lights==false then safe(function()require('CSV/Outcomes').finish(e)end)end
    return unpack(result)
   end)
  end)
 end
end
return M
