local function emit(f,fn)if type(f)=='table' and f.defer then f:defer(fn)else f:write(fn())end end
local R={rows={},count=0,started=getTimestampMs(),observations={},nextSave=0}
local keys={'vehicleReject','vehicleSampleAge','vehicleWait','vehicleCollision','vehicleDriverMatched','vehicleAttackerMatched','vehicleWeaponBefore','vehicleWeaponAfter','vehicleEvent','vehicleRole','vehicleTargets','vehicleAttacks','vehicleContact','vehicleDeath','vehicleCause','vehicleManual','vehicleSynchronous','nativeAlert','encounterThreat','exposureChecked','attackGrace','nicotineStress','outside','humanThreat','npcVisible','psychologyKind','actorKind','experience','outcomeNativeSound','outcomeKind','outcomeGroup','lootThirst','lootDark','lootWater','lootLight','lootOtherLight','lootClothing','lootCold','lootKind','lootItem','lootReserve','lootHunger','lootPain','recentThreat','engineLastSeen','near','visible','panic','sneaking','targeted','approaching','attacking','blockedNear','accessibleNear','reactiveNear','reactiveCrowd','bleeding','endurance','thirst','health','fire','acute','jammed','empty','rounds','chamber','hasChamber','anger','boredom','drunk','hunger','cold','heat','tired','pain','stress','wet','load','sick','coldSymptoms','unhappy','discomfort'}
local function factsText(f)
 local t={};for _,key in ipairs(keys)do t[#t+1]=key..'='..tostring((f or {})[key])end;return table.concat(t,' ')
end
function R.record(group,outcome,info)
 info=info or {};local key=table.concat({info.voice or 'unknown',group or '-',tostring(info.intensity or 0),outcome or '-',info.threatKind or '-',info.line or '-',info.policy or '-'},'|')
 local row=R.rows[key]
 if not row then
  if R.count>=2048 then R.dropped=(R.dropped or 0)+1;return end
  row={count=0,first=getTimestampMs()};R.rows[key]=row;R.count=R.count+1
 end
 row.count=row.count+1;row.last=getTimestampMs();row.line=info.line or '-';row.text=info.text or '-';row.policy=info.policy or '-';row.remaining=info.remainingMs or 0;row.facts=factsText(info.facts)
end
function R.observe(name,facts)
 local o=R.observations[name] or {count=0};R.observations[name]=o;o.count=o.count+1;o.last=getTimestampMs();o.facts=factsText(facts)
end
-- Kahlua's recursive quicksort can overflow on the grouped full audio bank.
local function sortInventory(keys)
 local count=#keys;local width=1;local buffer={}
 while width<count do
  for left=1,count,width*2 do
   local middle=math.min(left+width,count+1)
   local finish=math.min(left+width*2,count+1)
   local a,b=left,middle
   for index=left,finish-1 do
    if a<middle and (b>=finish or keys[a]<=keys[b]) then
     buffer[index]=keys[a];a=a+1
    else buffer[index]=keys[b];b=b+1 end
   end
  end
  for index=1,count do keys[index]=buffer[index]end
  width=width*2
 end
end
function R.export(writer,compact)
 local f=writer or require('CSV/ReportWriter').open('CSV-production-report.txt');if not f then return false end
 local preparationStarted=getTimestampMs()
 local V=require 'CSV/Core';local C=V.client;local N=require 'CSV/NeedTiming'
 emit(f,function()return 'CSV production evidence v'..require('CSV/Core').version..'\nSessionStart='..R.started..' ExportedAt='..getTimestampMs()..' droppedRows='..(R.dropped or 0)..'\n' end)
 emit(f,function()return 'NOT OBSERVED is not missing audio. Preview is not gameplay. no_eligible_recording needs semantic review; missing_audio_file is a packaging defect. Silence/cooldown does not require synthesis.\n' end)
 if C then emit(f,function()return 'Settings '..C.settingsSnapshot()..'\n' end)end
 if C and C.lastMix then local mix=C.lastMix
  emit(f,function()return 'PLAYBACK_MIX line='..mix.line..' gain='..mix.gain..' requested='..mix.requested..' nearbyBoost='..mix.presence..' peakLimited='..tostring(mix.limited)..'\n' end)
 end
 local psychology=require 'CSV/Psychology'
 emit(f,function()return 'PSYCHOLOGY installed='..tostring(psychology.installed==true)..' error='..tostring(psychology.error==true)..' alifeBridge='..tostring(ProjectALife and ProjectALife.Executor and ProjectALife.Executor._csvWoundObserved==true)..'\n' end)
 for player,state in pairs(psychology.players)do
  local md=require('CSV/Actors').call(player,'getModData') or {};local e=md.csvExperience or {zombie=0,human=0,injury=0,raid=0,historyUnknown=true}
  emit(f,function()return 'EXPERIENCE zombie='..e.zombie..' nativeZombieKills='..tostring(e.nativeZombieKills)..' zombieEncounters='..tostring(e.zombieEncounters or 0)..' humanEncounters='..tostring(e.humanEncounters or 0)..' human='..e.human..' injury='..e.injury..' raid='..e.raid..' pastUnknown='..tostring(e.historyUnknown)..' queued='..#state.queue..' tracking='..tostring(state.track and state.track.mode)..'\n' end)
 end
 for name,status in pairs(require('CSV/Observers').status)do
  emit(f,function()return 'OBSERVER '..name..' calls='..status.calls..' errors='..status.errors..' failed='..tostring(status.failed)..' lastError='..tostring(status.lastError)..' totalMs='..tostring(status.totalMs or 0)..' maxMs='..tostring(status.maxMs or 0)..'\n' end)
 end
 for name,status in pairs(require('CSV/Connections').groups)do
  emit(f,function()return 'CONNECTION '..name..' installed='..tostring(status.installed)..' errors='..status.errors..' lastError='..tostring(status.lastError)..' totalMs='..tostring(status.totalMs or 0)..' maxMs='..tostring(status.maxMs or 0)..'\n' end)
 end
 local bridge=require 'CSV/ALifeBridge'
 emit(f,function()return 'ALIFE status='..bridge.status..' lastError='..tostring(bridge.lastError)..'\n' end)
 local hearing=require 'CSV/Hearing'
 emit(f,function()return 'HEARING source='..tostring(hearing.lastSource)..' fallbackMultiplier='..hearing.fallback()..' appliedToRiskOnly=true\n' end)
 local metrics=require('CSV/State').metrics
 emit(f,function()return 'STATE captures='..metrics.captures..' reads='..metrics.reads..' cacheHits='..metrics.hits..' visitedBodies='..metrics.visits..' totalReadMs='..metrics.readMs..' maxReadMs='..metrics.maxReadMs..'\n' end)
 local selection=require('CSV/Selection').metrics
 local builds,indexed,candidates=selection.indexBuilds,selection.indexed,selection.candidates
 emit(f,function()return 'SELECTION indexBuilds='..builds..' indexed='..indexed..' candidates='..candidates..'\n'end)
 local diagnostics=require('CSV/ApiDiagnostics')
 local total,overflow=diagnostics.total,diagnostics.overflow
 emit(f,function()return 'API_FAILURES total='..total..' overflow='..overflow..'\n'end)
 for name,row in pairs(diagnostics.rows)do
  local count,last=row.count,row.last
  emit(f,function()return 'API_FAILURE method='..name..' count='..count..' last='..last..'\n'end)
 end
 local lootMetrics=require('CSV/Loot').metrics
 if lootMetrics then
  local scans,items,maximum=lootMetrics.scans,lootMetrics.items,lootMetrics.maxItems
  emit(f,function()return 'INVENTORY scans='..scans..' items='..items..' maxItems='..maximum..'\n'end)
 end
 local manager=require('CSV/SpeechManager');local m=manager.metrics
 emit(f,function()return 'SPEECH_MANAGER pending='..#manager.queue..' submitted='..m.submitted..' accepted='..m.played..' expired='..m.expired..' cancelled='..m.cancelled..' blocked='..m.blocked..' retryPlansSkipped='..(m.retrySkipped or 0)..'\n' end)
 local writes=require('CSV/ReportWriter').metrics
 emit(f,function()return 'REPORT_WRITER completed='..writes.completed..' failed='..writes.failed..' maxSliceMs='..writes.maxSliceMs..' maxOpenMs='..(writes.maxOpenMs or 0)..' maxPrepareMs='..(R.maxPrepareMs or 0)..'\n' end)
 require('CSV/AlpCallout').export(f)
 local native=require 'CSV/NativeVoice'
 emit(f,function()return 'VOICE_NATIVE_ACTIVITY scope=active_event_windows includesSilentSlots=true selectedTakeUnknown=true errors='..native.errors..'\n' end)
 emit(f,function()return 'VOICE_BREATH source=parameter_driven_native_event individualTakesObservable=false activeWindows='..native.ambient.windows..' activeScans='..native.ambient.activeScans..' scans='..native.ambient.scans..'\n' end)
 for name,count in pairs(native.activity)do emit(f,function()return 'VOICE_NATIVE_EVENT name='..name..' activeWindows='..count..'\n' end)end
 local spatial=require('CSV/Playback').spatial
 emit(f,function()return 'PLAYBACK_SPATIAL localForced2d='..spatial.self2d..' worldPositionUpdates='..spatial.worldPositionUpdates..' actorsMovedWhileTalking='..spatial.movedWhileTalking..'\n' end)
 local reload=require 'CSV/Reload';local rm=reload.metrics
 emit(f,function()return 'RELOAD starts='..rm.starts..' ineligible='..rm.ineligible..' evaluations='..rm.evaluations..' requests='..rm.requests..' finished='..rm.finished..' cancelled='..rm.cancelled..'\n' end)
 for name,hook in pairs(reload.hooks)do emit(f,function()return 'RELOAD_HOOK '..name..' startUnchanged='..tostring(hook.class.start==hook.start)..'\n' end)end
 if reload.last then local last=reload.last
  emit(f,function()return 'RELOAD_LAST group='..last.group..' reason='..last.reason..' panic='..tostring(last.panic)..' near='..tostring(last.near)..' visible='..tostring(last.visible)..' sneaking='..tostring(last.sneaking)..' at='..last.at..'\n' end)
 end
 local observer=require 'CSV/Outcomes'
 local vehicle=require('CSV/VehicleCombat').metrics
 emit(f,function()return 'VEHICLE_COMBAT samples='..vehicle.samples..' contacts='..vehicle.contacts..' confirmedKills='..vehicle.kills..' rejectedDeaths='..vehicle.rejected..'\n' end)
 emit(f,function()return 'ACTION_OBSERVERS watching='..#observer.watch..' pending='..#observer.pending..' error='..tostring(observer.error==true)..'\n' end)
 for name,ok in pairs(observer.hooks)do emit(f,function()return 'ACTION_HOOK '..name..' installed='..tostring(ok)..'\n' end)end
 local coverage={}
 for key,row in pairs(R.rows)do local group=key:match('^[^|]+|([^|]+)|');if group then coverage[group]=(coverage[group] or 0)+row.count end end
 local groups={};for group in pairs(require('CSV/Delivery').groups)do groups[#groups+1]=group end;table.sort(groups)
 for _,group in ipairs(groups)do
  local count=coverage[group] or 0
  emit(f,function()return 'COVERAGE '..group..' attempts='..count..' status='..(count==0 and 'NOT_OBSERVED' or 'OBSERVED')..' mildNormalIntervalSeconds='..tostring(N.seconds[group] or 'event-specific')..'\n' end)
 end
 local names={};for key in pairs(R.rows)do names[#names+1]=key end;sortInventory(names)
 for _,key in ipairs(names)do local row=R.rows[key]
  emit(f,function()return 'DECISION '..key..' count='..row.count..' first='..row.first..' last='..row.last..' line='..row.line..' policy='..row.policy..' remainingMs='..row.remaining..' text='..row.text..' '..row.facts..'\n' end)
 end
 for name,o in pairs(R.observations)do emit(f,function()return 'OBSERVATION '..name..' count='..o.count..' last='..o.last..' '..o.facts..'\n' end)end
 require('CSV/Trace').export(f)
 emit(f,function()return 'INVENTORY includes debug-only recordings; existence does not prove appropriate acting.\n' end)
 local trace=require('CSV/Trace')
 emit(f,function()return 'INVENTORY_SCOPE '..(compact and 'observed_only; omitted assets have no recorded activity in this session' or 'all_available')..'\n' end)
 local clips={}
 for key in pairs(compact and trace.assets or V.data.clips)do if V.data.clips[key] then clips[#clips+1]=key end end;sortInventory(clips)
 for _,key in ipairs(clips)do
  local evidence=trace.asset(key)
  emit(f,function()return 'ASSET '..key..' durationMs='..V.data.clips[key].duration..' gameplayQueued='..(evidence.gameplayQueued or 0)..' gameplayStarted='..(evidence.gameplayStarted or 0)..' gameplayFinished='..(evidence.gameplayFinished or 0)..' previewStarted='..(evidence.previewStarted or 0)..'\n' end)
 end
 R.maxPrepareMs=math.max(R.maxPrepareMs or 0,getTimestampMs()-preparationStarted)
 if not writer then f:close()end;return true
end
function R.tick()
 require('CSV/ReportWriter').tick()
 local now=getTimestampMs();if now<R.nextSave then return end;R.nextSave=now+60000
 local observed=false;for _ in pairs(R.observations)do observed=true;break end
 if R.count>0 or observed then R.export(nil,true)end
end
return R
