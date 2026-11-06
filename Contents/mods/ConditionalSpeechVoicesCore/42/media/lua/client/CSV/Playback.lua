local M={}
local Trace=require 'CSV/Trace'
local spatial={self2d=0,worldPositionUpdates=0,movedWhileTalking=0}
M.spatial=spatial
local NeedTiming=require 'CSV/NeedTiming'
function M.install(C,V,speechAvailable,diagnostic)
local function stop(entry)
    if entry.emitter and entry.handle then pcall(entry.emitter.stopSoundLocal,entry.emitter,entry.handle) end
end
function C.cancel(entry,reason,broadcast)
    Trace.step(entry.trace,'ended',reason,{started=entry.started~=nil,elapsed=V.now()-entry.queued})
    entry.finishedReason=reason
    stop(entry)
    for i=#C.active,1,-1 do if C.active[i]==entry then table.remove(C.active,i) end end
    C.lastPlayback={line=entry.line,outcome=reason,elapsed=V.now()-entry.queued,started=entry.started~=nil}
    if entry.packet then require('CSV/ProductionReport').observe('playback_'..(entry.preview and 'preview_' or 'gameplay_')..entry.packet.voice..'_'..entry.line..'_'..reason,{})end
    if broadcast and not entry.preview and not entry.private and entry.player:isLocalPlayer() and isClient() and entry.packet then
        sendClientCommand(entry.player,'CSV','stop',entry.packet)
    end
end
function C.stopPacket(p)
    if type(p)~='table' or not V.finite(p.actor) or not V.finite(p.seq) then return false end
    local key=tostring(p.actor)..':'..tostring(p.seq)
    if C.seenCount>=256 then C.seen={};C.seenCount=0 end
    if not C.seen[key] then C.seenCount=C.seenCount+1 end
    C.seen[key]=V.now()+30000
    for i=#C.active,1,-1 do local e=C.active[i]
        if e.packet and e.packet.actor==p.actor and e.packet.seq==p.seq then C.cancel(e,'remote_stop',false) end
    end
    return true
end
function C.pauseClock()
    local now=V.now()
    local paused=isGamePaused and isGamePaused() or false
    if C.clockWasPaused and C.clockLast then
        local elapsed=math.max(0,now-C.clockLast)
        for _,e in ipairs(C.active)do
            e.deadline=e.deadline+elapsed
            if not e.started then e.queued=e.queued+elapsed end
        end
    end
    C.clockLast=now;C.clockWasPaused=paused
    return paused
end
function C.settingsSnapshot()
    local p=C.preferences()
    local text='own='..C.volumeGain(true)..' other='..C.volumeGain(false)..' frequency='..p.frequency..' whisper='..tostring(p.whisper)..' thoughts='..tostring(p.thoughts)..' profanity='..tostring(p.profanity)..' safe='..tostring(p.safeSpeech)..' lootMode='..p.lootMode..' lootFrequency='..p.lootFrequency..' nearbyVoiceBoost='..C.presenceGain()..' pitchSource=character'..' bobPitchOffsetSemitones=1'
    if knoxwaveGetOption then
        for _,key in ipairs({'echo','echoWet','roomReverb','roomReverbWet'})do
            local ok,value=pcall(knoxwaveGetOption,key)
            text=text..' knoxwave.'..key..'='..(ok and tostring(value) or 'unknown')
        end
    end
    return text
end
function C.observeSettings()
    local text=C.settingsSnapshot()
    if text~=C.lastSettings then
        C.lastSettings=text;C.settingChanges=C.settingChanges or {}
        local entry=tostring(V.now())..' '..text
        C.settingChanges[#C.settingChanges+1]=entry
        if #C.settingChanges>40 then table.remove(C.settingChanges,1)end
        print('[CSV] settings '..entry)
    end
end
function C.sweep()
    if C.pauseClock() then return end
    C.observeSettings()
    local now=V.now()
    for i=#C.active,1,-1 do
        local e=C.active[i]
        local ok,playing=pcall(function()return e.emitter:isPlaying(e.handle) end)
        local pending=false
        if e.emitter.hasSoundsToStart then
            local checked,value=pcall(e.emitter.hasSoundsToStart,e.emitter)
            pending=checked and value==true
        end
        -- isPlaying also includes queued sounds in the game's emitter.
        if not e.started and now-e.queued<5000 and ok and playing and not pending then
            Trace.step(e.trace,'engine_active','engine_observed')
            e.started=now;e.deadline=now+e.duration+300
            print('[CSV] playback observed line='..e.line..' handle='..tostring(e.handle)..' (engine active; not proof of audibility)')
        end
        local reason
        local activityBlock=require('CSV/Activity').block(e.player,e.private,e.preview)
        if activityBlock then reason=activityBlock
        elseif not require('CSV/Profanity').allowed(e.line,C.preferences(),e.packet and e.packet.voice) then reason='profanity_disabled'
        elseif not e.preview and not e.private and e.player.isSneaking and e.player:isSneaking() and not e.allowStealth then
            local concealment=require 'CSV/Concealment'
            local facts=e.ownVoice and require('CSV/State').capture(e.player) or nil
            local permitted=e.engaged and (not facts or concealment.active(facts) or facts.attackGrace==true) or e.exposed and (not facts or concealment.open(facts))
            if not permitted then reason='concealment_interrupt' end
        elseif e.player:isDead() then reason='actor_dead'
        elseif not ok then reason='emitter_check_error'
        elseif not e.started and now-e.queued>=5000 then reason='start_timeout'
        elseif not playing and now-e.queued>=250 then reason=e.started and 'engine_finished' or 'ended_before_start'
        elseif e.started and now>=e.deadline then reason='duration_limit' end
        if reason then
            C.cancel(e,reason,reason=='concealment_interrupt' or reason=='consuming' or reason=='sleeping')
            C.lastPlayback={line=e.line,outcome=reason,elapsed=now-e.queued,started=e.started~=nil}
            print('[CSV] playback ended line='..e.line..' reason='..reason..' elapsedMs='..tostring(now-e.queued))
        else
            local x,y,z=e.player:getX(),e.player:getY(),e.player:getZ()
            if e.originX and not e.movementObserved and (math.abs(x-e.originX)+math.abs(y-e.originY)>.2 or z~=e.originZ) then
                e.movementObserved=true;spatial.movedWhileTalking=spatial.movedWhileTalking+1
            end
            if e.ownVoice then
                e.emitter:set3D(e.handle,false)
            elseif e.emitter.setPos then
                e.emitter:setPos(x,y,z)
                spatial.worldPositionUpdates=spatial.worldPositionUpdates+1
            end
            local gain=C.entryGain(e);e.emitter:setVolume(e.handle,gain)
        end
    end
end
local function localPlayerByID(id)
    for i=0,getNumActivePlayers()-1 do
        local p=getSpecificPlayer(i)
        if p and p:getOnlineID()==id then return p end
    end
end
function C.play(p,actor,localPreview,details)
    details=details or {}
    if not V.config.enabled then return false,'disabled' end
    if not speechAvailable() and not localPreview then return false,'voice_pack_unavailable' end
    if not V.validPacket(p) then return false,'invalid_packet_or_missing_clip' end
    if not require('CSV/Profanity').allowed(p.line,C.preferences(),p.voice) then return false,'profanity_disabled' end
    actor=actor or localPlayerByID(p.actor) or getPlayerByOnlineID(p.actor)
    if not localPreview and require('CSV/NativeVoice').supported(p.voice) and require('CSV/NativeVoice').painActive(actor) then return false,'native_'..p.voice..'_pain' end
    if not actor or actor:isDead() or (V.voice(actor)~=p.voice and not (localPreview==true and actor:isLocalPlayer())) then return false,'actor_or_voice_mismatch' end
    local activityBlock=require('CSV/Activity').block(actor,details.private,localPreview and not details.private)
    if activityBlock then return false,activityBlock end
    local audible=false
    for i=0,getNumActivePlayers()-1 do
        local listener=getSpecificPlayer(i)
        if listener and not listener:isDead() and V.near(listener,actor,p.radius) then audible=true;break end
    end
    if not audible then return false,'out_of_range' end
    local key=tostring(p.actor)..':'..tostring(p.seq)
    local now=V.now()
    if C.seen[key] and C.seen[key]>now then return false,'duplicate' end
    if C.seenCount>=256 then C.seen={};C.seenCount=0 end
    C.seen[key]=now+30000;C.seenCount=C.seenCount+1
    C.sweep()
    local priority=V.packetPriority(p)
    for i=#C.active,1,-1 do local e=C.active[i]
        if e.player==actor then
            if not localPreview and not e.preview and require('CSV/Priority').interrupt(priority,e.priority or 1) then C.cancel(e,'urgent_interrupt',actor:isLocalPlayer())
            else return false,'already_speaking' end
        end
    end
    if #C.active>=V.config.maxConcurrent then return false,'concurrency_limit' end
    local clip=V.clip(p.voice,p.line)
    local emitter=actor:getEmitter()
    if not emitter then return false,'emitter_unavailable' end
    local ownVoice=actor:isLocalPlayer()
    if ownVoice then
        emitter=getSoundManager():getUIEmitter()
        if not emitter then return false,'self_emitter_unavailable' end
    elseif emitter.setPos then
        emitter:setPos(actor:getX(),actor:getY(),actor:getZ())
    end
    -- Local playback only. The server relay owns replication, and original Speech.Say owns AI noise.
    local sound=ownVoice and (clip.sound..'_Self') or clip.sound
    local handle
    if ownVoice then handle=emitter:playSoundImpl(sound,false,nil)
    else handle=emitter:playSoundImpl(sound,nil)end
    if not handle or handle==0 then diagnostic('play-failed',clip.sound); return false,'play_failed' end
    diagnostic('play-started-'..p.voice,sound..' mode='..(ownVoice and 'self-2d' or 'world-3d')..' handle='..tostring(handle))
    local baseVolume=V.deliveryGain(p.voice,p.line) -- Delivery loudness is independent of hearing/relay radius.
    local balance=(clip.gain or 1)*(details.gain or 1)
    local mix={player=actor,packet=p,line=p.line,ownVoice=ownVoice,baseVolume=baseVolume,balance=balance,private=details.private,preview=localPreview==true,contextFacts=details.contextFacts}
    local finalGain,presence,requestedGain=C.entryGain(mix)
    C.lastMix={line=p.line,gain=finalGain,requested=requestedGain,presence=presence,limited=finalGain+0.00001<requestedGain}
    print('[CSV] playback settings sound='..sound..' mode='..(ownVoice and 'self-2d' or 'world-3d')..' pitchInput='..p.pitch..' pitchFactor='..V.pitchMultiplier(p.pitch,p.voice)..' gain='..finalGain..' requestedGain='..requestedGain..' nearbyBoost='..presence)
    if ownVoice then emitter:set3D(handle,false);spatial.self2d=spatial.self2d+1 end
    emitter:setVolume(handle,finalGain)
    if V.config.followPitch and emitter.setPitch then
        -- Approximation, not the game's FMOD curve: +/-100 maps to +/-2 semitones.
        emitter:setPitch(handle,V.pitchMultiplier(p.pitch,p.voice))
    end
    if ownVoice then emitter:tick()end
    Trace.step(details.trace,'queued','engine_handle',{line=p.line,voice=p.voice,handle=handle,private=details.private==true,preview=localPreview==true and not details.private,gain=finalGain,requestedGain=requestedGain,peakLimited=finalGain+0.00001<requestedGain})
    C.active[#C.active+1]={originX=actor:getX(),originY=actor:getY(),originZ=actor:getZ(),trace=details.trace,player=actor,emitter=emitter,handle=handle,baseVolume=baseVolume,balance=balance,contextFacts=details.contextFacts,ownVoice=ownVoice,line=p.line,priority=priority,preview=localPreview==true and not details.private,private=details.private,allowStealth=p.allowStealth==true and V.allowStealth(p.line),exposed=p.exposed==true and p.radius<=require('CSV/Hearing').quietRadius,engaged=p.engaged==true and p.radius<=12,packet=p,queued=now,duration=clip.duration/(V.config.followPitch and V.pitchMultiplier(p.pitch,p.voice) or 1),deadline=now+clip.duration/(V.config.followPitch and V.pitchMultiplier(p.pitch,p.voice) or 1)+300}
    return true,'played',{line=p.line,delivery=V.delivery(p.voice,p.line),gain=finalGain,pitch=p.pitch}
end
function C.emit(player,ctx,volume)
    if not V.finite(volume) or volume<=0 then return end
    C.sequence=C.sequence+1
    if C.sequence>=2147483647 then C.sequence=1 end
    local p={version=1,pack=V.bank(ctx.voice).id,packRevision=V.bank(ctx.voice).revision,actor=math.max(0,player:getOnlineID()),seq=C.sequence,line=ctx.line.id,
        voice=ctx.voice,pitch=V.pitch(player),radius=math.min(V.config.maxDistance,volume),priority=ctx.policy.priority,allowStealth=ctx.policy.allowStealth,exposed=ctx.policy.exposed,engaged=ctx.policy.engaged}
    Trace.step(ctx.trace,'play_requested','spoken',{line=p.line,radius=p.radius,noiseRadius=ctx.policy.noiseRadius})
    local played,reason,info=C.play(p,player,false,{trace=ctx.trace})
    if not played then Trace.step(ctx.trace,'blocked',reason or 'rejected')end
    ctx.outcome=played and 'played' or (reason or 'rejected')
    ctx.info=info or {line=p.line,delivery=V.delivery(p.voice,p.line),pitch=p.pitch}
    ctx.info.upstreamVolume=ctx.upstreamVolume;ctx.info.sourceVolume=volume;ctx.info.volumeBlock=ctx.volumeBlock;ctx.info.intensity=ctx.intensity
    if played and (ctx.group=='Panic' or ctx.group=='PanicCallback' or ctx.group=='Threat') then
        C.lastThreat[player]=V.now();C.lastThreatPhase[player]=(ctx.facts.panic or 0)>=3 and 'high' or ((ctx.facts.panic or 0)>0 and 'tense' or 'calm')
    end
    if played and ctx.policy.engaged then C.lastEngagement[player]=V.now()end
    if played then
        require('CSV/Encounter').record(player,ctx.group,ctx.facts)
        C.remember(player,ctx.line.id,ctx.line)
        NeedTiming.mark(player,ctx.group,ctx.intensity,V.now())
        if (ctx.policy.priority or 1)==1 then
            if require('CSV/LootRules').groups[ctx.group] or ctx.group=='FoundLoot' then C.lastLoot[player]=V.now() else C.lastOrdinary[player]=V.now() end
        end
        if isClient() then sendClientCommand(player,'CSV','speak',p) end
    end
    return played
end
end
return M
