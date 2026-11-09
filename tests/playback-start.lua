local b='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=b..'shared/?.lua;'..b..'client/?.lua;'..package.path
local now=10000;getTimestampMs=function()return now end;isClient=function()return false end
local facts={near=1,visible=1,panic=0,recentThreat=true,encounterThreat=true}
local playing,pending=false,false
local emitter={playVocals=function()return 1 end,isPlaying=function()return playing end,hasSoundsToStart=function()return pending end,setVolume=function()end,setPitch=function()end,setPos=function()end,stopSoundLocal=function()end}
local p={isLocalPlayer=function()return true end,isDead=function()return false end,isSneaking=function()return false end,getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end,getOnlineID=function()return 1 end,getEmitter=function()return emitter end}
getNumActivePlayers=function()return 1 end;getSpecificPlayer=function()return p end
local V={config={enabled=true,maxConcurrent=2,maxDistance=25},now=function()return now end,finite=function(x)return type(x)=='number' end,voice=function()return 'test' end,validPacket=function()return true end,near=function()return true end,packetPriority=function()return 2 end,clip=function()return {sound='Test',duration=2000}end,deliveryGain=function()return 1 end,delivery=function()return 'normal' end,pitch=function()return 0 end,pitchMultiplier=function()return 1 end,bank=function()return {id='test',revision='1'}end}
package.loaded['CSV/Core']=V
package.loaded['CSV/Trace']={step=function()end}
package.loaded['CSV/Activity']={block=function()end}
package.loaded['CSV/Profanity']={allowed=function()return true end}
package.loaded['CSV/NativeVoice']={supported=function()return false end,ready=function()return false end,painActive=function()return false end}
package.loaded['CSV/ProductionReport']={observe=function()end}
package.loaded['CSV/LootRules']={groups={}}
package.loaded['CSV/VehicleCombatRules']={groups={}}
package.loaded['CSV/Concealment']={active=function(s)return (s.directAttack or 0)>0 end}
local marks=0;package.loaded['CSV/NeedTiming']={mark=function()marks=marks+1 end}
local history=0
local C={active={},seen={},seenCount=0,sequence=0,lastLoot={},lastOrdinary={},preferences=function()return {} end,entryGain=function()return 1,1,1 end,observeSettings=function()end,remember=function()history=history+1 end}
V.client=C
require('CSV/Playback').install(C,V,function()return true end,function()end)
C.observeSettings=function()end
local E=require 'CSV/Encounter'
local function emit()
 local ctx={voice='test',group='Threat',line={id='Threat_1'},facts=facts,policy={priority=2},intensity=1}
 assert(C.emit(p,ctx,10));return ctx
end
local ctx=emit();assert(not E.players[p] and history==0 and marks==0,'handle acceptance cannot commit speech history')
now=now+300;C.sweep();assert(ctx.playbackEntry.finishedReason=='ended_before_start' and history==0,'early failure preserves repeat allowance')
playing=true;pending=true;ctx=emit();assert(not E.players[p],'queued sound is not an observed start')
pending=false;C.sweep();assert(E.players[p].reacted and history==1 and marks==1,'observed start commits once')
C.sweep();assert(history==1 and marks==1,'later sweeps cannot double commit')
C.cancel(C.active[1],'engine_finished',false);E.players[p]=nil;pending=true;ctx=emit()
now=now+5100;C.sweep();assert(ctx.playbackEntry.finishedReason=='start_timeout' and not E.players[p] and history==1,'timeout never commits encounter')
local P=require 'CSV/Priority'
assert(P.startle('Startle',true,3,false,'Threat'),'new alert may interrupt equal priority')
assert(not P.startle('Startle',true,3,false,'AcutePain'),'pain remains protected')
assert(not P.startle('Startle',true,3,true,'Threat'),'audition remains protected')
local safe=require 'CSV/Safety'
assert(safe.settled({near=0,visible=12,encounterThreat=false,recentThreat=false}))
assert(not safe.settled({near=0,visible=12,encounterThreat=false,recentThreat=true}))
assert(not safe.clear({near=0,visible=12,encounterThreat=false,directAttack=1}))
assert(not safe.clear({near=0,encounterThreat=false}))
-- Q and ordinary speech must share ownership even though Q uses native playback.
V.client=C
local Q=require 'CSV/Callout';local native=package.loaded['CSV/NativeVoice']
native.ready=function()return true end;native.painActive=function()return false end
V.bank=function()return {native={replacements={ShoutHey={'Call_1'},WhisperHey={'Quiet_1'}}},lines={Call_1='Hey!',Quiet_1='Over here.'}}end
p.getDescriptor=function()return {getVoicePrefix=function()return 'TestVoice'end}end
p.getPrimaryHandItem=function()end;p.getSecondaryHandItem=function()end;p.getWornItems=function()end
p.isCanShout=function()return true end;p.SayShout=function()end;p.playEmote=function()end
local qActive=false;local stopped={};local previousIsPlaying=emitter.isPlaying
emitter.isPlaying=function(_,ref)if type(ref)=='string' then return false end;if ref==999 then return qActive end;return playing end
emitter.stopSoundLocal=function(_,ref)stopped[ref]=true;if ref==999 then qActive=false end end
p.transmitPlayerVoiceSound=function()qActive=true;return 999 end
ItemTag={MEGAPHONE='mega'};ZombRand=function()return 0 end;addSound=function()end
playing=true;pending=false;ctx=emit()
assert(Q.call(p) and #C.active==0 and stopped[1],'Q stops the owned speech handle')
local ok,reason=C.play({actor=1,seq=999,line='Test',voice='test',radius=10,pitch=0},p,false)
assert(not ok and reason=='native_callout','normal speech cannot overlap Q')
qActive=false;now=now+300;Q.observe(p)
assert(C.play({actor=1,seq=1000,line='Test',voice='test',radius=10,pitch=0},p,false),'Q completion releases speech')
print('PASS engine start/failure history, alert protections, shared safety and Q/speech ownership')

-- A queued line loses eligibility before the engine starts it.
C.cancel(C.active[1],'test_reset',false)
pending=true;playing=true;local before=history;ctx=emit()
p.isDead=function()return true end;pending=false;C.sweep()
assert(history==before and ctx.playbackEntry.finishedReason=='actor_dead','death before start must not commit speech history')
p.isDead=function()return false end
pending=true;ctx=emit();before=history;pending=false
package.loaded['CSV/Activity'].block=function()return 'sleeping'end
C.sweep()
assert(history==before and ctx.playbackEntry.finishedReason=='sleeping','sleep before start must not consume the reaction')
package.loaded['CSV/Activity'].block=function()end
-- An invalid replacement must leave the current lower-priority voice alone.
ctx=emit();local current=ctx.playbackEntry
local previousEmitter=p.getEmitter;p.getEmitter=function()end
V.packetPriority=function()return 4 end
local packet={actor=1,seq=2000,line='Test',voice='test',radius=10,pitch=0}
local accepted,why=C.play(packet,p,false)
assert(not accepted and why=='emitter_unavailable' and C.active[1]==current and not current.finishedReason,'missing emitter must not cancel current speech')
p.getEmitter=previousEmitter
assert(C.play(packet,p,false),'rejected request can retry with the same packet')
C.cancel(C.active[1],'test_reset',false)
-- Failure after a handle is allocated must clean up that handle only.
local volume=emitter.setVolume
emitter.setVolume=function()error('configuration failed')end
packet.seq=2001;stopped[1]=nil
accepted,why=C.play(packet,p,false)
assert(not accepted and why=='sound_setup_failed' and #C.active==0 and stopped[1],'configuration failure must not leave untracked audio')
emitter.setVolume=volume
assert(C.play(packet,p,false),'failed configuration does not poison deduplication')
local entry=C.active[1];local failures=0
entry.onFailed=function()failures=failures+1 end
C.cancel(entry,'test_cancel',false);C.cancel(entry,'test_cancel',false)
assert(failures==1,'cancellation callbacks run at most once')
print('PASS eligibility before start, failed replacement, safe handle cleanup, retry and idempotent cancellation')

-- Remaining crouched must not bypass engine completion checks.
package.loaded['CSV/State']={capture=function()return {directAttack=1}end}
p.isSneaking=function()return true end
packet.seq=2002;packet.engaged=true
assert(C.play(packet,p,false))
playing=false;now=now+300;C.sweep()
assert(#C.active==0 and C.lastPlayback.outcome=='engine_finished' or #C.active==0 and C.lastPlayback.outcome=='ended_before_start','crouched active attack still releases a finished handle')
p.isSneaking=function()return false end;packet.engaged=nil
-- An emitter query error is not evidence of successful startup.
playing=true;pending=true;before=history;ctx=emit()
local checkPending=emitter.hasSoundsToStart
emitter.hasSoundsToStart=function()error('emitter unloaded')end
C.sweep()
assert(history==before and ctx.playbackEntry.finishedReason=='emitter_check_error')
emitter.hasSoundsToStart=checkPending;pending=false
packet.seq=2003;assert(C.play(packet,p,false))
emitter.setVolume=function()error('emitter update failed')end
C.sweep()
assert(#C.active==0 and C.lastPlayback.outcome=='sound_update_failed','broken active entry is removed instead of failing every tick')
emitter.setVolume=volume
print('PASS crouched completion, failed startup query and bounded update failure')
