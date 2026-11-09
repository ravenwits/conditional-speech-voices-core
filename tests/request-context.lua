local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local p={}
local oldOutcome,oldPsych,oldInjury={},{},{}
local state={outcome={[p]=oldOutcome}}
local psychology={context={[p]=oldPsych},players={}}
local injury={context={[p]=oldInjury}}
package.loaded['CSV/Core']={now=function()return 100 end,config={enabled=true},languageSupported=function()return true end}
package.loaded['CSV/State']=state
package.loaded['CSV/Psychology']=psychology
package.loaded['CSV/Injury']=injury
package.loaded['CSV/Recovery']={players={}}
package.loaded['CSV/Loot']={players={}}
package.loaded['CSV/Actors']={call=function(_,name)return name=='isLocalPlayer' end}
package.loaded['CSV/Trace']={request=function()return {}end}
local request=require 'CSV/SpeechRequest'
local e={player=p,group='Psychology',outcome={},psychology={},injury=123,alert=true,reload={}}
local ok=pcall(request.withContext,e,function()
    assert(state.outcome[p]==e.outcome and state.nativeAlert[p]==true)
    assert(psychology.context[p]==e.psychology and injury.context[p]==123)
    assert(state.reload[p]==e.reload)
    error('observer dispatch failed')
end)
assert(not ok)
assert(state.outcome[p]==oldOutcome and psychology.context[p]==oldPsych and injury.context[p]==oldInjury)
assert(state.nativeAlert[p]==nil and state.reload[p]==nil,'failed dispatch restores absent contexts too')
e.outcome=nil;e.reload=nil
assert(not request.valid(e),'orphaned observer event cannot play after owner replacement')
psychology.players[p]={queue={e.psychology},last={}}
assert(request.valid(e))
e.psychology.kind='zombieKill'
request.accept(e)
assert(e.psychology.consumed and #psychology.players[p].queue==0)
assert(not request.valid(e),'consumed event cannot be replayed')
assert(psychology.players[p].last.zombieKill==100)
print('PASS observer context rollback, orphan rejection and completion ownership')
