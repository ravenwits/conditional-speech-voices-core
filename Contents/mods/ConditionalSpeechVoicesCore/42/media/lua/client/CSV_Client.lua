local V=require 'CSV/Core'
local Speech=require 'ConditionalSpeech_Core'
local State=require 'CSV/State'
local Extras=require 'CSV/Extras'
local extraGroups={AmmoCount=true,ChamberEmpty=true,Threat=true,AcutePain=true,ReliefThreat=true,ReliefBleeding=true,ReliefEndurance=true,ReliefThirst=true,NoxiousSmell=true,Uncomfortable=true,CantSprint=true,Angry=true}
for group in pairs(require('CSV/RecoveryRules'))do extraGroups[group]=true end
for group in pairs(require('CSV/LootRules').groups)do extraGroups[group]=true end
for group in pairs(require('CSV/OutcomeRules').groups)do extraGroups[group]=true end
for group in pairs(require('CSV/ReloadRules').groups)do extraGroups[group]=true end
extraGroups.Psychology=true;extraGroups.Startle=true
if Speech._csvInstalled then return end
local C={active={},seen={},seenCount=0,sequence=0,contexts=setmetatable({},{__mode='k'}),errors=0}
C.gameReady=false
C.lastOrdinary=setmetatable({},{__mode='k'})
C.lastLoot=setmetatable({},{__mode='k'})
C.lastAttempt=setmetatable({},{__mode='k'})
V.client=C
local Debug=require 'CSV/Debug'
C.debug=Debug
-- Bounded diagnostics for the first in-game checks. No player names or dialogue logged.
local logged={}
local function diagnostic(key,message)
    if logged[key] then return end
    logged[key]=true
    print('[CSV] '..key..' '..tostring(message or ''))
end
diagnostic('loaded','speech core v'..V.version)
local function playerInfo(player)
    local d=player and player:getDescriptor()
    return 'language='..tostring(Translator.getLanguage():name())..' prefix='..tostring(d and d:getVoicePrefix())..' type='..tostring(d and d:getVoiceType())..' mapped='..tostring(V.voice(player))
end
require('CSV/Selection').install(C,V)
require('CSV/Settings').install(C,V)
local function speechAvailable() return require('CSV/Core').languageSupported() end
require('CSV/Playback').install(C,V,speechAvailable,diagnostic)
local installed,installError=require('CSV/SpeechAdapter').install(C,V,{speechAvailable=speechAvailable,diagnostic=diagnostic,playerInfo=playerInfo,extraGroups=extraGroups})
if not installed then print('[CSV] speech adapter unavailable: '..tostring(installError));return end
Speech._csvInstalled=true
local function onServer(module,command,p)
    if module=='CSV' and command=='stop' then C.stopPacket(p);return end
    if module=='CSV' and command=='play' then
        local ok,result,info,details=pcall(C.play,p)
        Debug.record('remote',nil,ok and (result and 'played' or (info or 'rejected')) or 'play_error',details or {line=p and p.line})
        local err=result
        if not ok then C.errors=C.errors+1;diagnostic('relay-error',err) end
    end
end
local function onTick()
    require('CSV/NativeVolume').update()
    if not Events.OnTickEvenPaused then require('CSV/ReportWriter').tick()end
    if V.config.enabled and speechAvailable() then
        require('CSV/Observers').tick()
    end
    if #C.active==0 then return end
    local now=V.now()
    if now<(C.nextSweep or 0) then return end
    C.nextSweep=now+100
    local ok,err=pcall(C.sweep)
    if not ok then C.errors=C.errors+1;diagnostic('playback-monitor-error',err) end
end
local lastPreview={}
function C.previewCandidates(voice)
    local ids={}
    if V.bank(voice).needTiers==1 then
        for _,pool in pairs(require('CSV/NeedTiers').slots)do
            for _,id in ipairs(pool)do if V.clip(voice,id) then ids[#ids+1]=id end end
        end
    end
    for _,group in pairs(V.data.groups) do
        for _,line in ipairs(group) do
            if V.clip(voice,line.id) then ids[#ids+1]=line.id end
        end
    end
    for _,line in ipairs(V.data.contextLines or {})do if V.clip(voice,line.id) then ids[#ids+1]=line.id end end
    if Extras.approved and V.extended(voice) then for _,line in pairs(Extras.catalog)do if V.clip(voice,line.id) then ids[#ids+1]=line.id end end end
    if V.extended(voice) and require('CSV/Whispers').approved then for _,line in pairs(require('CSV/Whispers').catalog)do if V.clip(voice,line.id) then ids[#ids+1]=line.id end end end
    if V.extended(voice) and require('CSV/Expressions').approved then for _,entry in pairs(require('CSV/Expressions').catalog)do if V.clip(voice,entry.id) then ids[#ids+1]=entry.id end end end
    local unique,seen={},{};for _,id in ipairs(ids)do if not seen[id]then unique[#unique+1]=id;seen[id]=true end end
    require('CSV/Sort').sort(unique)
    return unique
end
local function randomPreview(voice)
    local ids=C.previewCandidates(voice)
    if #ids>1 then
        for i=#ids,1,-1 do if ids[i]==lastPreview[voice] then table.remove(ids,i) end end
    end
    if #ids==0 then return nil end
    return ids[ZombRand(#ids)+1]
end
-- Contextual listening shares selection/delivery rules, without gameplay side effects.
function C.contextPreview(player,voice,group,level,facts)
    facts=facts or State.capture(player)
    local trace=require 'CSV/Trace'
    local record=trace.begin(player,group,'context_preview',facts,'preview')
    local line,decision=C.plan(player,voice,group,level or 1,4,facts,C.preferences())
    trace.step(record,'selected',decision.reason,{line=line and line.id or '-',mode=decision.mode})
    if not line or not V.clip(voice,line.id) then local reason=decision.reason=='unmanaged_group' and 'event_evidence_required' or 'no_matching_recording';trace.step(record,'blocked',reason);C.lastPreviewReason=reason;return false,C.lastPreviewReason end
    if decision.mode~='spoken' then trace.step(record,'blocked',decision.reason);C.lastPreviewReason=decision.reason;return false,decision.reason,line end
    local ok,reason=C.preview(player,line.id,voice,decision.radius,nil,{contextFacts=facts,trace=record})
    return ok,reason,line
end
-- Local listening preview: no server message, subtitle, cooldown or zombie noise.
function C.preview(player,lineID,selectedVoice,previewRadius,previewPitch,details)
    local function rejected(reason)
        Debug.record('preview',nil,reason,{line=lineID})
        C.lastPreviewReason=reason
        print('[CSV] preview rejected reason='..reason)
        return false,reason
    end
    print('[CSV] preview requested line='..tostring(lineID or 'random')..' voice='..tostring(selectedVoice or 'character'))
    if not player or not player:isLocalPlayer() or player:isDead() then return rejected('invalid_local_player') end
    local voice=selectedVoice or V.voice(player)
    if not V.pack.voiceBanks[voice] then return rejected('unsupported_voice') end
    lineID=lineID or randomPreview(voice)
    if not lineID then return rejected('no_recorded_clip') end
    C.sequence=C.sequence+1
    if C.sequence>=2147483647 then C.sequence=1 end
    local packet={version=1,pack=V.bank(voice).id,packRevision=V.bank(voice).revision,actor=math.max(0,player:getOnlineID()),seq=C.sequence,
        line=lineID,voice=voice,pitch=previewPitch or V.pitch(player),radius=previewRadius or 15}
    local trace=require 'CSV/Trace'
    details=details or {};details.trace=details.trace or trace.begin(player,lineID,'local_preview',details.contextFacts,'preview')
    trace.step(details.trace,'play_requested','preview',{line=lineID,voice=voice})
    local ok,result,reason,info=pcall(C.play,packet,player,true,details)
    if not ok or not result then trace.step(details.trace,'blocked',ok and (reason or 'rejected') or 'play_error')end
    Debug.record('preview',nil,ok and (result and 'played' or (reason or 'rejected')) or 'play_error',info or {line=lineID,delivery=V.delivery(voice,lineID),pitch=packet.pitch})
    C.lastPreviewReason=ok and (result and 'queued' or (reason or 'rejected')) or ('play_error: '..tostring(result))
    if ok and result then lastPreview[voice]=lineID end
    print('[CSV] preview voice='..voice..' line='..packet.line..' delivery='..V.delivery(voice,lineID)..' volume='..tostring(C.volumeGain(true))..' result='..tostring(result)..' reason='..C.lastPreviewReason)
    if not ok then C.errors=C.errors+1 end
    return ok and result or false,C.lastPreviewReason
end
local function onContextMenu(playerIndex,context,worldobjects,test)
    if test or not V.config.enabled or not C.debugEnabled() then return end
    local player=getSpecificPlayer(playerIndex)
    if not player or not player:isLocalPlayer() or player:isDead() then return end
    local voice=V.voice(player)
    local submenu=require('CSV/DebugMenu').speech(context)
    submenu:addOption(getText('UI_CSV_SaveReport'),nil,Debug.export)
    require('CSV/DebugMenu').health(submenu,player)
    if not voice or not V.pack.voiceBanks[voice] then return end
    submenu:addOption(getText('UI_CSV_Scenarios'),player,function(p)require('CSV/Scenarios').open(p)end)
    submenu:addOption(getText('UI_CSV_Pitch'),player,function(p)require('CSV/Pitch').open(p)end)
    submenu:addOption(getText('UI_CSV_Audition'),player,function(p)require('CSV/Audition').open(p)end)
    local statsOption=submenu:addOption(getText('UI_CSV_Statistics'),nil,nil)
    local statsMenu=ISContextMenu:getNew(submenu);submenu:addSubMenu(statsOption,statsMenu)
    local function row(text)
        local item=statsMenu:addOption(text,nil,nil);item.notAvailable=true
    end
    row(getText('UI_CSV_Session')..': '..Debug.total..' / '..Debug.previews)
    if C.lastPlayback then row(getText('UI_CSV_Playback')..': '..C.lastPlayback.line..' / '..require('CSV/DebugUI').playback(C.lastPlayback)) end
    for i,g in ipairs(Debug.top())do
        if i>8 then break end
        local item=statsMenu:addOption(g.name..': '..g.attempts..' / '..g.played,nil,nil)
        item.notAvailable=true
    end
end
Events.OnFillWorldObjectContextMenu.Add(onContextMenu)
Events.OnServerCommand.Add(onServer)
Events.OnTick.Add(onTick)
if Events.OnTickEvenPaused then Events.OnTickEvenPaused.Add(function()
    require('CSV/ReportWriter').tick()
    local ok,err=pcall(function()C.pauseClock();C.observeSettings()end)
    if not ok then C.errors=C.errors+1;diagnostic('settings-monitor-error',err)end
end)end
if Events.OnGameStart then Events.OnGameStart.Add(function()C.gameReady=true;require('CSV/Observers').install()end) end
return C




