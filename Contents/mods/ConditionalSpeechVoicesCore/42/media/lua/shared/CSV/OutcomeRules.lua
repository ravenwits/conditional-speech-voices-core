local R={groups={Darkness='Explore',WeaponBroken='LowAmmo',JamCleared='GunJammed',WeaponReady='LowAmmo',FuelLow='VehicleDamage',BatteryDead='VehicleDamage',EngineFailed='VehicleDamage',BandageDone='Injured',DisinfectDone='Pain',DoorLocked='Explore',DoorBlocked='Explore'}}
for g,parent in pairs(require('CSV/TraitSpeechRules').groups)do R.groups[g]=parent end
for g,parent in pairs(require('CSV/VehicleRules').groups)do R.groups[g]=parent end
function R.urgent(g)return g=='WeaponBroken' or require('CSV/VehicleRules').urgent[g]==true end
function R.ready(f)
 if not f or f.jammed~=false or type(f.condition)~='number' or f.condition<=0 then return false end
 if f.hasChamber==true then return f.chamber==true and f.spent==false end
 return f.hasChamber==false and type(f.rounds)=='number' and type(f.perShot)=='number' and f.rounds>=f.perShot
end
-- A group name alone is never proof an action succeeded.
function R.classify(e)
 if not e or e.completed~=true or e.cancelled==true then return nil end
 if e.kind and e.kind:match('^vehicle_') then return require('CSV/VehicleRules').classify(e) end
 if e.kind=='trait' then return require('CSV/TraitSpeechRules').classify(e) end
 local a,b=e.before or {},e.after or {}
 if e.kind=='darkness' and b.awake==true and type(b.light)=='number' and b.light>=0 and b.light<=.18 then return 'Darkness' end
 if e.kind=='swing' and type(a.condition)=='number' and a.condition>0 and b.condition==0 then return 'WeaponBroken' end
 if e.kind=='gun' then
  if a.jammed==true and b.jammed==false then return 'JamCleared' end
  if not R.ready(a) and R.ready(b) then return 'WeaponReady' end
 elseif e.kind=='bandage' and a.bandaged==false and b.bandaged==true then return 'BandageDone'
 elseif e.kind=='disinfect' and type(a.alcohol)=='number' and type(b.alcohol)=='number' and b.alcohol>a.alcohol then return 'DisinfectDone'
 elseif e.kind=='window' and a.open==false and b.open==false and b.destroyed~=true then
  if b.blocked==true then return 'DoorBlocked' end
  if b.locked==true and e.nativeSound=='locked' then return 'DoorLocked' end
 elseif e.kind=='car_door' and a.open==false and b.open==false and b.locked==true then return 'DoorLocked'
 elseif e.kind=='door' and a.open==false and b.open==false then
  if b.blocked==true then return 'DoorBlocked' end
  if b.locked==true then return 'DoorLocked' end
 elseif e.kind=='start' and a.running==false and b.running==false and b.starting==false and e.settled==true then
  if b.battery==0 then return 'BatteryDead' end
  return 'EngineFailed'
 elseif e.kind=='fuel' and b.running==true and type(b.fuel)=='number' and b.fuel>=0 and b.fuel<15 then return 'FuelLow' end
end
-- Only the object-neutral blocked-passage line fits a barricaded window.
function R.allowedLine(id,e)
 return not (e and e.kind=='window' and R.classify(e)=='DoorBlocked') or id=='DoorBlocked_3'
end
return R
