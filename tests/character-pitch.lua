package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/client/?.lua;'..package.path
package.loaded['CSV/Core']={finite=function(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end}
local applied;package.loaded['CSV/NativeVoice']={safeApply=function(p)applied=p end}
getText=function(k)return k end
local function player(pitch)
 local d={pitch=pitch,getVoicePitch=function(s)return s.pitch end,setVoicePitch=function(s,v)s.pitch=v end}
 return {getDescriptor=function()return d end,isLocalPlayer=function()return true end,isDead=function()return false end}
end
local a,b=player(100),player(-37);local current=a;getPlayer=function()return current end
local options={}
function options:getOption()return self.option end
function options:addSlider(id,label,lo,hi,step,value,tip)
 self.option={id=id,value=value,min=lo,max=hi,step=step,tooltip=tip,getValue=function(s)return s.value end,setValue=function(s,v)s.value=v end,setEnabled=function(s,v)s.isEnabled=v end};return self.option
end
MainOptions={addModOptionsPanel=function()end,toUI=function()end}
local M=require 'CSV/CharacterPitch';M.install(options);local o=options.option
assert(o.value==100 and o.getValue==nil and o.step==1,'reads exact character value; excluded from global serialization')
o:onChangeApply(100);assert(a:getDescriptor().pitch==100,'absolute value never accumulates')
o:onChangeApply(-10);assert(a:getDescriptor().pitch==-10 and applied==a)
MainOptions:toUI();assert(o.value==-10,'reopen reads saved descriptor')
-- Moving the slider without Apply must not mutate the character.
o.value=70;MainOptions:toUI();assert(o.value==-10 and a:getDescriptor().pitch==-10)
current=b;assert(not M.apply(80),'stale panel cannot modify another character')
MainOptions:addModOptionsPanel();assert(o.value==-37)
o:onChangeApply(200);assert(b:getDescriptor().pitch==100 and a:getDescriptor().pitch==-10)
assert(not M.apply(0/0));assert(b:getDescriptor().pitch==100)
current=nil;MainOptions:toUI();assert(not o.isEnabled and not M.apply(20),'main menu disabled')
current=a;MainOptions:toUI();assert(o.isEnabled and o.value==-10,'save isolation')
print('PASS character pitch absolute bounds, exact initialization, apply/cancel, save isolation, stale owner guard and no global serialization')
