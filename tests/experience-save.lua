local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local E=require 'CSV/Experience'
local saved={version=1,zombie='12',human='bad',injury=-4,raid=0/0,nativeZombieKills='wrong',zombieEncounters=math.huge,humanEncounters=-2,extension='keep'}
local md={csvExperience=saved,otherMod={preserve=true}}
local player={getModData=function()return md end,getZombieKills=function()return nil end}
local e=E.get(player)
assert(e==saved and e.zombie==12 and e.human==0 and e.injury==0 and e.raid==0,'normalize corrupt/legacy counters without replacing the record')
assert(e.zombieEncounters==0 and e.humanEncounters==0 and e.nativeZombieKills==0)
assert(E.level(player,'zombie')=='uncertain' and e.extension=='keep' and md.otherMod.preserve)
E.mark(player,'human');E.encounter(player,'human')
assert(e.human==1 and e.humanEncounters==1)
local again=E.get(player);assert(again==e and again.human==1,'normalization is repeat safe')
local snapshot=E.snapshot(player);E.mark(player,'human');assert(snapshot.human==1,'report snapshot does not change while rows are deferred')
local future={version=2,opaque={progress=123},zombie='future-format'}
md.csvExperience=future
e=E.get(player);E.mark(player,'human');E.encounter(player,'zombie')
assert(md.csvExperience==future and future.zombie=='future-format' and future.human==nil and future.opaque.progress==123,'older Core must not overwrite a newer save schema')
assert(E.get(player)==e and e.human==1 and e.historyUnknown and e.unsupportedVersion==2,'unknown schema uses session-only tracking')
md.csvExperience={zombie=9,human=2}
e=E.get(player);assert(e.version==1 and e.zombie==9 and e.human==2,'unversioned legacy counters are retained')
print('PASS malformed counters, repeat-safe legacy save repair, future schema preservation and frozen report snapshot')
