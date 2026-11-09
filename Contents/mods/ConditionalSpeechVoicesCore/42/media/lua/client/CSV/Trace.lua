local function emit(f,fn)if type(f)=='table' and f.defer then f:defer(fn)else f:write(fn())end end
-- Local diagnostic history. Never replicate IDs or retain world objects in records.
local T={records={},assets={},assetCount=0,assetLimit=4096,droppedAssets=0,sequence=0,evicted=0,context=setmetatable({},{__mode='k'}),limit=256}
local keys={'health','injuryEvent','nativeAlert','encounterThreat','humanThreat','fire','acute','exposureChecked','attackGrace','near','visible','panic','sneaking','targeted','attacking','directAttack','activePursuit','recentThreat','whisperRisk','hunger','thirst','bleeding','endurance','pain','unhappy'}
local known={};for _,key in ipairs(keys)do known[key]=true end
for _,rule in pairs(require('CSV/RecoveryRules'))do if not known[rule.field] then keys[#keys+1]=rule.field;known[rule.field]=true end end
local function now()return getTimestampMs()end
local function clean(value)return tostring(value):gsub('[\r\n\t]',' '):sub(1,240)end
local function snapshot(facts)
 local target={}
 for _,key in ipairs(keys)do
  local value=facts and facts[key]
  if type(value)=='string' or type(value)=='number' or type(value)=='boolean' then target[key]=value end
 end
 for _,field in ipairs({'psychology','outcome','loot'})do
  local value=facts and facts[field]
  if type(value)=='table' then for _,key in ipairs({'kind','verified','experience','group','type','item','nativeSound','event','role','targets','attacks','nativeContact','dead','nativeCause'})do
   local v=value[key];if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then target[field..'_'..key]=v end
  end end
 end
 return target
end
function T.supports(group)
 return type(group)=='string' and #group>0 and #group<=80
end
local function assetEvidence(record,stage,reason,info)
 if stage=='queued' and info and type(info.voice)=='string' and type(info.line)=='string' then
  record.clipKey=info.voice..'_'..info.line
 end
 if not record.clipKey then return end
 local row=T.assets[record.clipKey]
 if not row then
  if T.assetCount>=T.assetLimit then T.droppedAssets=T.droppedAssets+1;return end
  row={};T.assets[record.clipKey]=row;T.assetCount=T.assetCount+1
 end
 local suffix=stage=='queued' and 'Queued' or stage=='engine_active' and 'Started' or stage=='ended' and reason=='engine_finished' and 'Finished' or nil
 if not suffix then return end
 record.assetStages=record.assetStages or {}
 local key=(record.kind=='preview' and 'preview' or 'gameplay')..suffix
 if not record.assetStages[key] then row[key]=(row[key] or 0)+1;record.assetStages[key]=true end
end
function T.step(record,stage,reason,info)
 if not record then return end
 if stage=='engine_active' then record.engineStarted=true end
 assetEvidence(record,stage,reason,info)
 local last=record.steps[#record.steps]
 if last and last.stage==stage and last.reason==reason then last.repeats=last.repeats+1;last.last=now();return end
 local step={at=now(),last=now(),stage=stage,reason=reason or '-',repeats=1,info={}}
 for key,value in pairs(info or {})do
  if type(value)=='string' or type(value)=='number' or type(value)=='boolean' then step.info[key]=clean(value)end
 end
 if #record.steps>=32 then table.remove(record.steps,2);record.droppedSteps=(record.droppedSteps or 0)+1 end
 record.steps[#record.steps+1]=step;record.status=stage;record.reason=reason
end
function T.begin(player,group,source,facts,kind)
 if not T.supports(group) and kind~='preview' then return nil end
 T.sequence=T.sequence+1
 local record={id=T.sequence,at=now(),group=group,source=source,kind=kind or 'gameplay',steps={},facts=snapshot(facts),latestFacts={},hasOrigin=facts~=nil}
 if player and player.getOnlineID then local ok,id=pcall(player.getOnlineID,player);if ok then record.actor=id end end
 if #T.records>=T.limit then table.remove(T.records,1);T.evicted=T.evicted+1 end
 T.records[#T.records+1]=record;T.step(record,source=='conditional_speech_request' and 'request_received' or 'observed',source)
 return record
end
function T.evidence(record,facts)
 if not record then return end
 if record.hasOrigin then record.latestFacts=snapshot(facts) else record.facts=snapshot(facts) end
 record.hasOrigin=true
end
function T.request(player,group)
 if not player or not player.isLocalPlayer or not player:isLocalPlayer() then return nil end
 local record=T.context[player] or T.begin(player,group,'conditional_speech_request')
 T.step(record,'requested',group)
 return record
end
function T.call(record,player,fn,...)
 local previous=T.context[player];T.context[player]=record
 local result={pcall(fn,...)};T.context[player]=previous
 if not result[1] then T.step(record,'error','request_error',{error=result[2]});error(result[2])end
 return unpack(result,2)
end
function T.block(state,player,group,source,reason,facts)
 local record=state.traceBlock
 if not record or record.reason~=reason or record.group~=group or now()-record.at>30000 then
  record=T.begin(player,group,source,facts);state.traceBlock=record
 else T.evidence(record,facts) end
 T.step(record,'blocked',reason)
 return record
end
local function fields(values)
 local names={};for key in pairs(values)do names[#names+1]=key end;require('CSV/Sort').sort(names)
 local out={};for _,key in ipairs(names)do out[#out+1]=key..'='..clean(values[key])end;return table.concat(out,' ')
end
function T.asset(key)return T.assets[key] or {}end
function T.export(f)
 emit(f,function()return 'TRACE_ASSETS tracked='..T.assetCount..' limit='..T.assetLimit..' dropped='..T.droppedAssets..'\n' end)
 emit(f,function()return 'EVENT_TRACE retained='..#T.records..' evicted='..T.evicted..' limit='..T.limit..'\n' end)
 emit(f,function()return 'TRACE_SCOPE all local speech requests; source observations only when attached. A request is not proof of a native event. Asset coverage excludes remote playback.\n' end)
 emit(f,function()return 'queued means accepted; engine_active is not proof of audibility. blocked can precede a retry or private thought. Preview is separate.\n' end)
 for _,r in ipairs(T.records)do
  emit(f,function()return 'TRACE id='..r.id..' kind='..r.kind..' group='..r.group..' source='..r.source..' actor='..tostring(r.actor)..' at='..r.at..' droppedSteps='..(r.droppedSteps or 0)..' '..fields(r.facts)..'\n' end)
  local hasLatest=false;for _ in pairs(r.latestFacts)do hasLatest=true;break end
  if hasLatest then emit(f,function()return 'TRACE_LATEST id='..r.id..' '..fields(r.latestFacts)..'\n' end)end
  for _,s in ipairs(r.steps)do emit(f,function()return 'TRACE_STEP id='..r.id..' dt='..(s.at-r.at)..' stage='..s.stage..' reason='..clean(s.reason)..' repeats='..s.repeats..' last='..s.last..' '..fields(s.info)..'\n' end)end
 end
end
return T
