local P={groups={}}
for group in pairs(require('CSV/ReloadRules').groups)do P.groups[group]='urgent' end
P.groups['Panic']='panic'
P.groups['PanicCallback']='panic'
P.groups['Agoraphobic']='phobia'
P.groups['Claustrophobic']='phobia'
P.groups['GunJammed']='urgent'
P.groups['LowAmmo']='urgent'
P.groups.AmmoCount='urgent';P.groups.ChamberEmpty='urgent'
P.groups['OutOfAmmo']='urgent'
P.groups['MultiHit']='urgent'
P.groups['VehicleDamage']='urgent'
P.groups['Bleeding']='physical'
P.groups['Pain']='physical'
P.groups['Injured']='physical'
P.groups['Endurance']='physical'
P.groups['CantSprint']='physical'
P.groups['HasACold']='condition'
P.groups['HeavyLoad']='condition'
P.groups['Hungry']='condition'
P.groups['Hyperthermia']='condition'
P.groups['Hypothermia']='condition'
P.groups['Sick']='condition'
P.groups['SickFromFood']='condition'
P.groups['Thirst']='condition'
P.groups['Tired']='condition'
P.groups['Wet']='condition'
P.groups['Windchill']='condition'
P.groups['NoxiousSmell']='condition'
P.groups['Bored']='emotion'
P.groups['Drunk']='emotion'
P.groups['Stress']='emotion'
P.groups['Unhappy']='emotion'
P.groups['Angry']='emotion'
P.groups['Uncomfortable']='emotion'
P.groups['AnimalTracks']='routine'
P.groups['ChopTree']='routine'
P.groups['Explore']='routine'
P.groups['FoodEaten']='routine'
P.groups['FoodRaw']='routine'
P.groups['FoodRotten']='routine'
P.groups['Foraged']='routine'
P.groups['FoundLoot']='routine'
P.groups['Holes']='routine'
P.groups['Kill']='routine'
P.groups['LevelUp']='routine'
P.groups['OnDawn']='routine'
P.groups['OnDusk']='routine'
P.groups.Threat='threat'
P.groups.AcutePain='physical'
P.groups.ReliefThreat='relief';P.groups.ReliefBleeding='relief';P.groups.ReliefEndurance='relief';P.groups.ReliefThirst='relief'
for group in pairs(require('CSV/RecoveryRules'))do P.groups[group]='relief' end
for group in pairs(require('CSV/LootRules').groups)do P.groups[group]='loot' end
for group in pairs(require('CSV/OutcomeRules').groups)do P.groups[group]=require('CSV/OutcomeRules').urgent(group) and 'urgent' or 'outcome' end
P.groups.Psychology='psychology';P.groups.Startle='startle'
function P.decide(group,intensity,s,prefs)
 s=s or {};prefs=prefs or {};local kind=P.groups[group]
 local function result(mode,reason,radius,priority,allowStealth)
  return {mode=mode,reason=reason,radius=radius,noiseRadius=radius,priority=priority or 1,allowStealth=allowStealth==true}
 end
 if not kind then return result('upstream','unmanaged_group') end
 if group=='Panic' and s.fire==true then return result('spoken','on_fire',15,4,true) end
 if group=='AcutePain' and s.acute==true then return result('spoken','fresh_injury',8,4,true) end
 local concealment=require 'CSV/Concealment'
 if group=='Startle' then
  if not s.nativeAlert then return result('silent','unverified_alert')end
  if concealment.active(s) then local d=result('spoken','native_alert_attack',6,3);d.engaged=true;return d end
  if s.sneaking==true then
   if (s.whisperRisk or 0)>0 then return result('silent','whisper_would_reveal')end
   if prefs.whisper and s.contextWhisperAvailable then return result('spoken','recorded_context_whisper',2,2,true)end
   return result('silent','concealment')
  end
  if s.sneaking~=false then return result('silent','unknown_concealment')end
  return result('spoken','native_alert',4,3)
 end
 -- Attack evidence overrides crouching, but does not permit irrelevant comments.
 if concealment.active(s) then
  if kind=='psychology' and s.psychology and s.psychology.verified==true and s.psychology.kind=='zombieKill' and s.sneaking==false and (s.directAttack or 0)==0 then
   local d=result('spoken','verified_kill',6,2);d.engaged=true;return d
  end
  local urgent=kind=='panic' or kind=='threat' or kind=='urgent' or kind=='physical' and (intensity or 0)>=3
   or kind=='psychology' and require('CSV/PsychologyRules').urgent(s.psychology)
  if urgent then
   local decision=result('spoken','active_attack',(s.panic or 0)>=3 and 12 or 6,3)
   decision.engaged=true;decision.delivery=(s.panic or 0)>=3 and 'frightened' or 'urgent'
   decision.noiseRadius=decision.radius;return decision
  end
  if not (group=='AcutePain' and s.acute or group=='Panic' and s.fire) then return result('silent','active_attack_defer')end
 end
 if concealment.open(s) then
  local standing={};for k,v in pairs(s)do standing[k]=v end;standing.sneaking=false
  local decision=P.decide(group,intensity,standing,prefs)
  if decision.mode=='spoken' then decision.radius=math.min(require('CSV/Hearing').quietRadius,decision.radius);decision.noiseRadius=decision.radius;decision.exposed=true;decision.reason='exposed_close_'..decision.reason end
  return decision
 end
 if s.sneaking==true and (s.whisperRisk or 0)>0 then return result('silent','whisper_would_reveal')end
 if kind=='psychology' then
  local R=require('CSV/PsychologyRules');local e=s.psychology
  if not R.pool(e,s) then return result('silent','unverified_psychology')end
  local danger=s.humanThreat==true or s.recentThreat==true or (s.near or 0)>0 or (s.visible or 0)>0
  if R.defer(e) and (danger or s.near~=0 or s.visible~=0 or s.recentThreat~=false) then return result('silent','aftermath_wait_for_safety')end
  if s.sneaking==true then
   if prefs.whisper and s.contextWhisperAvailable then return result('spoken','recorded_context_whisper',2,2,true)end
   return result('silent','concealment')
  end
  if s.sneaking~=false then return result('silent','unknown_concealment')end
  return result('spoken',e.kind=='zombieKill' and 'verified_kill' or 'verified_psychology',R.urgent(e) and 8 or 4,R.urgent(e) and 3 or e.kind=='zombieKill' and 2 or 1)
 end
 if (kind=='loot' or group=='FoundLoot') and not require('CSV/LootRules').allowed(group,prefs) then return result('silent','loot_option_disabled') end
 if kind=='loot' and (s.near~=0 or s.visible~=0 or s.recentThreat~=false) then return result('silent','loot_wait_for_safety') end
 -- Actual fire and fresh physical damage may cause an involuntary cry even while crouched.
 if s.sneaking==true then
  if prefs.whisper and s.whisperAvailable and (kind=='threat' or kind=='panic') and (s.near or 0)>0 then
   return result('spoken','recorded_whisper',2,2,true)
  end
  if prefs.whisper and s.contextWhisperAvailable then
   if (s.attacking or 0)>0 and kind~='physical' and kind~='urgent' and kind~='panic' then return result('silent','active_attack_defer') end
   return result('spoken','recorded_context_whisper',2,kind=='urgent' and 2 or 1,true)
  end
  return result('silent','concealment')
 end
 if s.sneaking~=false then return result('upstream','unknown_concealment') end
 local near=s.accessibleNear or s.near
 local close=type(near)=='number' and near>0 or (s.exposedNpc or 0)+(s.exposedPlayer or 0)>0
 local danger=s.humanThreat==true or (s.near or 0)>0 or (s.visible or 0)>0 or s.recentThreat==true
 local evidence=require('CSV/ThreatEvidence').kind(s)
 if evidence=='attacking' then close=true end
 if (kind=='threat' or kind=='panic') and evidence=='unknown' and s.targeted~=nil then return result('silent','awaiting_threat_evidence') end
 if (kind=='threat' or kind=='panic') and (evidence=='blocked' or evidence=='observed_only') then
  if kind=='threat' and evidence=='observed_only' and (s.panic or 0)<3 then return result('spoken','observed_calm_warning',4,2) end
  return result('silent','no_active_threat_'..evidence)
 end
 if group=='Threat' then
  if close and type(s.panic)=='number' and s.panic<3 then
   return result('spoken',s.panic==0 and 'controlled_warning' or 'tense_warning',s.panic==0 and 6 or 8,2)
  end
  return result('silent','no_controlled_close_threat')
 end
 if kind=='panic' and close and type(s.panic)=='number' and s.panic>=3 then return result('spoken','close_threat_high_panic',15,3) end
 if close and kind=='panic' and type(s.panic)=='number' and s.panic>0 then return result('spoken','tense_warning',8,2) end
 if close and kind=='urgent' then return result('spoken','immediate_problem',8,3) end
 if close and kind=='physical' and (intensity or 0)>=3 then return result('spoken','severe_physical_problem',8,3) end
 -- A verified firearm fault matters even if threats are farther than six tiles.
 -- Stealth, attack priority and unknown concealment have already been resolved.
 if group=='GunJammed' and s.jammed==true or group=='OutOfAmmo' and s.empty==true then
  return result('spoken','verified_firearm_problem',4,2)
 end
 if danger then return result('silent','danger_defer_'..kind) end
 if require('CSV/OutcomeRules').urgent(group) and s.near==0 and s.visible==0 and s.recentThreat==false then return result('spoken',group=='WeaponBroken' and 'verified_weapon_break' or 'verified_vehicle_problem',6,2) end
 if kind=='loot' then return result('spoken','useful_loot',4,1) end
 if kind=='outcome' then return result('spoken','verified_action_result',4,1) end
 if kind=='relief' then return result('spoken','verified_relief',4,1) end
 if prefs.safeSpeech and s.near==0 and s.visible==0 and s.recentThreat==false then
  return result('spoken','safe_comment',4,1)
 end
 return result('upstream','source_mood_filters')
end
return P
