local b='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=b..'shared/?.lua;'..package.path
local now=1000
getTimestampMs=function()return now end
MoodleType={}
local S=require 'CSV/State'
local Safety=require 'CSV/Safety'
local zombies={}
local list={size=function()return #zombies end,get=function(_,i)return zombies[i+1]end}
local cell={getZombieList=function()return list end}
getCell=function()return cell end
local px=0
local player={getX=function()return px end,getY=function()return 0 end,getZ=function()return 0 end,
 isSneaking=function()return false end,CanSee=function(_,z) z.checks=z.checks+1;return z.shown end}
local function zombie(x,shown,target)
 return {checks=0,shown=shown,isDead=function()return false end,getX=function()return x end,
  getY=function()return 0 end,getZ=function()return 0 end,
  getTarget=function()return target and player or nil end,isAttacking=function()return target end}
end
for i=1,120 do zombies[i]=zombie(i+10,false,false)end
local farPursuer=zombies[120];farPursuer.shown=true;farPursuer.getTarget=function()return player end
local close=zombie(2,true,true);zombies[121]=close
S.beginFrame()
local first=S.capture(player)
assert(first.near==1 and first.attacking==1 and first.encounterThreat==true,'near attacks are checked beyond the remote budget')
assert(S.metrics.farSightChecks==48 and close.checks==1)
S.capture(player);assert(close.checks==1,'other consumers reuse the same frame')
S.endFrame()
zombies[121]=nil
local second=S.capture(player)
assert(second.near==0 and second.encounterThreat==nil and not Safety.clear(second),'incomplete sight must not start recovery')
local third=S.capture(player)
assert(farPursuer.checks==1 and third.encounterThreat==true,'rotation reaches the last pursuing zombie')
farPursuer.shown=false;farPursuer.getTarget=function()end
now=now+501
assert(not Safety.clear(S.capture(player)),'expired observations cannot confirm safety')
S.capture(player)
local settled=S.capture(player)
assert(Safety.clear(settled) and settled.recentThreat==true,'complete safe scan starts the existing recovery clock')
now=now+10000
S.capture(player);S.capture(player)
assert(not Safety.settled(S.capture(player)),'recovery clock restarts when evidence expires')
now=now+10000
zombies={}
assert(Safety.settled(S.capture(player)), 'empty lists are safely resolved immediately')
px=10
local safe=S.capture(player)
assert(Safety.clear(safe))
print('PASS crowd budget, near attacks, rotating far pursuit and safe recovery')
