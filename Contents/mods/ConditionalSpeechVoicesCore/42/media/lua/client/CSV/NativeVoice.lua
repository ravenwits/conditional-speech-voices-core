local N={banks={},errors=0,disabledVoices={}}
local V=require 'CSV/Core'
local function spec(voice)local b=V.pack.extraVoices[voice or 'alp'];return b and b.native end
function N.supported(voice)return voice~=nil and spec(voice)~=nil end
function N.prefix(pitch,voice)
 return assert(V.pack.voices[voice or 'alp'],'Unknown voice').prefix..tostring(math.floor(math.max(-100,math.min(100,pitch or 0))+100.5))
end
-- The engine picks a clip uniformly. Leave some exertions unvoiced while
-- keeping the animation, impact sound, and the native vocal handle intact.
local silentChoices={MeleeAttack=6,MeleeStab=6,MeleeStabOnGround=6,MeleeAttackHeavy=3,
 MeleeShove=6,MeleeStomp=6,Exercise=6,CorpseDragging=6,CorpseHighEffort=3,CorpseLowEffort=6}
function N.ensure(pitch,voice)
 voice=voice or 'alp'
 local data=spec(voice);if not data then return nil end
 pitch=math.floor(math.max(-100,math.min(100,pitch or 0))+.5)
 local prefix=N.prefix(pitch,voice);if N.banks[prefix] then return prefix end
 -- Separate definitions per used pitch. Never mutate shared vanilla clips.
 local events={}
 for _,suffix in ipairs(data.suffixes)do events[#events+1]={suffix=suffix,source=suffix,ids=data.replacements[suffix]}end
 -- These single-take events let the caption and network audio share one choice.
 for _,source in ipairs({'ShoutHey','WhisperHey'})do
  for _,id in ipairs(data.replacements[source])do
   events[#events+1]={suffix='CSV'..id,source=source,ids={id}}
  end
 end
 for _,event in ipairs(events)do
  local suffix=event.suffix
  local original=GameSounds.getSound(V.pack.voices[voice].base..event.source)
  if not original then error('Missing native voice event '..suffix)end
  local name=prefix..suffix
  local body={'sound '..name..' { category = '..original:getCategory()..', is3D = true, loop = false, master = '..original:getMasterName()..','}
  if suffix=='' then
   -- IsoPlayer.updateVocalProperties keeps this parameter-driven event alive.
   -- A finite breath sample here restarts even when the character is resting.
   local clip=original:getRandomClip()
   body[#body+1]='clip { event = '..clip:getEvent()..', distanceMax = '..tostring(clip:getMaxDistance())..', }'
  else
   local ids=event.ids
   if not ids or #ids==0 then error('Missing custom voice replacement '..suffix)end
   for index=1,#ids+(silentChoices[suffix] or 0) do
    local id=ids[1+(index-1)%#ids]
    local source=GameSounds.getSound('CSV_'..voice..'_'..id)
    local clip=source and source:getRandomClip()
    local file=clip and clip:getFile()
    if not file or not file:match('^media/sound/CSV/[%w_]+%.mp3$') then error('Missing custom voice file '..id)end
    body[#body+1]='clip { file = '..file..', volume = '..tostring(index<=#ids and clip:getVolume() or 0)..', pitch = '..tostring(V.pitchMultiplier(pitch,voice))..', distanceMin = '..tostring(clip:getMinDistance())..', distanceMax = '..tostring(clip:getMaxDistance())..', }'
   end
  end
  body[#body+1]='}'
  -- Java objects expose methods to Kahlua, not writable Lua fields.
  -- Let the native sound-script loader create all GameSound/Clip fields.
  local script=GameSoundScript.new()
  script:Load(name,table.concat(body,'\n'))
  GameSounds.OnReloadSound(script)
  if not GameSounds.isKnownSound(name) then error('Custom sound registration failed '..name)end
 end
 N.banks[prefix]=true;return prefix
end
function N.tryEnsure(pitch,voice)
 if N.disabledVoices[voice or 'alp'] then return nil end
 local ok,prefix=pcall(N.ensure,pitch,voice)
 if ok then return prefix end
 N.disabled=true;N.disabledVoices[voice or 'alp']=true;N.errors=N.errors+1;print('[CSV] '..(voice or 'alp')..' native voice setup disabled for this session: '..tostring(prefix))
end
function N.apply(player)
 if not player or not player.getDescriptor then return end
 local d=player:getDescriptor();if not d then return end
 local md=player:getModData()
 local voice=md.csvVoice
 if not voice then for id,v in pairs(V.pack.voices)do if v.prefix and (d:getVoicePrefix() or ''):sub(1,#v.prefix)==v.prefix then voice=id;break end end end
 local selected=voice and spec(voice)~=nil
 if not selected then return end
 local prefix=N.ensure(V.pitch(player),voice);if not prefix then return end
 if d:getVoicePrefix()~=prefix then d:setVoicePrefix(prefix)end
 md.csvVoice=voice
end
function N.safeApply(player)
 local voice=player and V.voice(player)
 if N.disabledVoices[voice or 'alp'] then return end
 local ok,err=pcall(N.apply,player)
 if not ok then N.disabled=true;N.disabledVoices[voice or 'alp']=true;N.errors=N.errors+1;print('[CSV] '..(voice or 'alp')..' native voice setup disabled for this session: '..tostring(err))end
end
function N.painActive(player)
 if not player or not N.supported(V.voice(player)) then return false end
 local e=player:getEmitter();if not e then return false end
 local prefix=player:getDescriptor():getVoicePrefix() or ''
 for _,suffix in ipairs(spec(V.voice(player)).pain)do if e:isPlaying(prefix..suffix) then return true,suffix end end
 return false
end
local activity=setmetatable({},{__mode='k'})
N.activity={}
N.ambient={windows=0,scans=0,activeScans=0}
local lastPain=setmetatable({},{__mode='k'})
function N.update(player)
 N.safeApply(player)
 if N.supported(V.voice(player)) then
  require('CSV/AlpCallout').observe(player)
  local now=V.now();local state=activity[player]
  if not state then state={nextScan=0,seen={}};activity[player]=state end
  if now>=state.nextScan then
   state.nextScan=now+200
   local emitter=player:getEmitter();local prefix=player:getDescriptor():getVoicePrefix()
   if emitter then
    local ambient=emitter:isPlaying(prefix)
    N.ambient.scans=N.ambient.scans+1
    if ambient then N.ambient.activeScans=N.ambient.activeScans+1 end
    if ambient and not state.ambient then N.ambient.windows=N.ambient.windows+1 end
    state.ambient=ambient
    for suffix in pairs(silentChoices)do
    local current=emitter:isPlaying(prefix..suffix)
    if current and not state.seen[suffix] then N.activity[suffix]=(N.activity[suffix] or 0)+1 end
    state.seen[suffix]=current
    end
   end
  end
 end
 local active,suffix=N.painActive(player)
 if suffix and suffix~=lastPain[player] then require('CSV/ProductionReport').observe(V.voice(player)..'_native_active_'..suffix,{})end
 lastPain[player]=suffix
 if not active or not V.client then return end
 local C=V.client
 for i=#C.active,1,-1 do
  local e=C.active[i]
  if e.player==player and not e.preview then C.cancel(e,'native_'..V.voice(player)..'_pain',true)end
 end
end
return N
