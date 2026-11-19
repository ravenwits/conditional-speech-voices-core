local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local localPlayer={isLocalPlayer=function()return true end,isDead=function()return false end}
local requests={}
local known={SawLogsDone_1=true,TraitStudy_2=true,ClothingPatched_1=true,ClothingSewn_1=true,SmokeFinished_1=true}
local rules=require('CSV/OutcomeRules')
package.loaded['CSV/Core']={config={enabled=true},voice=function()return 'test' end,
 extended=function()return true end,languageSupported=function()return true end,
 clip=function(_,id)return known[id] end}
package.loaded['CSV/Outcomes']={queue=function(event,group)
 assert(rules.classify(event)==group)
 requests[#requests+1]=event;return true
end}
local multiplayer=false
function isClient()return multiplayer end
function isServer()return false end
function getTimestampMs()return 0 end
function instanceof(item,kind)return item.kind==kind end
ItemTag={SMOKABLE='smokable'}
ArrayList={new=function()return {size=function(self)return #self end,get=function(self,i)return self[i+1] end}end}
local function item(id,kind,fullType)
 return {kind=kind,getID=function()return id end,getFullType=function()return fullType end}
end
local old=item(1,'Item','Base.Plank')
local made=item(2,'Item','Base.Plank')
local current=old
local logic={getCreatedOutputItems=function(_,array)array[1]=current end}
ISHandcraftAction={performRecipe=function(self)if self.succeeds then current=made end end}
ISRepairClothing={complete=function(self)return self.succeeds end}
ISEatFoodAction={complete=function(self)if self.succeeds then self.item.present=false end;return true end}
ISAddItemInRecipe={complete=function(self)return self.succeeds end}
for _,module in ipairs({'Entity/TimedActions/ISHandcraftAction','TimedActions/ISRepairClothing',
 'TimedActions/ISEatFoodAction','TimedActions/ISAddItemInRecipe'}) do package.loaded[module]=true end
local r=require('CSV/RoutineActions')
r.install();r.install()
local saw=setmetatable({character=localPlayer,logic=logic,craftRecipe={getName=function()return 'SawLogs' end}},{__index=ISHandcraftAction})
assert(saw:performRecipe()==nil and #requests==0)
saw.succeeds=true;saw:performRecipe()
assert(#requests==1 and requests[1].routineGroup=='SawLogsDone')
saw:performRecipe()
assert(#requests==1,'duplicate completion or stale output')
assert(not ISRepairClothing.complete({character=localPlayer,succeeds=false}) and #requests==1)
assert(ISRepairClothing.complete({character=localPlayer,succeeds=true}) and #requests==2)
multiplayer=true
assert(ISRepairClothing.complete({character=localPlayer,succeeds=true}) and #requests==2)
multiplayer=false
local cigarette={present=true,hasTag=function(_,tag)return tag=='smokable' end}
cigarette.getContainer=function()return {contains=function(_,it)return it.present end}end
ISEatFoodAction.complete({character=localPlayer,item=cigarette})
assert(#requests==2,'unconsumed cigarette must not speak')
ISEatFoodAction.complete({character=localPlayer,item=cigarette,succeeds=true})
assert(#requests==3 and requests[3].routineGroup=='SmokeFinished')
local food={kind='Food'}
local cook={character=localPlayer,baseItem=food,usedItem=food,succeeds=true,
 recipe={getAddIngredientSound=function()return 'AddItemInRecipe' end}}
ISAddItemInRecipe.complete(cook)
assert(#requests==3,'pack without optional audio stays silent')
known.MealPrepared_1=true
ISAddItemInRecipe.complete(cook)
assert(#requests==4 and requests[4].routineGroup=='MealPrepared')
local pages=3
SkillBook={Woodwork={}}
local read={startPage=3,item={getAlreadyReadPages=function()return pages end,
 getNumberOfPages=function()return 200 end,getSkillTrained=function()return 'Woodwork' end}}
assert(not r.read(localPlayer,read))
pages=4
assert(r.read(localPlayer,read) and requests[5].actionObject==read and requests[5].skillBook)
local longStick={getName=function()return 'SawLongStick' end,getCategory=function()return 'Carpentry' end}
current=old;saw.craftRecipe=longStick;saw:performRecipe()
assert(#requests==5,'shared saw animation must not count as SawLogs')
current=old;made=item(3,'Clothing','Base.Shirt')
saw.craftRecipe={getName=function()return 'SewShirt' end,getCategory=function()return 'Tailoring' end}
saw:performRecipe()
assert(#requests==6 and requests[6].routineGroup=='ClothingSewn')
assert(not rules.classify({kind='routine',routineGroup='WeaponBroken',completed=true,verified=true}))
local generator={on=false,condition=20}
function generator:isActivated() return self.on end
function generator:getCondition() return self.condition end
ISActivateGenerator={complete=function(self) if self.succeeds then generator.on=self.activate end;return true end}
ISFixGenerator={complete=function(self) if self.succeeds then generator.condition=40 end;return true end}
local fire={isLit=false}
SCampfireSystem={instance={getLuaObjectAt=function()return fire end}}
ISLightFromKindle={updateKindling=function(self) if self.succeeds then fire.isLit=true end end}
ISLightFromLiterature={complete=function()return true end}
ISLightFromPetrol={complete=function()fire.isLit=true;return true end}
for _,name in ipairs({'TimedActions/ISActivateGenerator','TimedActions/ISFixGenerator',
 'Camping/TimedActions/ISLightFromKindle','Camping/TimedActions/ISLightFromLiterature','Camping/TimedActions/ISLightFromPetrol'}) do
 package.loaded[name]=true
end
known.GeneratorStarted_1=true;known.GeneratorRepaired_1=true;known.CampfireLit_1=true
r.install()
local action={character=localPlayer,generator=generator,activate=true,campfire={x=1,y=2,z=0}}
ISActivateGenerator.complete(action);ISFixGenerator.complete(action);ISLightFromKindle.updateKindling(action)
assert(#requests==6,'failed start, unchanged condition and unlit fire do not speak')
action.succeeds=true
ISActivateGenerator.complete(action);ISFixGenerator.complete(action);ISLightFromKindle.updateKindling(action)
assert(#requests==9 and requests[7].routineGroup=='GeneratorStarted' and requests[8].routineGroup=='GeneratorRepaired' and requests[9].routineGroup=='CampfireLit')
ISLightFromPetrol.complete(action)
assert(#requests==9,'already lit')
fire.isLit=false;ISLightFromPetrol.complete(action)
assert(#requests==10 and requests[10].routineGroup=='CampfireLit')
-- Crop and rod catches are optional lines for the corresponding trait. Check the
-- actual item transfer, including repeated ticks and unsuccessful harvests.
local actorTraits={}
CharacterTrait={GARDENER='Gardener',FISHING='Angler'}
function localPlayer:hasTrait(key)return actorTraits[key]==true end
local core=package.loaded['CSV/Core']
core.now=function()return 10 end
core.localize=function(_,line)return line end
local inventory={counts={},items={}}
function inventory:getItemCount(name)return self.counts[name] or 0 end
function inventory:contains(it)return self.items[it]==true end
function localPlayer:getInventory()return inventory end
farming_vegetableconf={props={Cabbage={vegetableName='Base.Cabbage'}}}
SFarmingSystem={harvest=function(_,plant,p)
 if plant.gain then
  local inv=p:getInventory()
  inv.counts[plant.gain]=inv:getItemCount(plant.gain)+1
 end
end}
ISPickupFishAction={PickupFishUpdate=function(self)
 if self:getJobDelta()>=self.finishShowModel and not self.fishInInv then
  self.fishInInv=true
  if self.store then inventory.items[self.item]=true end
 end
end}
package.loaded['Farming/SFarmingSystem']=true
package.loaded['TimedActions/Fishing/TimedActions/ISPickupFishAction']=true
r.install();r.install()
local baseline=#requests
local crop={typeOfSeed='Cabbage',gain='Base.Cabbage'}
local function harvest()return SFarmingSystem:harvest(crop,localPlayer) end
actorTraits.Gardener=true
harvest()
assert(#requests==baseline,'old pack has no harvest line')
known.CropHarvested_1=true;actorTraits.Gardener=false
harvest()
assert(#requests==baseline,'ordinary harvest must stay silent even with the recording')
actorTraits.Gardener=true;crop.gain='Base.CabbageSeed'
harvest()
assert(#requests==baseline,'seeds alone are not harvested produce')
crop.gain=nil
harvest()
assert(#requests==baseline,'failed crop action')
crop.gain='Base.Cabbage';multiplayer=true
harvest()
multiplayer=false
assert(#requests==baseline,'client action alone cannot confirm a yield')
harvest()
assert(#requests==baseline+1 and requests[#requests].routineGroup=='CropHarvested')
baseline=#requests
local function rodPickup(fish,store)
 return setmetatable({character=localPlayer,item={},isFish=fish,fishInInv=false,finishShowModel=.8,
  delta=.9,getJobDelta=function(self)return self.delta end,store=store},{__index=ISPickupFishAction})
end
actorTraits.Angler=true
rodPickup(true,true):PickupFishUpdate()
assert(#requests==baseline,'old pack has no catch line')
known.FishCaught_1=true;actorTraits.Angler=false
rodPickup(true,true):PickupFishUpdate()
assert(#requests==baseline,'angler only')
actorTraits.Angler=true
rodPickup(false,true):PickupFishUpdate()
rodPickup(true,false):PickupFishUpdate()
assert(#requests==baseline,'trash and fish outside inventory must not speak')
local caught=rodPickup(true,true)
caught.delta=.2;caught:PickupFishUpdate()
assert(#requests==baseline,'hooked fish still outside the inventory')
caught.delta=.9;caught:PickupFishUpdate();caught:PickupFishUpdate()
assert(#requests==baseline+1 and requests[#requests].routineGroup=='FishCaught','one reaction per landed fish')
multiplayer=true;rodPickup(true,true):PickupFishUpdate();multiplayer=false
assert(#requests==baseline+1,'predicted multiplayer pickup')

print('PASS verified routine actions, silent missing takes, failed completions and reading progress')

do
 local crafts={
  {'MakeGlassJar','Base.JarCrafted','TraitGlasswork','ARTISAN'},
  {'Forge_Hinge','Base.Hinge','TraitForgeWork','BLACKSMITH'},
  {'Forge_Tongs','Base.Tongs','TraitForgeWork','BLACKSMITH2'},
  {'Make_Stone_Block_from_Stone','Base.StoneBlock','TraitMasonry','MASON'},
  {'CarveWoodenSpoon','Base.WoodenSpoon','TraitWhittling','WHITTLER'},
 }
 local sourceModule='Base'
 local scriptModule={getName=function()return sourceModule end}
 for _,case in ipairs(crafts)do
  local recipe,output,group,trait=unpack(case)
  local id=group..'_1'
  local originalCount=#requests
  CharacterTrait[trait]=trait
  saw.craftRecipe={getName=function()return recipe end,getModule=function()return scriptModule end}
  local function complete(typeName,success)
   current=old
   made=item(4,'Item',typeName)
   saw.succeeds=success
   saw:performRecipe()
  end
  known[id]=nil;actorTraits[trait]=true;complete(output,true)
  known[id]=true;actorTraits[trait]=false;complete(output,true)
  actorTraits[trait]=true;complete(output,false)
  complete('Base.Plank',true)
  sourceModule='OtherMod';complete(output,true);sourceModule='Base'
  multiplayer=true;complete(output,true);multiplayer=false
  assert(#requests==originalCount,'Unverified or ineligible specialist craft: '..recipe)
  complete(output,true)
  saw:performRecipe()
  assert(#requests==originalCount+1 and requests[#requests].routineGroup==group,recipe)
  assert(not requests[#requests].actionObject,'Completed craft can end before playback')
  actorTraits[trait]=nil
 end
end
print('PASS specialist handcraft needs the recorded trait, Base recipe and new matching item')

-- Simulate a dedicated server with two players sharing one receiving client.
local H=require 'CSV/Connections'
for _,name in ipairs({'crop-harvest','fish-caught','craft'})do H.remove('activity.'..name) end
local server=true
function isServer()return server end
function localPlayer:getOnlineID()return 7 end
local otherPlayer={getOnlineID=function()return 8 end,isLocalPlayer=function()return true end,
 isDead=localPlayer.isDead,getInventory=localPlayer.getInventory,hasTrait=localPlayer.hasTrait}
function getNumActivePlayers()return 2 end
function getSpecificPlayer(i)return i==0 and localPlayer or otherPlayer end
local packets={}
function sendServerCommand(target,module,command,event)
 assert(server and event.playerId==target:getOnlineID())
 packets[#packets+1]={target,module,command,event}
end
local function event()
 return {Add=function(handler)return handler end,Remove=function()end}
end
Events={OnConnected=event(),OnServerCommand=event()}
local receive
Events.OnServerCommand.Add=function(handler)receive=handler end
local function receivePacket(packet) return receive(packet[2],packet[3],packet[4]) end
local beforeNetwork=#requests
local root='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
dofile(root..'server/CSV_Activities.lua')
crop.gain='Base.Cabbage';SFarmingSystem:harvest(crop,otherPlayer)
local netFish=rodPickup(true,true)
netFish:PickupFishUpdate();netFish:PickupFishUpdate()
rodPickup(false,true):PickupFishUpdate();rodPickup(true,false):PickupFishUpdate()
local networkCrafts={
 {'MakeGlassJar','Base.JarCrafted','TraitGlasswork','ARTISAN'},
 {'Forge_Hinge','Base.Hinge','TraitForgeWork','BLACKSMITH'},
 {'Make_Stone_Block_from_Stone','Base.StoneBlock','TraitMasonry','MASON'},
 {'CarveWoodenSpoon','Base.WoodenSpoon','TraitWhittling','WHITTLER'},
}
for _,craft in ipairs(networkCrafts)do
 local recipe,output,group,trait=unpack(craft)
 saw.character=otherPlayer
 saw.craftRecipe={getName=function()return recipe end,getModule=function()return {getName=function()return 'Base' end}end}
 made=item(4,'Item',output);current=old;saw.succeeds=false;saw:performRecipe()
 saw.succeeds=true;saw:performRecipe();saw:performRecipe()
 actorTraits[trait]=true;known[group..'_1']=true
end
assert(#packets==6 and #requests==beforeNetwork,'server confirms exactly six outputs without local playback')
assert(packets[1][1]==otherPlayer and packets[2][1]==localPlayer)
for i,craft in ipairs(networkCrafts)do
 assert(packets[i+2][1]==otherPlayer and packets[i+2][4].group==craft[3])
end

server=false;multiplayer=true
core.finite=function(n)return type(n)=='number' and n>-math.huge and n<math.huge end
r.install()
assert(receive,'activity client registered')
rodPickup(true,true):PickupFishUpdate()
assert(#packets==6 and #requests==beforeNetwork,'local pickup prediction cannot start speech')
for i,packet in ipairs(packets)do
 receivePacket(packet);receivePacket(packet)
 assert(#requests==beforeNetwork+i and requests[#requests].player==packet[1])
end
receive('CSVActivities','completed',{playerId=50,sequence=80,group='CropHarvested'})
receive('CSVActivities','completed',{playerId=7,sequence=81,group='CampfireLit'})
receive('CSVActivities','completed',{playerId=7,sequence='82',group='CropHarvested'})
assert(#requests==beforeNetwork+6,'foreign actor, invalid group, or invalid sequence')
actorTraits.Gardener=false
receive('CSVActivities','completed',{playerId=7,sequence=83,group='CropHarvested'})
actorTraits.Gardener=true;known.FishCaught_1=false
receive('CSVActivities','completed',{playerId=7,sequence=84,group='FishCaught'})
assert(#requests==beforeNetwork+6,'server confirmation still needs the trait and its recorded audio')
print('PASS dedicated server output checks and actor-only multiplayer delivery')
