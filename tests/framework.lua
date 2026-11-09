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
R.register('Example',{schema=1,bank=b,voices={{id='test',name='Test',prefix='VoiceCSVTestP',base='VoiceFemale',preview='Test_1'}}})
assert(not pcall(R.register,'Example',{schema=1,bank=b,voices={}}))
assert(not pcall(R.register,'Conflict',{schema=1,bank=b,voices={{id='other',name='Other',prefix='VoiceCSVTestP',base='VoiceMale',preview='Test_1'}}}))
local V=require 'CSV/Core'
assert(V.available() and V.pack.extraVoices.test==b and #V.pack.voiceOrder==2)
assert(V.pack.voices.test.base=='VoiceFemale')
assert(V.contextLine({},'test','Thirst',4,{visible=0,recentThreat=false}).id=='ThirstCritical_1')
local N=require 'CSV/NativeVoice';assert(N.prefix(0,'test')=='VoiceCSVTestP100')
assert(not pcall(R.register,'Late',{}))
assert(b.extraVoices==nil,'provider bank must not be mutated')
print('PASS third party female voice, shared context, unique identity, duplicates and registry freeze')
