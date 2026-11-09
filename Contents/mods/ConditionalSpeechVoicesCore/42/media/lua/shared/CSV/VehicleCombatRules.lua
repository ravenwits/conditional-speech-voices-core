local R={groups={},maxSampleAge=500,contactSettle=250,quietGap=6000}
for _,stem in ipairs({'VehicleCrowd','VehicleSiege','VehicleImpact','VehicleKill'})do
 for _,role in ipairs({'Driver','Passenger'})do R.groups[stem..role]='VehicleDamage' end
end
-- Three occupied quadrants alone can still be a crowd on one side. Require
-- at least four threats and no empty angular half-circle around the vehicle.
function R.surrounded(angles)
 if #angles<4 then return false end
 local sorted={};for i,a in ipairs(angles)do sorted[i]=a end;require('CSV/Sort').sort(sorted)
 local gap=sorted[1]+math.pi*2-sorted[#sorted]
 for i=2,#sorted do gap=math.max(gap,sorted[i]-sorted[i-1])end
 return gap<math.pi
end
function R.contact(a,b,now)
 return a and b and a.alive==true and b.contact==true and b.collision==true
  and (a.contact==false or a.trackedContact==true)
  and a.car==b.car and a.driver~=nil and a.driver==b.driver and b.attacker==b.driver
  and a.weaponRevision==b.weaponRevision and a.burning==false and b.burning==false
  and now>=a.at and now-a.at<=R.maxSampleAge
end
function R.classify(e)
 if not e or e.kind~='vehicle_combat' or e.completed~=true or e.cancelled or e.verified~=true then return nil end
 local role=e.role=='driver' and 'Driver' or e.role=='passenger' and 'Passenger'
 if not role or not e.after or e.after.occupied~=true then return nil end
 if e.event=='crowd' or e.event=='siege' then
  if e.surrounded~=true or (e.targets or 0)<4 then return nil end
  if e.event=='siege' and ((e.panic or 0)<3 or (e.attacks or 0)<1) then return nil end
  return (e.event=='siege' and 'VehicleSiege' or 'VehicleCrowd')..role
 end
 if e.aliveBefore~=true or e.nativeContact~=true or e.driverMatched~=true or e.noInterveningHit~=true then return nil end
 if e.event=='impact' then return 'VehicleImpact'..role end
 if e.event=='kill' and e.dead==true and e.observed==true then return 'VehicleKill'..role end
end
return R
