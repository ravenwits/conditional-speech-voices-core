local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
getActivatedMods=function()return {contains=function()return false end,size=function()return 1 end,get=function()return 'CSV-Voice-Example'end}end
package.preload['CSV_Packs/CSV-Voice-Example']=function()return {schema=1,voices={{id='example',name='Example',prefix='VoiceCSVExampleP',base='VoiceMale',preview='Line_1'}},bank={id='example',language='XX',revision='1',data={groups={},clips={}},extras={catalog={}},whispers={catalog={}},expressions={catalog={},bySource={}},profanity={ids={}},peaklimits={},lines={},native={suffixes={},pain={},replacements={ShoutHey={},WhisperHey={}}}}}end
local p=require 'CSV/Pack'
assert(p.extraVoices.example and p.voices.example.name=='Example')
assert(#p.voiceOrder==1 and p.voiceOrder[1]=='example')
print('PASS active mod provider discovery without English, Turkish or manual registration')
