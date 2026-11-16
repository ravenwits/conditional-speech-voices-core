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
R.register('Example',{schema=1,bank=b,voices={{id='test',name='Test',prefix='VoiceCSVTestP',base='VoiceFemale',preview='Test_1'}}})
assert(not pcall(R.register,'Example',{schema=1,bank=b,voices={}}))
assert(not pcall(R.register,'Conflict',{schema=1,bank=b,voices={{id='other',name='Other',prefix='VoiceCSVTestP',base='VoiceMale',preview='Test_1'}}}))
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
b.data.clips['test_'..jamFear]=nil
assert(selection.chooseLine(player,'test','GunJammed',1,4,facts).id=='GunJammed_1','A fear take is optional')
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
assert(not pcall(R.register,'Late',{}))
assert(b.extraVoices==nil,'provider bank must not be mutated')
print('PASS third party female voice, shared context, unique identity, duplicates, registry freeze and threat selection')
