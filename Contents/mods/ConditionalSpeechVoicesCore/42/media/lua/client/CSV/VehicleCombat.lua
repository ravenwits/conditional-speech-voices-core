local M={cars={},players=setmetatable({},{__mode='k'}),samples=setmetatable({},{__mode='k'}),contacts=setmetatable({},{__mode='k'}),deaths=setmetatable({},{__mode='k'}),weapons=setmetatable({},{__mode='k'}),nextPoll=0,serial=0,metrics={samples=0,contacts=0,kills=0,rejected=0}}
local V=require 'CSV/Core'
local A=require 'CSV/Actors';local call=A.call
local R=require 'CSV/VehicleCombatRules'
local function eligible(p)
 return V.config.enabled and V.languageSupported() and call(p,'isLocalPlayer')==true and call(p,'isDead')==false and V.extended(V.voice(p))
end
local function role(p,car)
 if call(p,'getVehicle')~=car then return nil end
 local driver=call(car,'isDriver',p)
 local person=call(car,'getDriver')
 return driver==true and 'driver' or driver==false and person and call(person,'isDead')==false and 'passenger' or nil
end
local function report(reason,e)
 require('CSV/ProductionReport').observe('vehicle_combat_'..reason,{vehicleEvent=e and e.event,vehicleRole=e and e.role,vehicleTargets=e and e.targets,vehicleAttacks=e and e.attacks,vehicleContact=e and e.nativeContact,vehicleDeath=e and e.dead})
end
function M.refresh()
 local cars={}
 for i=0,getNumActivePlayers()-1 do
  local p=getSpecificPlayer(i);local car=eligible(p) and call(p,'getVehicle');local r=car and role(p,car)
  if r then
   local old=M.players[p]
   if not old or old.car~=car or old.role~=r then M.players[p]={car=car,role=r,siegeLevel=0,burst=0} end
   local entry=cars[car]
   if not entry then
    local ext=call(call(car,'getScript'),'getExtents');local x,z=call(ext,'x'),call(ext,'z')
    -- Use actual vehicle dimensions; missing dimensions disable crowd claims only.
    local radius=type(x)=='number' and type(z)=='number' and math.sqrt(x*x+z*z)/2+1.25 or nil
    entry={car=car,occupants={},driver=call(car,'getDriver'),radius=radius};cars[car]=entry
   end
   entry.occupants[#entry.occupants+1]=p
  else M.players[p]=nil end
 end
 M.cars=cars;M.active=false;for _ in pairs(cars)do M.active=true;break end
end
local function snapshot(z,car,driver)
 return {at=V.now(),car=car,driver=driver,alive=call(z,'isDead')==false,contact=call(car,'isPersistentContact',z),collision=call(z,'isVehicleCollision'),attacker=call(z,'getAttackedBy'),weaponRevision=M.weapons[z] or 0,burning=call(z,'isOnFire')}
end
function M.weaponHit(_,z)
 if not z then return end;M.weapons[z]=(M.weapons[z] or 0)+1
 M.contacts[z]=nil
end
function M.event(p,kind,proof)
 local s=M.players[p];if not s then return end
 local e={kind='vehicle_combat',event=kind,player=p,obj=s.car,role=s.role,completed=true,localAction=true,verified=true,after={occupied=true},session=s,burst=s.burst}
 for k,v in pairs(proof or {})do e[k]=v end
 return e
end
function M.offer(p,kind,proof)
 local s=M.players[p];if not s then return false end
 if s.pending and (s.pending.cancelled or s.pending.consumed or V.now()>(s.pending.expires or 0)) then s.pending=nil end
 local siege=kind=='crowd' or kind=='siege';local level=kind=='siege' and 2 or 1
 if siege then
  if (s.siegeLevel or 0)>=level then return false end
  if s.pending and not s.pending.cancelled and not s.pending.consumed then
   if s.pending.event=='siege' or s.pending.event=='crowd' and kind=='crowd' then return false end
   s.pending.cancelled=true
  end
 else
  if s.surrounded or s.burstSpoken then return false end
  if s.pending and not s.pending.cancelled and not s.pending.consumed then
   if s.pending.event=='impact' and kind=='kill' then s.pending.cancelled=true else return false end
  end
 end
 local e=M.event(p,kind,proof);local group=R.classify(e)
 if group and require('CSV/Outcomes').queue(e,group) then s.pending=e;report('queued',e);return true end
 return false
end
function M.accepted(e)
 local s=M.players[e.player];if not s or s~=e.session then return end
 if e.event=='crowd' or e.event=='siege' then s.siegeLevel=e.event=='siege' and 2 or math.max(1,s.siegeLevel or 0)
 else s.burstSpoken=true end
end
function M.valid(e)
 local s=M.players[e.player]
 if not eligible(e.player) or not s or s~=e.session or role(e.player,e.obj)~=e.role then return false end
 if e.event=='crowd' or e.event=='siege' then
  return s.surrounded==true and (e.event~='siege' or (s.attacks or 0)>0 and (s.panic or 0)>=3)
 end
 return e.burst==s.burst and not s.surrounded
end
function M.ownsThreat(p)
 local s=M.players[p]
 if not s or not s.surrounded then return false end
 local e=s.pending
 return (s.siegeLevel or 0)>0 or e and not e.cancelled and not e.consumed and V.now()<=(e.expires or 0)
end
local function registerContact(z,a,b)
 if not R.contact(a,b,V.now()) then return nil end
 local c=M.contacts[z]
 if c and (c.car~=b.car or c.driver~=b.driver or c.weaponRevision~=b.weaponRevision) then c=nil end
 if not c then
  c={car=b.car,driver=b.driver,weaponRevision=b.weaponRevision,at=V.now(),aliveBefore=true,notified=false}
  M.contacts[z]=c;M.metrics.contacts=M.metrics.contacts+1
 end
 c.last=V.now()
 return c
end
function M.observeZombie(z)
 if not M.active then return end
 if A.kind(z)~='zombie' then return end
 local alive=call(z,'isDead')==false
 if not alive then return end
 if M.deaths[z] and M.deaths[z].handled then M.deaths[z]=nil;M.samples[z]=nil;M.contacts[z]=nil end
 local zx,zy,zz=call(z,'getX'),call(z,'getY'),call(z,'getZ')
 if type(zx)~='number' or type(zy)~='number' then return end
 -- Pick the nearest tracked vehicle, not table iteration order. Overlapping
 -- cars with ambiguous contact remain uncredited rather than guessed.
 local nearest,best=nil,math.huge
 for car,entry in pairs(M.cars)do
  local x,y=call(car,'getX'),call(car,'getY')
  if type(x)=='number' and type(y)=='number' and zz==call(car,'getZ') then
   local distance=(zx-x)^2+(zy-y)^2
   if distance<best then nearest=car;best=distance end
  end
 end
 for car,entry in pairs(M.cars)do
  local cx,cy=call(car,'getX'),call(car,'getY')
  if type(cx)=='number' and type(cy)=='number' and zz==call(car,'getZ') then
   local dx,dy=zx-cx,zy-cy
   if car==nearest and dx*dx+dy*dy<=math.max(16,(entry.radius or 0)+3)^2 then
    M.metrics.samples=M.metrics.samples+1
    local b=snapshot(z,car,entry.driver);local previous=M.samples[z]
    local c=registerContact(z,previous,b)
    if c then
     for _,p in ipairs(entry.occupants)do local s=M.players[p];if s then s.lastContact=V.now() end end
    end
    b.trackedContact=c~=nil
    local target=call(z,'getTarget');local targetCar=call(target,'getVehicle')
    b.threat=targetCar==car and call(z,'isTargetVisible')==true
    b.attacking=b.threat and call(z,'isAttacking')==true
    b.thumping=call(z,'getThumpTarget')==car
    b.dx=dx;b.dy=dy;b.distance=math.sqrt(dx*dx+dy*dy)
    M.samples[z]=b
    return
   end
  end
 end
 M.samples[z]=nil
end
function M.death(z)
 if M.deaths[z] then return true end
 if A.kind(z)~='zombie' or call(z,'isDead')~=true then return false end
 local a=M.samples[z];if not a or not M.cars[a.car] then return false end
 local b=snapshot(z,a.car,call(a.car,'getDriver'))
 if a.alive~=true or b.collision~=true or b.attacker~=a.driver or a.driver~=b.driver or a.weaponRevision~=b.weaponRevision or a.burning~=false or b.burning~=false or V.now()-a.at>R.maxSampleAge then return false end
 -- OnZombieDead runs inside damage application, before the car adds this
 -- contact. Verify on following ticks instead of pretending callback order differs.
 local seen={};for _,p in ipairs(M.cars[a.car].occupants)do seen[p]=call(p,'CanSee',z)==true end
 M.deaths[z]={before=a,at=V.now(),seen=seen,handled=false}
 return true
end
function M.settle()
 local now=V.now()
 for z,d in pairs(M.deaths)do
 if d.handled and now-d.at>2000 then M.deaths[z]=nil;M.samples[z]=nil;M.contacts[z]=nil
 elseif not d.handled then
  local a=d.before;local b=snapshot(z,a.car,call(a.car,'getDriver'))
  if R.contact(a,b,now) and call(z,'isDead')==true and M.cars[a.car] then
   d.handled=true;local c=registerContact(z,a,b);if c then c.killed=true;c.notified=true end
   M.metrics.kills=M.metrics.kills+1
   if eligible(a.driver) then require('CSV/Experience').mark(a.driver,'zombie') end
   for _,p in ipairs(M.cars[a.car].occupants)do
    local s=M.players[p]
    if s then s.lastContact=now end
    if d.seen[p] then M.offer(p,'kill',{aliveBefore=true,nativeContact=true,driverMatched=true,noInterveningHit=true,dead=true,observed=true})
    else M.offer(p,'impact',{aliveBefore=true,nativeContact=true,driverMatched=true,noInterveningHit=true}) end
   end
   report('kill_confirmed',{event='kill',nativeContact=true,dead=true})
  elseif now-d.at>R.contactSettle or b.driver~=a.driver or b.weaponRevision~=a.weaponRevision or b.burning~=false then
   d.handled=true;M.metrics.rejected=M.metrics.rejected+1;local reasons={}
   if b.collision~=true then reasons[#reasons+1]='collision_flag_missing' end
   if b.contact~=true then reasons[#reasons+1]='native_contact_missing' end
   if b.driver~=a.driver then reasons[#reasons+1]='driver_changed' end
   if b.attacker~=b.driver then reasons[#reasons+1]='attacker_mismatch' end
   if b.weaponRevision~=a.weaponRevision then reasons[#reasons+1]='weapon_hit_intervened' end
   if b.burning~=false then reasons[#reasons+1]='burning_or_unknown' end
   if not M.cars[a.car] then reasons[#reasons+1]='vehicle_untracked' end
   if now-a.at>R.maxSampleAge then reasons[#reasons+1]='sample_stale' end
   if a.contact~=false and a.trackedContact~=true then reasons[#reasons+1]='contact_onset_unproven' end
   if #reasons==0 then reasons[1]='confirmation_timeout' end
   require('CSV/ProductionReport').observe('vehicle_death_rejected',{vehicleReject=table.concat(reasons,','),vehicleSampleAge=now-a.at,vehicleWait=now-d.at,vehicleContact=b.contact,vehicleCollision=b.collision,vehicleDriverMatched=b.driver==a.driver,vehicleAttackerMatched=b.attacker==b.driver,vehicleWeaponBefore=a.weaponRevision,vehicleWeaponAfter=b.weaponRevision})
  end
 end end
 for z,c in pairs(M.contacts)do
  if now-c.last>R.maxSampleAge or not M.cars[c.car] then M.contacts[z]=nil
  elseif not c.notified and now-c.at>=R.contactSettle and not M.deaths[z] then
   c.notified=true
   for _,p in ipairs(M.cars[c.car].occupants)do M.offer(p,'impact',{aliveBefore=true,nativeContact=true,driverMatched=true,noInterveningHit=true})end
  end
 end
end
function M.crowds()
 local now=V.now()
 for p,s in pairs(M.players)do
  local entry=M.cars[s.car];local angles={};local attacks=0;local count=0
  if entry and entry.radius then for z,b in pairs(M.samples)do
   if b.car==s.car and now-b.at<=R.maxSampleAge and b.alive and call(z,'isDead')==false and b.distance<=entry.radius and (b.threat or b.thumping) then
    -- Only perceived threats count; unseen bodies cannot reveal themselves.
    if call(p,'CanSee',z)==true or b.thumping then
     count=count+1;angles[#angles+1]=math.atan2(b.dy,b.dx)
     if b.attacking or b.thumping then attacks=attacks+1 end
    end
   end
  end end
  local around=R.surrounded(angles)
  if around then s.surroundSince=s.surroundSince or now else s.surroundSince=nil end
  s.surrounded=around and now-s.surroundSince>=750;s.attacks=attacks;s.observedAt=now
  s.panic=call(call(p,'getMoodles'),'getMoodleLevel',MoodleType and MoodleType.PANIC)
  if s.surrounded then
   s.clearSince=nil
   M.offer(p,(s.panic or 0)>=3 and attacks>0 and 'siege' or 'crowd',{surrounded=true,targets=count,attacks=attacks,panic=s.panic})
  else
   s.clearSince=s.clearSince or now
   if now-s.clearSince>=R.quietGap then s.siegeLevel=0 end
  end
  if not s.surrounded and s.lastContact and now-s.lastContact>=R.quietGap then
   s.burst=s.burst+1;s.burstSpoken=false;s.lastContact=nil
  end
 end
end
function M.tick()
 if isClient and isClient() then return end
 if V.now()>=(M.nextRefresh or 0) then M.nextRefresh=V.now()+100;M.refresh()end
 M.settle()
 local now=V.now();if now>=M.nextPoll then M.nextPoll=now+250;M.crowds() end
end
function M.attackFacts(p,s)
 local state=M.players[p]
 if state and role(p,state.car)==state.role and V.now()-(state.observedAt or 0)<=R.maxSampleAge and (state.attacks or 0)>0 then
  s.vehicleAttacks=state.attacks;s.directAttack=math.max(s.directAttack or 0,state.attacks);s.encounterThreat=true;s.recentThreat=true
 end
end
function M.install()
 if isClient and isClient() then return end -- Server attribution is a separate MP feature.
 require('CSV/State').vehicleFacts=M.attackFacts
 require('CSV/Connections').install('vehicle-combat',function(t)
  t:event(Events.OnZombieUpdate,function(z)
   if not M.active then return end
   require('CSV/Observers').run('vehicleCombat.zombie',M.observeZombie,z)
  end)
  t:event(Events.OnWeaponHitCharacter,function(a,z)M.weaponHit(a,z)end)
 end)
end
return M
