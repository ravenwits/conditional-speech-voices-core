package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/client/?.lua;'..package.path
package.loaded['CSV/Core']={voice=function()return 'test'end}
package.loaded['CSV/NativeVoice']={supported=function(v)return v=='test'end,ready=function()return true end}
local M=require 'CSV/Callout';local call=M.call;local count,vanilla=0,0
M.call=function()count=count+1;return true end
local menu={emote=function()vanilla=vanilla+1 end,onKeyPressed=function()end,onKeyReleased=function()end}
M.install(menu);M.install(menu)
local p={setJoypadIgnoreAimUntilCentered=function()end}
menu.emote({character=p},'shout');assert(count==1 and vanilla==0)
menu.emote({character=p},'wave');assert(count==1 and vanilla==1)
M.call=function()return false end
menu.emote({character=p},'shout');assert(vanilla==2)
local core=package.loaded['CSV/Core']
core.client={preferences=function()return {profanity=false}end}
core.bank=function()return {native={replacements={WhisperHey={'Tagged'}}},lines={Tagged='Tagged'}} end
package.loaded['CSV/VoiceOwnership']={calloutAllowed=function()return true end}
package.loaded['CSV/Pack']={profanity={ids={}},extraVoices={test={profanity={ids={Tagged=true}}}}}
package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/shared/?.lua;'..package.path
local actor={isSneaking=function()return true end,isCanShout=function()return true end,
 transmitPlayerVoiceSound=function()error('Marked Q callout reached the native emitter')end}
assert(call(actor)==true and M.metrics.blocked==1)
print('PASS radial shout dispatch, vanilla fallback and profanity filtering')
