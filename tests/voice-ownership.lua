local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local pain,callout=false,false
local interrupted=0
local client={active={}}
local V={client=client,voice=function(p)return p.voice end}
package.loaded['CSV/Core']=V
package.loaded['CSV/NativeVoice']={painActive=function()return pain end}
package.loaded['CSV/Callout']={busy=function()return callout end,interrupt=function()interrupted=interrupted+1 end}
local owner=require 'CSV/VoiceOwnership'
local foreign={voice='other'}
local cancelled={}
client.cancel=function(entry,reason)
    cancelled[#cancelled+1]={entry=entry,reason=reason}
    for i=#client.active,1,-1 do if client.active[i]==entry then table.remove(client.active,i)end end
end
for _,voice in ipairs({'bob','kate','alp','mujde','third-party-voice'})do
    local actor={voice=voice,isLocalPlayer=function()return true end}
    local normal={player=actor,priority=1,group='Hungry'}
    local other={player=foreign,priority=1}
    local preview={player=actor,priority=1,preview=true}
    client.active={preview,normal,other};cancelled={}
    assert(not owner.claimSpeech(actor,{priority=4,group='Injured'}))
    assert(#cancelled==0 and #client.active==3,'blocked preemption must not partially cancel another entry')
    client.active={normal,other}
    assert(owner.check(actor,{priority=3,group='Panic'}))
    assert(#cancelled==0,'checking a queue candidate must not cancel speech')
    assert(owner.claimSpeech(actor,{priority=3,group='Panic'}))
    assert(#cancelled==1 and #client.active==1 and client.active[1]==other)
    callout=true
    local allowed,reason=owner.check(actor,{priority=4,group='Injured'})
    assert(not allowed and reason=='native_callout')
    callout=false;client.active={normal,preview,other};pain=true;cancelled={}
    assert(not owner.calloutAllowed(actor))
    assert(not owner.claimSpeech(actor,{priority=4,preview=true}))
    owner.nativeUpdate(actor,true)
    assert(#cancelled==2 and #client.active==1 and client.active[1]==other,'native injury owns the actor, including audition')
    assert(cancelled[1].reason=='native_'..voice..'_pain')
    pain=false
    assert(owner.calloutAllowed(actor) and owner.check(actor,{priority=1}),'finished injury releases ownership')
end
assert(interrupted==5)
print('PASS atomic voice ownership, Q/pain/speech priority, actor isolation and third-party parity')
