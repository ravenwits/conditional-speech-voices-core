local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local function bank()
 return {id='test',schema=1,language='XX',revision='1',data={groups={},clips={}},extras={approved=true,catalog={}},whispers={approved=true,catalog={}},expressions={approved=true,catalog={},bySource={}},profanity={ids={}},peaklimits={},native={suffixes={},replacements={ShoutHey={},WhisperHey={}},pain={}},lines={}}
end
local R=require 'CSV/Registry'
local samples=bank()
samples.data.clips.sample_Hello={sound='CSV_sample_Hello',duration=1000}
samples.data.clips.sample_Hurt={sound='CSV_sample_Hurt',duration=1000}
local voice={id='sample',name='Sample',prefix='VoiceCSVSampleP',base='VoiceMale',preview='Hello',previewLines={'Hello','Hurt'},previewLast='Hurt'}
for _,invalid in ipairs({{}, {'Absent'}, {'Hello','Hello'}, {[1]='Hello',extra='Hurt'}, {[1]='Hello',[3]='Hurt'}})do
 voice.previewLines=invalid
 assert(not pcall(R.register,'BadPlaylist',{schema=1,bank=samples,voices={voice}}))
 assert(R.providers.BadPlaylist==nil)
end
voice.previewLines={'Hello','Hurt'};voice.previewLast='Absent'
assert(not pcall(R.register,'BadPlaylist',{schema=1,bank=samples,voices={voice}}))
voice.previewLast='Hurt'
R.register('PreviewExample',{schema=1,bank=samples,voices={voice}})
local b=bank();b.data.clips.test_ThirstCritical_1=true;b.data.contextLines={{id='ThirstCritical_1',group='Thirst',min=4,max=4,delivery='exhausted'}}
b.data.contextLines[2]={id='PanicEscape_1',group='Panic',min=3,max=4,threat=true,delivery='frightened'}
for _,group in ipairs({'ThreatCalm','ThreatTense','ThreatWhisper'}) do
 local id=group..'_1'
 b.extras.catalog[id]={id=id,group=group,text=group}
 b.lines[id]=group
 b.data.clips['test_'..id]=true
end
for _,group in ipairs({'Fire','DoorLocked','DoorBlocked','EngineStalled'}) do
 for i=1,3 do
  local id=group..'_'..i
  b.extras.catalog[id]={id=id,group=group,text=id}
  b.data.clips['test_'..id]=true
  b.lines[id]=id
 end
end
local semantics=require 'CSV/PackSemantics'
 b.extras.catalog.TracksMore_1={id='TracksMore_1',group='TracksMore'}
 b.lines.TracksMore_1='More tracks.'
 b.data.clips.test_TracksMore_1=true
b.data.groups.GunJammed={}
for _,id in ipairs(semantics.groups.GunJammed) do
 b.data.groups.GunJammed[#b.data.groups.GunJammed+1]={id=id,text=id}
end
local jamFear='Expr_frightened_GunJammed_1'
b.expressions.catalog[jamFear]=semantics.expressions[jamFear]
b.data.clips['test_'..jamFear]={duration=1000}
b.lines[jamFear]='The weapon jammed!'
b.data.clips.test_GunJammed_1={duration=1000}
b.lines.GunJammed_1='The weapon jammed.'
b.data.clips.test_PanicEscape_1=true
 b.lines.PanicEscape_1="Get away."
for _,group in ipairs({'MortalFear','HumanDanger','KeepHidden','ShelterThreat'}) do
 local id=group..'_1'
 b.extras.catalog[id]=semantics.extras[id]
 b.whispers.catalog[id]=semantics.whispers[id]
 b.lines[id]='Default '..group
 b.data.clips['test_'..id]={duration=1000}
end
b.lines.ThreatTense_2='Stay back. I need room to move.'
b.data.clips.test_ThreatTense_2={duration=1000}
R.register('Example',{schema=1,bank=b,voices={{id='test',name='Test',prefix='VoiceCSVTestP',base='VoiceFemale',preview='Test_1'}}})
assert(not pcall(R.register,'Example',{schema=1,bank=b,voices={}}))
assert(not pcall(R.register,'Conflict',{schema=1,bank=b,voices={{id='other',name='Other',prefix='VoiceCSVTestP',base='VoiceMale',preview='Test_1'}}}))
do
 local E=require 'CSV/Expressions'
 local normal={id='Endurance_1',group='Endurance'}
 local breathless={id='Expr_breathless_Endurance_1',source=normal.id,group=normal.group,profile='breathless'}
 local drunk={id='Expr_slurred_Endurance_1',source=normal.id,group=normal.group,profile='slurred'}
 local bank={expressions={approved=true,catalog={[breathless.id]=breathless,[drunk.id]=drunk}}}
 local available={[breathless.id]=true,[drunk.id]=true}
 local voice={bank=function()return bank end,extended=function()return true end,
  clip=function(_,id)return available[id] end}
 local f={endurance=2,drunk=2}
 assert(E.pick(voice,'test',normal,f)==breathless)
 available[breathless.id]=nil
 assert(E.pick(voice,'test',normal,f)==drunk)
 available[drunk.id]=nil
 assert(E.pick(voice,'test',normal,f)==normal)
end
local V=require 'CSV/Core'
assert(V.available() and V.pack.extraVoices.test==b and #V.pack.voiceOrder==2)
assert(V.pack.voices.test.base=='VoiceFemale')
assert(V.contextLine({},'test','Thirst',4,{visible=0,recentThreat=false}).id=='ThirstCritical_1')
assert(V.delivery('test','ThreatWhisper_1')=='whisper')
 getTimestampMs=function()return 100000 end
local selection={preferences=function()return {}end}
require('CSV/Selection').install(selection,V)
local player={}
local facts={sneaking=false,panic=0,near=1,accessibleNear=1,reactiveNear=0,targeted=0,visible=1}
local function plan(group)
 return selection.plan(player,'test',group,facts.panic>=3 and 4 or 1,4,facts,{whisper=true})
end
local line,decision=plan('Threat')
assert(line.id=='ThreatCalm_1' and decision.mode=='spoken' and decision.radius==4)
facts.reactiveNear=1;facts.targeted=1
line,decision=plan('Threat')
assert(line.id=='ThreatTense_1' and decision.mode=='spoken')
facts.approaching=1
line=plan('Threat')
assert(line.id=='ThreatTense_1')
selection.remember(player,line.id,line)
line,decision=plan('Threat')
assert(decision.mode=='silent' and decision.reason=='semantic_repeat')
facts.sneaking=true
line,decision=plan('Threat')
assert(line.id=='ThreatWhisper_1' and decision.mode=='spoken' and decision.radius==2)
facts.whisperRisk=1
line,decision=plan('Threat')
assert(decision.mode=='silent')
facts.whisperRisk=0;facts.accessibleNear=0
line,decision=plan('Threat')
assert(decision.mode=='silent')
facts.accessibleNear=1;facts.sneaking=false;facts.panic=4
facts.attacking=1;facts.visible=0;facts.recentThreat=false
line,decision=plan('Panic')
assert(line.id=='PanicEscape_1' and decision.mode=='spoken')
facts.fire=true;facts.health=90
line,decision=plan('Panic')
assert(not line and decision.mode=='silent','Minor fire does not trigger a scream')
facts.health=20
line,decision=plan('Panic')
assert(line.id=='Fire_2' and V.delivery('test',line.id)=='shout' and decision.radius==15)
b.data.clips.test_Alt_Fire_2={duration=1000}
b.lines.Alt_Fire_2='Ah! Get it off!'
selection.history[player]={Fire_1=V.now(),Fire_3=V.now()}
selection.remember(player,line.id,line)
line,decision=plan('Panic')
assert(line.id=='Alt_Fire_2' and decision.mode=='spoken' and V.delivery('test',line.id)=='shout')
assert(V.maxPriority(line.id)==V.maxPriority('Fire_2') and V.allowStealth(line.id)==V.allowStealth('Fire_2'))
facts.health=90
line,decision=plan('Panic')
assert(not line and decision.mode=='silent','An alternate cannot bypass the fire severity check')
facts.health=20
b.data.clips.test_Fire_2=nil
assert(plan('Panic').id=='Fire_1','The fire cry is optional')
facts.fire=false;facts.health=100;facts.attacking=0;facts.near=0;facts.reactiveNear=0
facts.outcome={kind='window',completed=true,nativeSound='locked',before={open=false},after={open=false,locked=true}}
assert(selection.chooseBaseLine(player,'test','WindowLocked',1,4,facts).id=='DoorLocked_2')
b.data.clips.test_DoorLocked_2=nil
assert(selection.chooseBaseLine(player,'test','WindowLocked',1,4,facts).id=='DoorLocked_1','A locked window accepts another neutral take')
facts.outcome.after.blocked=true
assert(selection.chooseBaseLine(player,'test','WindowBarricaded',1,4,facts).id=='DoorBlocked_3')
facts.outcome={kind='vehicle_stop',completed=true,localAction=true,nativeCause='damage',before={running=true},after={running=false}}
facts.directAttack=1
assert(selection.chooseBaseLine(player,'test','EngineStalled',1,4,facts).id=='EngineStalled_2')
facts.outcome.nativeCause=nil
assert(selection.chooseBaseLine(player,'test','EngineStalled',1,4,facts)==nil,'An unexplained engine stop cannot trigger a stall line')
facts.outcome=nil;facts.panic=0;facts.jammed=true;facts.directAttack=1
assert(selection.chooseLine(player,'test','GunJammed',1,4,facts).id==jamFear)
facts.traits={brave=true};facts.panic=4
assert(selection.chooseLine(player,'test','GunJammed',1,4,facts).id=='GunJammed_1','Brave uses the tense fault take during contact')
facts.traits=nil;facts.panic=0
b.data.clips['test_'..jamFear]=nil
assert(selection.chooseLine(player,'test','GunJammed',1,4,facts).id=='GunJammed_1','A fear take is optional')
local actor={}
local danger={sneaking=false,near=1,visible=1,panic=3,health=100,
 psychology={kind='humanAttack',verified=true},traits={brave=true}}
local function psychologyPlan()
 return selection.plan(actor,'test','Psychology',1,1,danger,{whisper=true})
end
line,decision=psychologyPlan()
assert(line.id=='ThreatTense_2' and decision.mode=='spoken','Older packs can use a focused MortalFear fallback')
for _,case in ipairs({
 {'MortalFear','humanAttack',3}, {'HumanDanger','humanAttack',2},
 {'KeepHidden','hiddenPursuer',3}, {'ShelterThreat','raid',3},
}) do
 local group=case[1]
 local normal='Alt_'..group..'Controlled_1'
 local whisper='Alt_Whisper_'..group..'Controlled_1'
 b.lines[normal]='Controlled '..group
 b.lines[whisper]=b.lines[normal]
 b.data.clips['test_'..normal]={duration=1000}
 b.data.clips['test_'..whisper]={duration=1000}
 danger.psychology={kind=case[2],verified=true,knownPursuer=true,homeKnown=true}
 danger.panic=case[3]
 danger.traits={brave=true}
 line,decision=psychologyPlan()
 assert(line.id==normal and decision.mode=='spoken' and danger.panic==case[3])
 danger.traits={desensitized=true};danger.sneaking=true
 line,decision=psychologyPlan()
 assert(line.id==whisper and decision.allowStealth and V.delivery('test',line.id)=='whisper')
 assert(V.allowStealth(whisper) and V.maxPriority(whisper)==V.maxPriority('Whisper_'..group..'_1'))
 danger.whisperRisk=1
 line,decision=psychologyPlan()
 assert(decision.mode=='silent' and decision.reason=='whisper_would_reveal')
 danger.whisperRisk=0;danger.sneaking=false;danger.traits={cowardly=true}
 line,decision=psychologyPlan()
 assert(line.id==group..'_1' and decision.mode=='spoken')
end
-- Every authored trait take must require a matching, available recording. Use actual
-- selection as well as the per-source lookup so a safety decision cannot be bypassed.
do
 local oldTraits=CharacterTrait
 CharacterTrait={}
 local selectedTrait
 local specialist={hasTrait=function(_,key)return key==selectedTrait end}
 local rules=require 'CSV/TraitSpeechRules'
 local neutral={panic=3,visible=1}
 for id,entry in pairs(require('CSV/VoiceAlternates'))do
  if entry.forTraits then
   b.data.clips['test_'..id]={duration=1000}
   b.lines[id]='Specialist '..id
   for key in pairs(entry.forTraits)do
    CharacterTrait[key]=key;selectedTrait=key
    assert(rules.preferredRecording(V,specialist,'test',entry.source,neutral,{},{}).id==id,id..': matching trait')
   end
   selectedTrait=nil
   assert(not rules.preferredRecording(V,specialist,'test',entry.source,neutral,{},{}),id..': unrelated trait')
   selectedTrait=next(entry.forTraits)
   if entry.traitCondition then
    assert(not rules.preferredRecording(V,specialist,'test',entry.source,{panic=2,visible=0},{},{}),id..': unconfirmed condition')
   end
   assert(not rules.preferredRecording(V,specialist,'test',entry.source,{fire=true,panic=4,visible=1},{},{}))
   b.profanity.ids[id]=true
   assert(not rules.preferredRecording(V,specialist,'test',entry.source,neutral,{},{profanity=false}))
   b.profanity.ids[id]=nil
   b.data.clips['test_'..id]=nil
   assert(not rules.preferredRecording(V,specialist,'test',entry.source,neutral,{},{}),id..': missing clip')
  end
 end
 for group,entry in pairs(rules.specialistRoutines)do
  local id=group..'_1'
  local event={kind='routine',verified=true,completed=true,routineGroup=group}
  local scene={sneaking=false,near=0,visible=0,recentThreat=false,outcome=event}
  b.lines[id]='Only a specialist may say '..id
  selectedTrait=next(entry.forTraits);CharacterTrait[selectedTrait]=selectedTrait
  assert(not selection.chooseBaseLine(specialist,'test',group,1,1,scene),id..': unavailable recording')
  b.data.clips['test_'..id]=true
  local chosen,policy=selection.plan(specialist,'test',group,1,1,scene,{safeSpeech=true})
  assert(chosen and chosen.id==id and policy.mode=='spoken',id..': completed activity')
  selectedTrait=nil
  assert(not selection.chooseBaseLine(specialist,'test',group,1,1,scene),id..': does not leak to other survivors')
  selectedTrait=next(entry.forTraits);event.verified=false
  assert(not selection.chooseBaseLine(specialist,'test',group,1,1,scene),id..': incomplete evidence')
  b.data.clips['test_'..id]=nil
 end
 local hunter='Alt_AnimalTracksHunter_1'
 b.data.clips['test_'..hunter]=true
 b.data.groups.AnimalTracks={{id='AnimalTracks_1'}}
 b.lines.AnimalTracks_1='Tracks.'
 b.data.clips.test_AnimalTracks_1=true
 local trackScene={sneaking=false,near=0,visible=0,recentThreat=false}
 local function tracks()return selection.plan(specialist,'test','AnimalTracks',1,1,trackScene,{safeSpeech=true})end
 selectedTrait='HUNTER'
 local tracked,delivery=tracks()
 assert(tracked and tracked.id==hunter and delivery.mode=='spoken','Hunter take after the stock AnimalTracks request')
 local trackHistory=selection.history[specialist] or {}
 selection.history[specialist]=trackHistory
 trackHistory.AnimalTracks_1=math.max(V.now(),1)
 tracked=tracks()
 assert(tracked and tracked.id==hunter,'Hunter take when the ordinary TracksMore fallback wins')
 selectedTrait=nil
 tracked=tracks()
 assert(tracked and tracked.id=='TracksMore_1','Only Hunter can use the alternate')
 selectedTrait='HUNTER'
 b.data.clips.test_AnimalTracks_1=nil;b.data.clips.test_TracksMore_1=nil
 tracked=tracks()
 assert(tracked and tracked.id==hunter,'A pack may record just the Hunter take')
 trackHistory.AnimalTracks_1=nil
 b.data.clips['test_'..hunter]=nil
 selectedTrait='EAGLE_EYED'
 local id='Alt_ThreatCalmSpotter_1'
 local observed={sneaking=false,panic=0,near=1,accessibleNear=1,reactiveNear=0,targeted=0,visible=1}
 local function warn()return selection.plan(specialist,'test','Threat',1,4,observed,{whisper=true})end
 assert(warn().id=='ThreatCalm_1','Old pack uses the original warning')
 b.data.clips['test_'..id]=true
 local spotted,heard=warn()
 assert(spotted.id==id and heard.mode=='spoken')
 selection.remember(specialist,id,spotted)
 assert(warn().id=='ThreatCalm_1','A recent specialist take yields to the original')
 selectedTrait='GRACEFUL'
 local quiet='Alt_Whisper_KeepHiddenQuiet_1'
 b.data.clips['test_'..quiet]=true
 danger.traits={};danger.sneaking=true;danger.psychology={kind='hiddenPursuer',verified=true,knownPursuer=true}
 line,decision=selection.plan(specialist,'test','Psychology',1,1,danger,{whisper=true})
 assert(line.id==quiet and V.delivery('test',quiet)=='whisper' and decision.allowStealth,'Use the recorded whisper')
 danger.whisperRisk=1
 line,decision=selection.plan(specialist,'test','Psychology',1,1,danger,{whisper=true})
 assert(decision.mode=='silent','A trait must not override exposure')
 selectedTrait='FAST_READER'
 local reader='Alt_BookReadingReader_1'
 b.data.clips['test_'..reader]=true
 local reading={sneaking=false,outcome={kind='routine',verified=true,completed=true,routineGroup='BookReading'}}
 assert(selection.chooseBaseLine(specialist,'test','BookReading',1,1,reading).id==reader,'Optional-only pack can play its verified activity')
 reading.outcome.completed=false
 assert(not selection.chooseBaseLine(specialist,'test','BookReading',1,1,reading))
 selectedTrait='STOUT'
 local relief='Alt_ReliefLoadStrong_1'
 b.data.clips['test_'..relief]=true
 assert(selection.chooseBaseLine(specialist,'test','ReliefLoad',1,1,{sneaking=false}).id==relief,'A recorded specialist relief is usable on its own')
 selectedTrait='DEXTROUS'
 local pickup='Alt_FoundLootPacked_1'
 b.data.clips['test_'..pickup]=true
 b.data.clips.test_FoundLoot_3=true
 b.lines.FoundLoot_3='I can take this.'
 b.data.groups.FoundLoot={{id='FoundLoot_1'},{id='FoundLoot_2'},{id='FoundLoot_3'}}
 b.data.groups.Explore={{id='Explore_1'},{id='Explore_2'}}
 local gathering={sneaking=false,near=0,visible=0,recentThreat=false,pickup=true}
 local chosen,policy=selection.plan(specialist,'test','FoundLoot',1,4,gathering,{safeSpeech=false})
 assert(policy.mode=='upstream' and chosen.id==pickup,'Respect upstream filters and select the matching recording')
 selectedTrait='FIRST_AID'
 local sparse='Alt_BandageDoneFirstAid_1'
 b.lines.BandageDone_2='I wrapped it.'
 b.data.clips.test_BandageDone_2=true
 b.extras.catalog.BandageDone_2={id='BandageDone_2',group='BandageDone'}
 -- groupLines caches the pack's immutable extras catalogue.
 local entries={}
 for key,val in pairs(b.extras.catalog)do entries[key]=val end
 b.extras.catalog=entries
 b.data.clips['test_'..sparse]=true
 local outcome={sneaking=false,near=0,visible=0,recentThreat=false,outcome={kind='bandage',completed=true,before={bandaged=false},after={bandaged=true}}}
 local bandage=selection.plan(specialist,'test','BandageDone',1,1,outcome,{safeSpeech=true})
 assert(bandage and bandage.id==sparse,'A different eligible normal take covers the sparse bank')
 selectedTrait='OUTDOORSMAN'
 b.data.clips.test_Alt_WetOutdoorsy_1=true
 assert(not rules.preferredRecording(V,specialist,'test','Wet_3',{cold=3},{},{}),'Severe wet/cold does not reuse mild discomfort')
 selectedTrait='ADRENALINE_JUNKIE'
 local express='Expr_frightened_PanicEscape_2'
 b.expressions.catalog[express]=semantics.expressions[express]
 b.data.clips.test_Alt_PanicEscapeAdrenaline_1=true
 assert(rules.preferredRecording(V,specialist,'test',express,neutral,{},{}).id=='Alt_PanicEscapeAdrenaline_1')
 for _,extra in ipairs({id,quiet,reader,relief,pickup,sparse,'Alt_WetOutdoorsy_1','Alt_PanicEscapeAdrenaline_1'})do b.data.clips['test_'..extra]=nil end
 CharacterTrait=oldTraits
end
local traits=require 'CSV/Traits'
assert(traits.startle({panic=4,traits={brave=true}})=='StartleBrave')
assert(traits.startle({panic=4,traits={desensitized=true}})=='StartleDesensitized')
assert(traits.startle({panic=4})=='StartleCowardly')
do
 local f={endurance=2,near=0,sneaking=false}
 for _,key in ipairs({'asthmatic','outOfShape','unfit'})do
  f.traits={[key]=true}
  assert(traits.context('Endurance',f)=='ExhaustedCoping',key)
 end
 f.traits=nil
 assert(traits.context('Endurance',f)==nil)
 f.endurance=3
 assert(traits.context('Endurance',f)=='ExhaustedCoping')
 f.traits={asthmatic=true}
 f.endurance=1
 assert(traits.context('Endurance',f)==nil)
 f.endurance=2
 for key,value in pairs({sneaking=true,near=1,humanThreat=true,fire=true,pain=1,bleeding=1,drunk=1,coldSymptoms=1}) do
  local old=f[key]
  f[key]=value
  assert(traits.context('Endurance',f)==nil,key)
  f[key]=old
 end
end
local psychology=require 'CSV/PsychologyRules'
assert(psychology.pool({kind='pursuit',intent=true,verified=true},{traits={brave=true},panic=1})=='PursuitSteady')
assert(psychology.pool({kind='pursuit',intent=true,verified=true,experience='practiced'},{traits={cowardly=true},panic=1})=='PursuitUneasy')
assert(psychology.pool({kind='humanKill',verified=true},{traits={pacifist=true},near=0,visible=0,recentThreat=false})=='TraitReluctant')
local outcomes=require 'CSV/OutcomeRules'
local openWindow={kind='car_window_open',completed=true,before={open=false},after={open=true,destroyed=false}}
assert(outcomes.classify(openWindow)=='CarWindowOpened')
openWindow.cancelled=true
assert(outcomes.classify(openWindow)==nil)
local smashed={kind='car_window_smash',completed=true,before={destroyed=false},after={destroyed=true}}
assert(outcomes.classify(smashed)=='CarWindowBroken')
smashed.before.destroyed=true
assert(outcomes.classify(smashed)==nil)
local N=require 'CSV/NativeVoice';assert(N.prefix(0,'test')=='VoiceCSVTestP100')
do
 local saved=b.native
 b.native={suffixes={'DrunkHic'},replacements={DrunkHic={},ShoutHey={},WhisperHey={}}}
 local vanillaHiccup={getEvent=function()return 'Character/Voice/Female/Drunk/Hic'end,
  getVolume=function()return 1 end,getMaxDistance=function()return 150 end}
 local script
 GameSounds={getSound=function(name)
  assert(name=='VoiceFemaleDrunkHic')
  return {getRandomClip=function()return vanillaHiccup end,getCategory=function()return 'Player'end,
   getMasterName=function()return 'Primary'end}
 end,OnReloadSound=function()end,isKnownSound=function()return true end}
 GameSoundScript={new=function()return {Load=function(_,_,body)script=body end}end}
 assert(N.ensure(0,'test')=='VoiceCSVTestP100')
 assert(script:find('event = Character/Voice/Female/Drunk/Hic',1,true),'Missing custom hiccup uses stock audio')
 b.native=saved
end
assert(not pcall(R.register,'Late',{}))
assert(b.extraVoices==nil,'provider bank must not be mutated')
print('PASS third party female voice, shared context, unique identity, duplicates, registry freeze and threat selection')

-- B42 single-player calls the finder directly; multiplayer uses the stock
-- OnAnimalTracks listener, which must not be installed a second time.
do
 local requests={}
 ISAnimalTracksFinder={getAnimalTracks=function(_,track)return track end}
 local show=ISAnimalTracksFinder.getAnimalTracks
 package.loaded['Foraging/ISAnimalTracksFinder']=true
 package.loaded.ConditionalSpeech_Core={check_AnimalTracks=function(actor,track)
  requests[#requests+1]={actor,track}
 end}
 local actor={isLocalPlayer=function()return true end,isDead=function()return false end}
 local oldVoice=V.voice
 V.voice=function()return 'test' end
 local connected=true
 function isClient()return connected end
 function isServer()return false end
 local upstream=require 'CSV/Upstream'
 upstream.installed=true
 upstream.install()
 assert(ISAnimalTracksFinder.getAnimalTracks==show)
 connected=false;upstream.install()
 local track={}
 assert(ISAnimalTracksFinder.getAnimalTracks(actor,track)==track)
 ISAnimalTracksFinder.getAnimalTracks(actor,nil)
 assert(#requests==1 and requests[1][1]==actor and requests[1][2]==track)
 V.voice=oldVoice
end
print('PASS standalone animal track discovery uses the speaking character')
