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
package.loaded['CSV/NativeVoice']={supported=function()return false end}
package.loaded['CSV/ProductionReport']={observe=function()end}
package.loaded['CSV/LootRules']={groups={}}
package.loaded['CSV/VehicleCombatRules']={groups={}}
package.loaded['CSV/Concealment']={active=function(s)return (s.directAttack or 0)>0 end}
local marks=0;package.loaded['CSV/NeedTiming']={mark=function()marks=marks+1 end}
local history=0
local C={active={},seen={},seenCount=0,sequence=0,lastThreat={},lastThreatPhase={},lastEngagement={},lastLoot={},lastOrdinary={},preferences=function()return {} end,entryGain=function()return 1,1,1 end,observeSettings=function()end,remember=function()history=history+1 end}
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
print('PASS engine acceptance/start/failure history, alert interruption protections and shared safety')
