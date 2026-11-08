local S={}
function S.evidence(group)
 local e={completed=true,before={},after={}}
 local traitCases={TraitRest={traits={sleepy=true},tired=3},TraitWound={traits={slowHealer=true},lingering=true},TraitFumble={traits={allThumbs=true},action='ISInventoryTransferAction',visible=1},TraitReading={traits={slowReader=true},action='ISReadABook',stress=1},TraitStudy={traits={slowLearner=true},action='ISResearchRecipe'},TraitFall={traits={clumsy=true},falling=false},TraitScratch={traits={thinSkin=true},recentCut=true},TraitIlliterate={traits={illiterate=true},inspectLiterature=true}}
 if traitCases[group] then e.kind='trait';e.traitGroup=group;e.verified=true;e.after=traitCases[group];e.after.awake=true;return e end
 local vehicle={VehicleCrowdDriver={'crowd','driver'},VehicleCrowdPassenger={'crowd','passenger'},VehicleSiegeDriver={'siege','driver'},VehicleSiegePassenger={'siege','passenger'},VehicleImpactDriver={'impact','driver'},VehicleImpactPassenger={'impact','passenger'},VehicleKillDriver={'kill','driver'},VehicleKillPassenger={'kill','passenger'}}
 if vehicle[group] then
  local v=vehicle[group]
  return {kind='vehicle_combat',event=v[1],role=v[2],completed=true,verified=true,localAction=true,before={},after={occupied=true},surrounded=true,targets=4,attacks=1,panic=4,aliveBefore=true,nativeContact=true,driverMatched=true,noInterveningHit=true,dead=true,observed=true}
 end
 if group=='Darkness' then e.kind='darkness';e.after={light=.1,awake=true}
 elseif group=='WeaponBroken' then e.kind='swing';e.before.condition=1;e.after.condition=0
 elseif group=='JamCleared' then e.kind='gun';e.before.jammed=true;e.after.jammed=false
 elseif group=='WeaponReady' then e.kind='gun';e.after={condition=5,jammed=false,hasChamber=true,chamber=true,spent=false}
 elseif group=='FuelLow' then e.kind='fuel';e.after={running=true,fuel=8}
 elseif group=='BatteryDead' then e.kind='start';e.before.running=false;e.after={running=false,starting=false,battery=0};e.settled=true
 elseif group=='EngineFailed' then e.kind='start';e.before.running=false;e.after={running=false,starting=false,battery=.8};e.settled=true
 elseif group=='EngineRecovered' then e.kind='vehicle_recovered';e.before.running=false;e.after.running=true;e.failedStart=true;e.localAction=true
 elseif group=='EngineStalled' then e.kind='vehicle_stop';e.before={running=true,fuel=40};e.after={running=false,fuel=40};e.nativeCause='damage';e.localAction=true
 elseif group=='FuelEmpty' then e.kind='vehicle_stop';e.before={running=true,fuel=.5};e.after={running=false,fuel=0};e.nativeCause='fuel';e.localAction=true
 elseif group=='HotwireDone' then e.kind='vehicle_hotwire';e.before.hotwired=false;e.after.hotwired=true;e.localAction=true
 elseif group=='CarAlarm' then e.kind='vehicle_alarm';e.before.alarm=false;e.after.alarm=true;e.localAction=true;e.synchronous=true
 elseif group=='HeadlightsFailed' then e.kind='vehicle_lights';e.before.lights=false;e.after={lights=true,canLight=false,battery=.5,dark=true};e.localAction=true
 elseif group=='BandageDone' then e.kind='bandage';e.before.bandaged=false;e.after.bandaged=true
 elseif group=='DisinfectDone' then e.kind='disinfect';e.before.alcohol=0;e.after.alcohol=3
 elseif group=='DoorLocked' then e.kind='door';e.before.open=false;e.after={open=false,locked=true}
 elseif group=='DoorBlocked' then e.kind='door';e.before.open=false;e.after={open=false,blocked=true} end
 return e
end
function S.cases()
 local cases={}
 for group in pairs(require('CSV/OutcomeRules').groups)do
  for _,mode in ipairs({'safe','whisper','concealed','combat','cancelled','unknown'})do
   local e=S.evidence(group);local f={outcome=e,sneaking=mode=='whisper' or mode=='concealed',near=mode=='combat' and 2 or 0,accessibleNear=mode=='combat' and 2 or 0,visible=mode=='combat' and 2 or 0,recentThreat=mode=='combat',panic=0}
   if mode=='cancelled' then e.cancelled=true end
   if mode=='unknown' then f.outcome=nil end
   local muted=mode=='concealed' or mode=='combat' and not ({TraitFumble=true,WeaponBroken=true,EngineStalled=true,FuelEmpty=true,CarAlarm=true,HeadlightsFailed=true,VehicleCrowdDriver=true,VehicleCrowdPassenger=true,VehicleSiegeDriver=true,VehicleSiegePassenger=true,VehicleImpactDriver=true,VehicleImpactPassenger=true,VehicleKillDriver=true,VehicleKillPassenger=true})[group] or mode=='cancelled' or mode=='unknown'
   cases[#cases+1]={name=group..': '..mode,group=group,level=1,max=1,state=f,prefs={whisper=mode=='whisper'},expect=(mode=='cancelled' or mode=='unknown') and 'none' or group,mode=muted and 'silent' or 'spoken',newOutcomes=true,limited='none'}
  end
 end
 local negatives={
  {'Darkness','light_restored',function(e)e.after.light=.8 end},
  {'Darkness','asleep',function(e)e.after.awake=false end},
  {'Darkness','unknown_light',function(e)e.after.light=nil end},
  {'VehicleCrowdDriver','one_side_only',function(e)e.surrounded=false end},
  {'VehicleCrowdPassenger','only_three',function(e)e.targets=3 end},
  {'VehicleSiegeDriver','no_panic',function(e)e.panic=0 end},
  {'VehicleSiegePassenger','not_attacking',function(e)e.attacks=0 end},
  {'VehicleImpactDriver','no_native_contact',function(e)e.nativeContact=false end},
  {'VehicleImpactPassenger','already_dead',function(e)e.aliveBefore=false end},
  {'VehicleKillDriver','other_driver',function(e)e.driverMatched=false end},
  {'VehicleKillPassenger','not_seen',function(e)e.observed=false end},
  {'VehicleKillDriver','weapon_intervened',function(e)e.noInterveningHit=false end},
  {'VehicleKillPassenger','survived_hit',function(e)e.dead=false end},
  {'VehicleImpactDriver','left_car',function(e)e.after.occupied=false end},
  {'VehicleImpactPassenger','unknown_seat',function(e)e.role=nil end},
  {'EngineRecovered','ordinary_start',function(e)e.failedStart=false end},
  {'EngineRecovered','already_running',function(e)e.before.running=true end},
  {'EngineStalled','manual_stop',function(e)e.manual=true end},
  {'EngineStalled','unknown_cause',function(e)e.nativeCause=nil end},
  {'FuelEmpty','unknown_fuel',function(e)e.before.fuel=nil;e.nativeCause=nil end},
  {'FuelEmpty','manual_stop_empty_tank',function(e)e.manual=true end},
  {'HotwireDone','already_hotwired',function(e)e.before.hotwired=true end},
  {'HotwireDone','failed_attempt',function(e)e.after.hotwired=false end},
  {'CarAlarm','nearby_only',function(e)e.synchronous=false end},
  {'CarAlarm','already_active',function(e)e.before.alarm=true end},
  {'HeadlightsFailed','daylight',function(e)e.after.dark=false end},
  {'HeadlightsFailed','working_light',function(e)e.after.canLight=true end},
  {'HeadlightsFailed','empty_battery',function(e)e.after.battery=0 end},
  {'HeadlightsFailed','switched_off',function(e)e.after.lights=false end},
 }
 for _,row in ipairs(negatives)do
  local e=S.evidence(row[1]);row[3](e)
  cases[#cases+1]={name=row[1]..': '..row[2],group=row[1],level=1,max=1,state={outcome=e,sneaking=false,near=0,visible=0,recentThreat=false,panic=0},expect='none',mode='silent',newOutcomes=true}
 end
 table.sort(cases,function(a,b)return a.name<b.name end);return cases
end
return S
