local Adapter={}
function Adapter.install(C,V,env)
 local Speech=require 'ConditionalSpeech_Core'
 local State=require 'CSV/State'
 local phraseSets=require 'ConditionalSpeech_PhraseSet'
 local NeedTiming=require 'CSV/NeedTiming'
 local Evidence=require 'CSV/ThreatEvidence'
 local Trace=require 'CSV/Trace'
 local Channel=require 'CSV/Channel'
 local Debug=C.debug
 local speechAvailable,diagnostic,playerInfo,extraGroups=env.speechAvailable,env.diagnostic,env.playerInfo,env.extraGroups
 return require('CSV/Connections').install('conditional-speech',function(transaction)
  assert(type(Speech.generateSpeechFrom)=='function' and type(Speech.ProcessSpeech)=='function' and type(Speech.Say)=='function','Conditional Speech interface unavailable')
local generate,process,say=Speech.generateSpeechFrom,Speech.ProcessSpeech,Speech.Say
local function owns(player)
 return V.config.enabled and speechAvailable() and player and player.isLocalPlayer and player:isLocalPlayer()
  and not player:isDead() and V.voice(player)~=nil
end
local function generateSpeechFrom(player,group,intensity,maximum,...)
    local manager=require('CSV/SpeechManager')
    if manager.enabled and not manager.dispatching and owns(player) then return manager.submit(generateSpeechFrom,player,group,intensity,maximum,{n=select('#',...),...})end
    local trace=Trace.request(player,group)
    if owns(player) and require('CSV/Activity').read(player)=='sleeping' then Trace.step(trace,'blocked','sleeping');C.lastAttempt[player]={group=group,outcome='sleeping',trace=trace};return end
    if not V.config.enabled or not speechAvailable() or not player or not player:isLocalPlayer() or player:isDead() then
        Trace.step(trace,'bypassed','addon_inactive_or_actor_ineligible')
        return generate(player,group,intensity,maximum,...)
    end
    if group=='Kill' and C.killObserverReady and V.extended(V.voice(player)) then Trace.step(trace,'delegated','attributed_kill_observer');return end -- Replaced by attributed, deferred Psychology events.
    diagnostic('player',playerInfo(player))
    local voice=V.voice(player)
    local sourceGroup=({AmmoCount='LowAmmo',ChamberEmpty='OutOfAmmo',Threat='Panic',AcutePain='Pain',ReliefThreat='Panic',ReliefBleeding='Bleeding',ReliefThirst='Thirst',ReliefEndurance='Endurance'})[group]
    if require('CSV/LootRules').groups[group] then sourceGroup='FoundLoot' end
    if group=='Startle' then sourceGroup='Panic' end
    sourceGroup=sourceGroup or require('CSV/OutcomeRules').groups[group]
    if group=='Psychology' then local e=require('CSV/Psychology').context[player];sourceGroup=e and (e.kind=='zombieKill' or e.kind=='humanKill') and 'Kill' or 'Panic' end
    local recoveryRule=require('CSV/RecoveryRules')[group];if recoveryRule then sourceGroup=recoveryRule.source end
    if not Speech.enabledPhraseSet(sourceGroup or group) then Trace.step(trace,'blocked','group_disabled');Debug.record('gameplay',group,'group_disabled',{voice=voice,intensity=intensity});return end
    if group=='FoundLoot' and not require('CSV/LootRules').allowed(group,C.preferences()) then Trace.step(trace,'blocked','loot_option_disabled');Debug.record('gameplay',group,'loot_option_disabled',{voice=voice});return end
    local facts=State.capture(player)
    if group=='AcutePain' then facts.injuryEvent=require('CSV/Injury').context[player] end
    Trace.evidence(trace,facts)
    local line,policy=C.plan(player,voice,group,intensity,maximum,facts,C.preferences())
    if require('CSV/Encounter').blocked(player,group,facts) then policy={mode='silent',reason='encounter_already_reacted'}end
    Trace.step(trace,'selected',policy.reason,{line=line and line.id or '-',voice=voice or '-',mode=policy.mode,delivery=line and voice and V.delivery(voice,line.id) or '-',meaning=line and line.group or group})
    if not voice then Trace.step(trace,'blocked','unsupported_voice');Debug.record('gameplay',group,'unsupported_voice');return generate(player,group,intensity,maximum,...) end
    local missingFile=line and not V.clip(voice,line.id)
    if missingFile then line=nil end
    local previous=C.contexts[player]
    local attempt={trace=trace,voice=voice,line=line,group=group,outcome=missingFile and 'missing_audio_file' or (line and 'upstream_skipped' or 'no_eligible_recording'),volumeBlock=select(1,...)==true,intensity=intensity}
    attempt.facts=facts;attempt.policy=policy
    if policy.reason=='encounter_already_reacted' then
        Trace.step(trace,'blocked','encounter_already_reacted')
        attempt.outcome='policy_encounter_already_reacted';C.lastAttempt[player]=attempt
        Debug.record('gameplay',group,attempt.outcome,{voice=voice,line=line and line.id,policy=policy.reason,facts=facts})
        return
    end
    local sourceLast=player:getModData().cs_lastspoke
    local sourceGap=SandboxVars.ConditionalSpeech.SpeechCooldown or 1
    if line and sourceLast and (sourceLast[1]+sourceGap>getTimestamp() or (sourceLast[2]==group and sourceLast[1]+sourceGap*3>getTimestamp())) then attempt.outcome='upstream_cooldown' end
    C.contexts[player]=attempt
    local originalPhrases=phraseSets.Phrases[group]
    local supplied=line and extraGroups[group] and (not originalPhrases or #originalPhrases==0)
    if supplied then
        local own={}
        for _,entry in ipairs(V.data.groups[group] or {line}) do own[#own+1]=entry.text end
        phraseSets.Phrases[group]=own
    end
    local oldCooldown
    local ownedEvent=policy.mode=='spoken' and (group=='AcutePain' and facts.acute==true or group=='Startle' and facts.nativeAlert or recoveryRule~=nil or group=='Psychology' and facts.psychology and facts.psychology.verified==true or facts.outcome and require('CSV/OutcomeRules').groups[group]~=nil)
    if ownedEvent then oldCooldown=player:getModData().cs_lastspoke;player:getModData().cs_lastspoke={0,''}end
    local encounter=require('CSV/Encounter')
    local escalation=encounter.reaction(group,facts) and encounter.escalation(encounter.players[player],facts)
    if escalation then Trace.step(trace,'encounter',escalation)end
    if not ownedEvent and (policy.engaged or policy.mode=='spoken' and escalation) and not encounter.blocked(player,group,facts) then oldCooldown=player:getModData().cs_lastspoke;player:getModData().cs_lastspoke={0,''}end
    if not oldCooldown and (attempt.policy.priority or 1)>=3 then
        for _,active in ipairs(C.active)do
            if active.player==player and not active.preview and (active.priority or 1)<attempt.policy.priority then
                oldCooldown=player:getModData().cs_lastspoke;player:getModData().cs_lastspoke={0,''};break
            end
        end
    end
    local result={pcall(generate,player,group,intensity,maximum,...)}
    if oldCooldown and (ownedEvent or attempt.outcome~='played') then player:getModData().cs_lastspoke=oldCooldown end
    if attempt.playbackFailed then player:getModData().cs_lastspoke=sourceLast end
    local entry=attempt.playbackEntry
    if entry and not entry.started then
        local assigned=player:getModData().cs_lastspoke
        entry.onFailed=function() if player:getModData().cs_lastspoke==assigned then player:getModData().cs_lastspoke=sourceLast end end
    end
    if supplied then phraseSets.Phrases[group]=originalPhrases end
    C.contexts[player]=previous
    attempt.info=attempt.info or {line=line and line.id or '-'}
    attempt.info.voice=voice;attempt.info.intensity=intensity;attempt.info.facts=facts;attempt.info.remainingMs=attempt.remainingMs;attempt.info.text=line and line.text;attempt.info.threatKind=Evidence.kind(facts);attempt.info.upstreamVolume=attempt.upstreamVolume;attempt.info.policy=attempt.policy.reason;attempt.info.panic=facts.panic;attempt.info.near=facts.near;attempt.info.sneaking=facts.sneaking;attempt.info.targeted=facts.targeted;attempt.info.approaching=facts.approaching;attempt.info.blockedNear=facts.blockedNear;attempt.info.directAttack=facts.directAttack;attempt.info.activePursuit=facts.activePursuit;attempt.info.noiseRadius=attempt.outcome=='played' and policy.noiseRadius or 0;attempt.info.hearingRiskRadius=facts.hearingRiskRadius;attempt.info.whisperRisk=facts.whisperRisk;attempt.info.exposed=require('CSV/Concealment').open(facts);attempt.info.concealmentRisk=facts.concealmentRisk
    C.lastAttempt[player]=attempt
    Trace.step(trace,result[1] and 'request_result' or 'error',result[1] and attempt.outcome or 'upstream_error',{line=line and line.id or '-',policy=attempt.policy.reason,volumeBlock=attempt.volumeBlock,upstreamVolume=attempt.upstreamVolume,remainingMs=attempt.remainingMs})
    if result[1] and attempt.outcome~='played' and attempt.outcome~='local_thought' then Trace.step(trace,'blocked',attempt.outcome)end
    Debug.record('gameplay',group,result[1] and attempt.outcome or 'upstream_error',attempt.info or {line=line and line.id or '-'})
    if not result[1] then error(result[2]) end
    return unpack(result,2)
end
local function ProcessSpeech(player,dialogue,group,...)
    if not owns(player) then return process(player,dialogue,group,...) end
    if not C.contexts[player] and group==nil and require('CSV/Upstream').countSpeech(player,dialogue) then return nil,nil end
    local text,volume=process(player,dialogue,group,...)
    local ctx=C.contexts[player]
    if ctx then ctx.upstreamVolume=volume;Trace.step(ctx.trace,'upstream_processed','source_result',{volume=volume,volumeBlock=ctx.volumeBlock,textReturned=type(text)=='string'})end
    if ctx and not ctx.line then
        if type(text)=='string' and ctx.policy.mode=='silent' then
            ctx.outcome='policy_'..ctx.policy.reason
            return text:sub(1,1)=='(' and text or ('('..text..')'),0
        end
        return text,volume
    end
    if ctx and type(text)=='string' then
        local decision=ctx.policy
        local remaining=NeedTiming.remaining(player,group,ctx.intensity,C.preferences().frequency,V.now())
        ctx.remainingMs=remaining
        if decision.mode~='silent' and (decision.priority or 1)==1 then
            local intervals={[0]=60000,[1]=30000,[2]=10000};local gap=group:match('^Relief') and 10000 or (intervals[C.preferences().frequency] or 30000)
            local last=C.lastOrdinary[player];local reason='ordinary_cooldown'
            if require('CSV/LootRules').groups[group] or group=='FoundLoot' then local _,gaps=require('CSV/LootRules').settings(C.preferences());gap=gaps.between;last=C.lastLoot[player];reason='loot_cooldown' end
            if last and V.now()-last<gap then decision={mode='silent',reason=reason};ctx.policy=decision end
        end
        if decision.mode~='silent' and remaining>0 then decision={mode='silent',reason='need_cooldown'};ctx.policy=decision end
        local channel=Channel.resolve(decision,require('CSV/Activity').read(player),C.preferences())
        ctx.channel=channel
        Trace.step(ctx.trace,'channel_decision',channel.reason,{allowed=channel.allowed,channel=channel.channel})
        if channel.channel=='private' or channel.channel=='none' then
            ctx.outcome=channel.allowed and 'private_only' or ('policy_'..channel.reason)
            return '('..ctx.line.text..')',0
        end
        if decision.mode=='silent' then
            Trace.step(ctx.trace,'blocked',decision.reason,{remainingMs=remaining})
            ctx.outcome='policy_'..decision.reason
            ctx.info={line=ctx.line.id,sourceVolume=0,volumeBlock=ctx.volumeBlock,intensity=ctx.intensity}
            return '('..ctx.line.text..')',0
        elseif decision.mode=='spoken' then
            volume=decision.radius;text=ctx.line.text
        end
    end
    if ctx and type(text)=='string' and V.finite(volume) and volume>0
        and not text:match('^[%(%*%[]') then
        ctx.ready=true
        return ctx.line.text,volume
    end
    if ctx then
        local reason
        if text==nil then reason='upstream_no_result'
        elseif ctx.volumeBlock then reason='upstream_volume_block'
        elseif not V.finite(volume) or volume<=0 then reason='upstream_zero_volume'
        else reason='addon_text_marker' end
        ctx.outcome=reason
        ctx.info={line=ctx.line.id,sourceVolume=volume,volumeBlock=ctx.volumeBlock,intensity=ctx.intensity}
        diagnostic(reason..'-'..tostring(group),'volume='..tostring(volume)..' blocked='..tostring(ctx.volumeBlock))
    end
    return text,volume
end
local function Say(player,text,volume)
    if not owns(player) then return say(player,text,volume) end
    local activity=require('CSV/Activity').read(player)
    if activity=='sleeping' then return end
    if activity=='consuming' then volume=0 end
    local ctx=C.contexts[player]
    local channel=ctx and Channel.resolve(ctx.policy,activity,C.preferences(),volume)
    if ctx and ctx.ready and text==ctx.line.text and channel.channel=='public' then
        ctx.ready=false
        local ok,played=pcall(C.emit,player,ctx,volume)
        ctx.playbackFailed=not ok or not played
        if not ok then ctx.outcome='emit_error';C.errors=C.errors+1;diagnostic('emit-error',played) end
        return say(player,ok and played and text or ('('..text..')'),ok and played and (ctx.policy.noiseRadius or volume) or 0)
    end
    local result=say(player,text,volume)
    if ctx and ctx.line and channel.allowed and channel.channel=='private' and not require('CSV/LootRules').groups[ctx.group] and ctx.group~='FoundLoot' and (not C.lastOrdinary[player] or V.now()-C.lastOrdinary[player]>=(({[0]=60000,[1]=30000,[2]=10000})[C.preferences().frequency] or 30000)) then
        C.sequence=C.sequence+1
        local p={version=1,pack=V.bank(ctx.voice).id,packRevision=V.bank(ctx.voice).revision,actor=math.max(0,player:getOnlineID()),seq=C.sequence,line=ctx.line.id,voice=ctx.voice,pitch=V.pitch(player),radius=15}
        local ok,played,reason=pcall(C.play,p,player,true,{private=true,gain=.35,trace=ctx.trace})
        Trace.step(ctx.trace,'private_thought',ok and (played and 'queued' or reason) or 'play_error')
        if ok and played then require('CSV/Encounter').record(player,ctx.group,ctx.facts);C.remember(player,ctx.line.id,ctx.line);ctx.outcome='local_thought';C.lastOrdinary[player]=V.now();NeedTiming.mark(player,ctx.group,ctx.intensity,V.now()) end
    end
    return result
end
transaction:replace(Speech,'generateSpeechFrom',generateSpeechFrom)
transaction:replace(Speech,'ProcessSpeech',ProcessSpeech)
transaction:replace(Speech,'Say',Say)
 end)
end
return Adapter
