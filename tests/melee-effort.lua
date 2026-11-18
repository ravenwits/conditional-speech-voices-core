local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path

local scripts={}
local clip={
    getFile=function() return 'media/sound/CSV/test_Effort.mp3' end,
    getVolume=function() return 1 end,
    getMinDistance=function() return 1 end,
    getMaxDistance=function() return 10 end,
}
local source={
    getCategory=function() return 'Voice' end,
    getMasterName=function() return 'Voice' end,
    getRandomClip=function() return clip end,
}
GameSounds={
    getSound=function() return source end,
    isKnownSound=function(name) return scripts[name]~=nil end,
    OnReloadSound=function(script) scripts[script.name]=script.body end,
}
GameSoundScript={new=function() return {
    Load=function(self,name,body) self.name=name;self.body=body end,
} end}

local active={}
local core={
    pack={
        voiceBanks={test={native={suffixes={'MeleeAttack','Exercise'},pain={},replacements={
            MeleeAttack={'Effort'},Exercise={'Effort'},ShoutHey={},WhisperHey={},
        }}}},
        voices={test={prefix='VoiceTest',base='VoiceMale'}},
    },
    voice=function() return 'test' end,
    pitchMultiplier=function() return 1 end,
    client={active={}},
}
package.loaded['CSV/Core']=core
package.loaded['CSV/Callout']={busy=function() return false end}
local native=require 'CSV/NativeVoice'
local owner=require 'CSV/VoiceOwnership'
local prefix=native.ensure(0,'test')
local player={
    getDescriptor=function() return {getVoicePrefix=function() return prefix end} end,
    getEmitter=function() return {isPlaying=function(_,name) return active[name]==true end} end,
}
local clips={}
for body in scripts[prefix..'MeleeAttack']:gmatch('clip%s*{([^}]*)}') do clips[#clips+1]=body end
assert(#clips==7 and clips[1]:find('file%s*=') and clips[1]:find('volume%s*=%s*1'))
for i=2,#clips do assert(clips[i]:match('^%s*$'),'silent melee must have no file or event') end
assert(scripts[prefix..'Exercise']:find('volume = 0',1,true),'other effort definitions remain intact')

local speech={player=player,priority=1}
core.client.active={speech}
core.client.cancel=function(entry,reason)
    assert(entry==speech and reason=='native_melee_effort')
    core.client.active={}
end
local function pick(index)
    -- B42's emitter queues a handle only when the chosen clip has a source.
    active[prefix..'MeleeAttack']=clips[index]:find('file%s*=')~=nil
    owner.nativeUpdate(player,false)
end
pick(2)
assert(core.client.active[1]==speech and owner.check(player,{priority=1})==false)
core.client.active={}
assert(owner.check(player,{priority=1}),'silent effort does not block a new line')
core.client.active={speech}
pick(1)
assert(#core.client.active==0)
local allowed,reason=owner.check(player,{priority=1})
assert(not allowed and reason=='native_melee_effort')
print('PASS silent melee choice preserves speech and audible choice interrupts')
