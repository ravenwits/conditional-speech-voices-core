-- Real bank data and server/client routing; fake only engine services.
local base=os.getenv('CSV_TEST_CORE_LUA') or 'Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..base..'server/?.lua;'..package.path
getActivatedMods=function()return {contains=function()return false end}end
local registry=require 'CSV/Registry'
local function bank(id,language,revision,voices)
 local b={id=id,language=language,revision=revision,data={groups={},clips={}},extras={approved=true,catalog={}},whispers={approved=true,catalog={}},expressions={approved=true,catalog={},bySource={}},profanity={ids={}},peaklimits={},lines={},native={suffixes={},pain={},replacements={ShoutHey={},WhisperHey={}}}}
 for _,voice in ipairs(voices)do b.data.clips[voice.id..'_Thirst_1']={sound='Example_'..voice.id..'_Thirst_1',duration=1000}end
 registry.register('Test'..language,{schema=1,bank=b,voices=voices})
end
bank('csv.en','EN','english-2',{{id='bob',name='Bob',vanilla=true,builtinPrefix='VoiceMale'},{id='kate',name='Kate',vanilla=true,builtinPrefix='VoiceFemale'}})
bank('csv.tr','TR','turkish-9',{{id='alp',name='Alp',prefix='VoiceCSVAlpP',base='VoiceMale',preview='Thirst_1'},{id='mujde',name='Mujde',prefix='VoiceCSVMujdeP',base='VoiceFemale',preview='Thirst_1'}})
local mode='both'
local clock=100000;getTimestampMs=function()return clock end
Translator={getLanguage=function()error('UI language must not select a voice bank')end}
local V=require 'CSV/Core'
assert(V.languageSupported())
local en=mode~='tr';local tr=mode~='en'
local sounds={}
local emitter={playSoundImpl=function(_,name)sounds[#sounds+1]=name;return #sounds end,setVolume=function()end,setPitch=function()end,setPos=function()end,set3D=function()end,tick=function()end,isPlaying=function()return false end}
emitter.playVocals=emitter.playSoundImpl
local function actor(id,voice,localPlayer,noData)
 local definition=V.pack.voices[voice]
 local prefix=voice=='bob' and 'VoiceMale' or voice=='kate' and 'VoiceFemale' or definition and definition.prefix..'100' or 'VoiceCSVAlpP100'
 local md=noData and {} or {csvVoice=voice~='bob' and voice~='kate' and voice or nil}
 return {getOnlineID=function()return id end,isDead=function()return false end,isSneaking=function()return false end,isLocalPlayer=function()return localPlayer==true end,
 getDescriptor=function()return {getVoicePrefix=function()return prefix end,getVoiceType=function()return 0 end,getVoicePitch=function()return 25 end}end,
 getModData=function()return md end,getX=function()return id end,getY=function()return 0 end,getZ=function()return 0 end,getEmitter=function()return emitter end}
end
getSoundManager=function()return {getUIEmitter=function()return emitter end}end
local listener=actor(0,en and 'bob' or 'alp',true)
getNumActivePlayers=function()return 1 end;getSpecificPlayer=function()return listener end
local C={active={},seen={},seenCount=0,preferences=function()return {profanity=true}end,entryGain=function()return 1,1,1 end}
require('CSV/Playback').install(C,V,function()return V.languageSupported()end,function()end)
C.sweep=function()end -- no frame advancement during one synchronous relay
local recipients={};local outgoing={}
getOnlinePlayers=function()return {size=function()return #recipients end,get=function(_,i)return recipients[i+1]end}end
sendServerCommand=function(who,module,command,p)outgoing[#outgoing+1]={who=who,p=p,command=command}end
Events={OnClientCommand={Add=function()end}}
local S=require 'CSV_Server'
local expected={bob='csv.en',kate='csv.en',alp='csv.tr',mujde='csv.tr'}
for i,voice in ipairs({'bob','kate','alp','mujde'})do
 local available=expected[voice]=='csv.en' and en or expected[voice]=='csv.tr' and tr
 local p=actor(i,voice,false,true)
 local packet={version=1,actor=i,seq=1,voice=voice,line='Thirst_1',pitch=0,radius=10,pack=expected[voice],packRevision='0.40.7'}
 if available then
  assert(V.voice(p)==voice,'descriptor resolves '..voice..' before modData')
  assert(V.bank(voice).id==expected[voice])
  packet.packRevision=V.bank(voice).revision
  assert(V.validPacket(packet))
  recipients={listener,p};outgoing={};C.active={}
  assert(S.receive('CSV','speak',p,packet),'server accepted '..voice)
  assert(#outgoing==2 and outgoing[1].p.pack==expected[voice],'server retains speaker bank')
  assert(outgoing[1].p.pitch==25,'pitch comes from authenticated player')
  assert(C.play(outgoing[1].p,p),'remote playback '..voice)
  assert(sounds[#sounds]==V.clip(voice,'Thirst_1').sound,'uses speaker recording')
  local played=#sounds
  assert(not C.play(outgoing[1].p,p) and #sounds==played,'relay duplicate cannot play twice')
  assert(not S.receive('CSV','speak',p,packet),'server duplicate blocked')
  packet.pack=packet.pack=='csv.en' and 'csv.tr' or 'csv.en';assert(not V.validPacket(packet),'wrong bank rejected')
  packet.pack=expected[voice];packet.packRevision='bad';assert(not V.validPacket(packet),'wrong revision rejected')
  packet.packRevision=V.bank(voice).revision;packet.actor=999;assert(not S.receive('CSV','speak',p,packet),'spoofed actor rejected')
 else
  assert(V.voice(p)==nil,'missing bank must not substitute a different voice')
  assert(not V.validPacket(packet),'missing voice pack rejected')
 end
end
assert(not V.validPacket({voice={}}))

C.active={};C.seen={};C.seenCount=0
local self={version=1,actor=0,seq=77,voice='bob',line='Thirst_1',pitch=0,radius=10,pack='csv.en',packRevision=V.bank('bob').revision}
assert(C.play(self,listener),'local prediction starts once')
local count=#sounds
assert(sounds[count]=='Example_bob_Thirst_1','local speaker uses character vocals')
recipients={listener};outgoing={}
assert(S.receive('CSV','speak',listener,self))
assert(#outgoing==1 and not C.play(outgoing[1].p,listener) and #sounds==count,'local server echo does not duplicate prediction')
self.voice='missing';assert(not V.validPacket(self),'missing provider rejected without fallback')
print('PASS '..mode..': speaker bank routing, different UI, remote descriptor, missing packs, revision checks and duplicate protection')
