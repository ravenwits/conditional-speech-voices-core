package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/client/?.lua;'..package.path
package.loaded['CSV/Core']={voice=function()return 'test'end}
package.loaded['CSV/NativeVoice']={supported=function(v)return v=='test'end}
local M=require 'CSV/AlpCallout';local count,vanilla=0,0
M.call=function()count=count+1;return true end
local menu={emote=function()vanilla=vanilla+1 end,onKeyPressed=function()end,onKeyReleased=function()end}
M.install(menu);M.install(menu)
local p={setJoypadIgnoreAimUntilCentered=function()end}
menu.emote({character=p},'shout');assert(count==1 and vanilla==0)
menu.emote({character=p},'wave');assert(count==1 and vanilla==1)
M.call=function()return false end
menu.emote({character=p},'shout');assert(vanilla==2)
print('PASS radial shout one dispatch, idempotent hook, unrelated emote and vanilla fallback')
