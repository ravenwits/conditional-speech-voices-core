local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
getActivatedMods=function()return {contains=function()return false end}end
local R=require 'CSV/Registry'
local foreign={unexpected=true}
local bank={id='test',language='XX',revision='1',data={groups={},clips={}},extras={catalog={}},whispers={catalog={}},expressions={catalog={},bySource={}},profanity={ids={}},peaklimits={},
 voiceOrder={'ghost'},voiceBanks=foreign,extraVoices=foreign,semanticAliases=foreign,hasCustomVoices='wrong'}
local voices={{id='example',name='Example',vanilla=true,builtinPrefix='VoiceMale'}}
bank.voices=voices
R.register('Example',{schema=1,bank=bank,voices=voices})
local V=require 'CSV/Core'
assert(#V.pack.voiceOrder==1 and V.pack.voiceOrder[1]=='example','provider metadata must not inject phantom registered voices')
assert(V.pack.voiceBanks.example==bank and V.pack.voiceBanks.unexpected==nil)
assert(V.pack.extraVoices.unexpected==nil and V.pack.semanticAliases.unexpected==nil)
assert(V.pack.voices[1]==nil and V.pack.voices.example==voices[1],'runtime voice map must not reuse the provider array')
assert(V.pack.hasCustomVoices==false)
assert(foreign.example==nil and voices.example==nil and bank.voiceOrder[1]=='ghost','assembling Core must not mutate provider-owned tables')
print('PASS provider metadata isolation, registry-only voices and immutable source tables')
