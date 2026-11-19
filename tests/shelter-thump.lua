local root='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=root..'shared/?.lua;'..root..'client/?.lua;'..package.path
local function square(x,y,z,building)
 local s={x=x,y=y,z=z,building=building,objects={}}
 function s:getX()return self.x end
 function s:getY()return self.y end
 function s:getZ()return self.z end
 function s:getBuilding()return self.building end
 function s:getSpecialObjects()return self.objects end
 return s
end
local function list(items)
 return {size=function()return #items end,get=function(_,i)return items[i+1]end}
end
local house={}
local inside=square(30,21,0,house)
local outside=square(30,20,0)
local up=square(30,21,1,house)
local second=square(32,21,0,house)
local tiles={['30:21:0']=inside,['30:20:0']=outside,['30:21:1']=up,['32:21:0']=second}
local cell={getGridSquare=function(_,x,y,z)return tiles[x..':'..y..':'..z]end}
function getCell()return cell end
function instanceof(o,kind)return o and o.kind==kind end
local function object(kind,s,north)
 return {kind=kind,getSquare=function()return s end,isNorth=function()return north end}
end
local door,window=object('IsoDoor',inside,true),object('IsoWindow',second,true)
local b=object('IsoBarricade',outside)
function b:getBarricadedObject()return door end
function door:getBarricadeForCharacter()return b end
inside.objects=list({door});outside.objects=list({b});second.objects=list({window})
local zombie={kind='IsoZombie',target=door,current=outside}
function zombie:getThumpTarget()return self.target end
function zombie:getCurrentSquare()return self.current end
local function player(id,s)
 return {getOnlineID=function()return id end,getCurrentSquare=function()return s end,
  isDead=function()return false end,isLocalPlayer=function()return true end}
end
local listener,spectator=player(8,inside),player(9,up)
local now=1000
package.loaded['CSV/Core']={config={enabled=true},now=function()return now end,voice=function()return 'fixture'end,
 clip=function(_,id)return id=='ShelterThump_3'end,extended=function()return true end,languageSupported=function()return true end}
local requests={}
package.loaded['CSV/Outcomes']={queue=function(e,g)requests[#requests+1]=e
 assert(require('CSV/OutcomeRules').classify(e)==g)
 assert(e.player==listener and e.verified)
end}
local function event()
 local e={callbacks={}}
 e.Add=function(f)e.callbacks[#e.callbacks+1]=f end
 e.Remove=function()end
 e.emit=function(...)for _,f in ipairs(e.callbacks)do f(...)end end
 return e
end
Events={OnWorldSound=event(),OnServerCommand=event()}
local server=false
local client=true
function isServer()return server end
function isClient()return client end
function getNumActivePlayers()return 2 end
function getSpecificPlayer(i)return i==0 and listener or spectator end
function getOnlinePlayers()return list({listener,spectator,player(10,outside)})end
local packets={}
function sendServerCommand(p,m,c,data)
 assert(p==listener and m=='CSV' and c=='shelterThump')
 packets[#packets+1]=data
end

require('CSV/ShelterThumpObserver').install()
local localSound=Events.OnWorldSound.emit
assert(#requests==0,'target acquisition is not an impact')
localSound(30,21,0,19,20,zombie)
localSound(30,21,0,20,20,player(6,outside))
assert(#requests==0)
-- A client can observe a locally simulated window strike in multiplayer.
zombie.target=window
localSound(32,21,0,20,20,zombie)
assert(#requests==1 and requests[1].x==32)
-- Game server receives the landed door hit with no client target.
Events.OnWorldSound=event();server=true;client=false
dofile(root..'server/CSV_ShelterThump.lua')
zombie.target=nil
Events.OnWorldSound.emit(30,21,0,20,20,zombie)
assert(#packets==1 and packets[1].x==30 and packets[1].north)
server=false;client=true
Events.OnServerCommand.emit('CSV','shelterThump',packets[1])
assert(#requests==2 and requests[2].x==30)
-- Barricade, another zombie and repeat packets share the original opening.
zombie.target=door
for i=1,6 do
 now=now+4000
 localSound(30,20,0,20,20,zombie)
 Events.OnServerCommand.emit('CSV','shelterThump',packets[1])
end
assert(#requests==2,'ongoing hits should never start another reaction')
now=now+12000
localSound(30,21,0,20,20,zombie)
assert(#requests==3)
local slots={}
for _,id in ipairs(require('CSV/VoicePresentation').optionalSlots)do slots[id]=true end
for i=1,3 do assert(slots['ShelterThump_'..i],'alternate must be optional')end
for name in pairs(require('CSV/VoiceCoverage').pools)do
 assert(not name:find('ShelterThump',1,true),'Shelter Thump must not be required for pack coverage')
end
local policy=require('CSV/Delivery')
assert(policy.decide('ShelterThump',1,{sneaking=false,outcome=requests[1]}).reason=='confirmed_shelter_thump')
assert(policy.decide('ShelterThump',1,{sneaking=true,outcome=requests[1]}).mode=='silent')
print('PASS ShelterThump landed-only event, multiplayer routing, barricade deduplication and optional variants')
