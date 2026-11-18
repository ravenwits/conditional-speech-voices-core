-- These IDs remain known to PackSemantics for loading older providers. They
-- cannot be selected by the supported gameplay routes and need no recording.
local retired={}
local function add(ids,reason)
 for _,id in ipairs(ids)do retired[id]=reason end
end

-- Rules.pool excludes these indexed choices. Dedicated paths still use the
-- retained severity tiers, pickup, tree, wet, critical and kill fallbacks.
add({
 'AnimalTracks_2','AnimalTracks_3','Bleeding_2','Explore_1','Explore_3',
 'FoodRotten_2','FoodRotten_3','Foraged_2','FoundLoot_1','FoundLoot_2',
 'HeavyLoad_1','Holes_3','Hyperthermia_1','Hypothermia_1','Injured_1',
 'NoxiousSmell_1','NoxiousSmell_2','OnDawn_3','Pain_2','Thirst_3','VehicleDamage_3',
},'excluded_base_pool')
add({'Kill_3'},'kill_uses_dedicated_pools')
add({'PanicCallback_1','PanicCallback_2','PanicCallback_3'},'panic_callback_uses_panic_pool')
add({'Uncomfortable_1','Uncomfortable_2','Uncomfortable_3'},'discomfort_replaces_base_pool')
-- Conditions.choose handles SickFromFood even if the FoodSuspect bank has
-- no available clip. The old SickFromFood pool is never reached.
add({'SickFromFood_1','SickFromFood_2','SickFromFood_3'},'food_suspect_replaces_base_pool')

-- These reactions require an occupied seat at playback. CarAlarm also has
-- an exterior path, so its whispers remain eligible.
local seated={
 BatteryDead=true,EngineFailed=true,EngineRecovered=true,EngineStalled=true,
 FuelEmpty=true,FuelLow=true,HeadlightsFailed=true,HotwireDone=true,
 TraitDriver=true,VehicleDamage=true,VehicleCrowdDriver=true,VehicleCrowdPassenger=true,
 VehicleImpactDriver=true,VehicleImpactPassenger=true,VehicleKillDriver=true,
 VehicleKillPassenger=true,VehicleSiegeDriver=true,VehicleSiegePassenger=true,
}
local semantics=require 'CSV/PackSemantics'
for source,entry in pairs(semantics.whispers)do
 if seated[entry.group] then retired[entry.id]='requires_vehicle_seat'
 elseif retired[source] then retired[entry.id]='source_unreachable' end
end
for id,entry in pairs(semantics.expressions)do
 if retired[entry.source] and (not entry.groupFallback or entry.group=='SickFromFood') then
  retired[id]='source_unreachable'
 end
end
for id,entry in pairs(require('CSV/VoiceAlternates'))do
 if retired[entry.source] then retired[id]='source_unreachable' end
end
return retired
