local R={groups={EngineRecovered='VehicleDamage',EngineStalled='VehicleDamage',FuelEmpty='VehicleDamage',HotwireDone='VehicleDamage',CarAlarm='VehicleDamage',HeadlightsFailed='VehicleDamage'}}
R.urgent={EngineStalled=true,FuelEmpty=true,CarAlarm=true,HeadlightsFailed=true}
for g,parent in pairs(require('CSV/VehicleCombatRules').groups)do R.groups[g]=parent;R.urgent[g]=true end
function R.classify(e)
 if e and e.kind=='vehicle_combat' then return require('CSV/VehicleCombatRules').classify(e) end
 if not e or e.completed~=true or e.cancelled or e.localAction~=true then return nil end
 local a,b=e.before or {},e.after or {}
 if e.kind=='vehicle_recovered' and e.failedStart==true and a.running==false and b.running==true then return 'EngineRecovered' end
 if e.kind=='vehicle_stop' and a.running==true and b.running==false and e.manual~=true then
  -- A stop alone cannot distinguish the key, a mod, damage or fuel starvation.
  if e.nativeCause=='fuel' and type(a.fuel)=='number' and a.fuel>0 and b.fuel==0 then return 'FuelEmpty' end
  if e.nativeCause=='damage' or e.nativeCause=='fuel' then return 'EngineStalled' end
 end
 if e.kind=='vehicle_hotwire' and a.hotwired==false and b.hotwired==true then return 'HotwireDone' end
 if e.kind=='vehicle_alarm' and e.synchronous==true and a.alarm==false and b.alarm==true then return 'CarAlarm' end
 if e.kind=='vehicle_lights' and a.lights==false and b.lights==true and b.canLight==false and type(b.battery)=='number' and b.battery>0 and b.dark==true then return 'HeadlightsFailed' end
end
return R
