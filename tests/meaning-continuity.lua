local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local semantic=require 'CSV/SemanticSpeech'
local history={}
semantic.remember(history,{id='StillAlive_2',text='Still here.'},100000)
assert(semantic.recent(history,{id='AfterZombieSteady_2',text='I made it.'},101000))
assert(not semantic.recent(history,{id='AfterZombieSteady_2',text='I made it.'},130000))
assert(not semantic.recent(history,{id='ReliefPain_1',text='The pain eased.'},101000))
semantic.remember(history,{id='Thirst_2',text='Water.'},100000)
assert(not semantic.recent(history,{id='NeedThirst_3',text='I need a drink badly.'},101000))
semantic.remember(history,{id='ThirstCritical_1',text='Water, please.'},100000)
assert(semantic.recent(history,{id='Whisper_ThirstCritical_2',text='I need water now.'},101000))
assert(not semantic.recent(history,{id='InjuryAcute_1',text='Ah!'},101000))
local kill=require 'CSV/KillSpeech';local psychology=require 'CSV/PsychologyRules'
local f={health=100,panic=0,unhappy=0,endurance=0,traits={desensitized=true},
 near=0,visible=0,recentThreat=false,encounterThreat=false,humanThreat=false,fire=false}
assert(kill.dark(f,'practiced'))
f.recentDistress=true
assert(not kill.dark(f,'practiced'))
local e={kind='humanKill',verified=true,experience='practiced'}
assert(psychology.pool(e,f)=='AfterHumanShaken')
f.recentDistress=false
assert(psychology.pool(e,f)=='AfterHumanSteady')
print('PASS meaning repeat expiry, separate needs, escalation and short emotional continuity')
