local b='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=b..'shared/?.lua;'..b..'client/?.lua;'..package.path
local calls=0
package.loaded['ConditionalSpeech_Core']={generateSpeechFrom=function(_,g,i,m)assert(g=='Injured' and i==4 and m==4);calls=calls+1 end}
package.loaded['CSV/Trace']={step=function()end,begin=function()return {} end,call=function(_,_,fn,...)return fn(...)end}
local H=require 'CSV/CriticalHealth';local p={}
H.observe(p,{health=100},0);assert(calls==0)
H.observe(p,{health=24},100);assert(calls==1 and H.pending(p).stage==1)
local first=H.pending(p);H.accept(p,first);assert(H.pending(p)==nil)
H.observe(p,{health=5},200);assert(calls==2 and H.pending(p).stage==2)
H.accept(p,H.pending(p));H.observe(p,{health=11},300);H.observe(p,{health=9},400);assert(calls==2,'acknowledged threshold oscillation cannot spam')
H.observe(p,{health=40},500);H.observe(p,{health=40},10501);H.observe(p,{health=8},10502);assert(calls==3)
local e=H.pending(p);assert(not H.valid(p,e,{health=60}) and not H.valid(p,e,{health=0}))
H.observe(p,{health=8},30000);assert(H.pending(p)==nil and calls==3,'expired crisis does not loop')
H.observe(p,{health=8},31001);assert(calls==4,'unheard critical warning retries after bounded delay')
local D=require 'CSV/Delivery'
local f={health=8,near=0,visible=0,recentThreat=false,encounterThreat=false,sneaking=false,panic=0}
assert(D.decide('Injured',4,f,{}).priority==4)
assert(D.decide('ReliefCold',1,f,{}).mode=='silent')
f.health=80;f.visible=30;assert(D.decide('ReliefThreat',1,f,{}).mode=='spoken')
f.sneaking=true;f.contextWhisperAvailable=true;f.recentThreat=true
assert(D.decide('ReliefThreat',1,f,{whisper=true}).mode=='silent','whisper route cannot bypass safety')
print('PASS critical thresholds, acknowledgement, death/healing invalidation, hysteresis and final relief safety')
