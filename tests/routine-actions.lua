local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local localPlayer={isLocalPlayer=function()return true end,isDead=function()return false end}
local requests={}
local known={ChopTree_1=true,TraitStudy_2=true,ClothingPatched_1=true,ClothingSewn_1=true,SmokeFinished_1=true}
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
print('PASS verified routine actions, silent missing takes, failed completions and reading progress')
