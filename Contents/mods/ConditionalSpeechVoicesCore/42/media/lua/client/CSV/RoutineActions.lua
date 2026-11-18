local A={}
local V=require 'CSV/Core'
local call=require('CSV/Actors').call

local function queue(p,group,action,skillBook)
 if not p or not p:isLocalPlayer() or p:isDead() or not V.config.enabled then return false end
 local voice=V.voice(p)
 if not voice or not V.extended(voice) or not V.languageSupported() then return false end
 local available=V.clip(voice,group..'_1')
 if not available and group=='SawLogsDone' then available=V.clip(voice,'ChopTree_1') end
 if not available and group=='BookReading' and skillBook then
  available=V.clip(voice,'TraitStudy_1') or V.clip(voice,'TraitStudy_2')
 end
 if not available then return false end
 return require('CSV/Outcomes').queue({kind='routine',routineGroup=group,verified=true,completed=true,
  player=p,obj=p,actionObject=action,skillBook=skillBook},group)
end

function A.read(p,action)
 local book=action.item
 local pages=call(book,'getAlreadyReadPages')
 local total=call(book,'getNumberOfPages')
 if type(total)~='number' or total<=0 or type(pages)~='number'
  or type(action.startPage)~='number' or pages<=action.startPage then return false end
 local skill=call(book,'getSkillTrained')
 return queue(p,'BookReading',action,SkillBook and SkillBook[skill]~=nil)
end

local function craftGroup(recipe)
 local name=call(recipe,'getName')
 if name=='SawLogs' or name=='Base.SawLogs' then return 'SawLogsDone','Plank' end
 local category=call(recipe,'getCategory')
 if category=='Tailoring' then return 'ClothingSewn','Clothing' end
 if category=='Cooking' then return 'MealPrepared','Food' end
end

local function outputs(logic)
 local result=ArrayList.new()
 logic:getCreatedOutputItems(result)
 return result
end

local function craftBefore(self)
 local group,kind=craftGroup(self.craftRecipe)
 if not group or not self.logic then return end
 local old=outputs(self.logic)
 local previous={}
 for i=0,old:size()-1 do previous[old:get(i):getID()]=true end
 return {group=group,kind=kind,previous=previous}
end

local function craftAfter(self,context)
 local made=outputs(self.logic)
 for i=0,made:size()-1 do
  local item=made:get(i)
  if not context.previous[item:getID()] and
   (context.kind=='Plank' and item:getFullType()=='Base.Plank' or context.kind~='Plank' and instanceof(item,context.kind)) then
   return queue(self.character,context.group)
  end
 end
end

local function smokeBefore(self)
 local item=self.item
 if item and ItemTag.SMOKABLE and item:hasTag(ItemTag.SMOKABLE) then
  return {item=item,container=item:getContainer(),uses=call(item,'getCurrentUsesFloat')}
 end
end

local function smokeAfter(self,before,succeeded)
 if succeeded~=true then return end
 local item=before.item
 local uses=call(item,'getCurrentUsesFloat')
 if before.container and not before.container:contains(item) or
  type(uses)=='number' and type(before.uses)=='number' and uses<before.uses then
  return queue(self.character,'SmokeFinished')
 end
end

local function foodBefore(self)
 return self.baseItem and self.usedItem and instanceof(self.baseItem,'Food')
  and instanceof(self.usedItem,'Food') and self.recipe:getAddIngredientSound()~='AddItemInBeverage'
end

local function install(name,loadAction,getAction,method,before,after)
 return require('CSV/Connections').install('routine.'..name,function(t)
  require(loadAction)
  local action=getAction()
  local original=action[method]
  local observe=require('CSV/Observers').run
  t:replace(action,method,function(self,...)
   local p=self.character
   local context
   if not isClient() and not isServer() and p and p:isLocalPlayer() and not p:isDead() and V.config.enabled then
    local ok,value=observe('routine.'..name..'.before',before,self)
    if ok then context=value end
   end
   local result=original(self,...)
   if context then observe('routine.'..name..'.after',after,self,context,result) end
   return result
  end)
 end)
end

local function campfire(self)
 local loc=self.campfire
 local system=SCampfireSystem and SCampfireSystem.instance
 if loc and system then return system:getLuaObjectAt(loc.x,loc.y,loc.z) end
end

local function fireBefore(self)
 local fire=campfire(self)
 return fire and fire.isLit==false
end

local function fireAfter(self)
 local fire=campfire(self)
 if fire and fire.isLit==true then queue(self.character,'CampfireLit') end
end

function A.install()
 install('generator-start','TimedActions/ISActivateGenerator',function()return ISActivateGenerator end,'complete',
  function(self)return self.activate==true and call(self.generator,'isActivated')==false end,
  function(self,_,success)
   if success==true and call(self.generator,'isActivated')==true then queue(self.character,'GeneratorStarted') end
  end)
 install('generator-repair','TimedActions/ISFixGenerator',function()return ISFixGenerator end,'complete',
  function(self)return call(self.generator,'getCondition') end,
  function(self,condition,success)
   local after=call(self.generator,'getCondition')
   if success==true and type(after)=='number' and after>condition then queue(self.character,'GeneratorRepaired') end
  end)
 install('campfire-kindling','Camping/TimedActions/ISLightFromKindle',function()return ISLightFromKindle end,'updateKindling',fireBefore,fireAfter)
 install('campfire-literature','Camping/TimedActions/ISLightFromLiterature',function()return ISLightFromLiterature end,'complete',fireBefore,fireAfter)
 install('campfire-petrol','Camping/TimedActions/ISLightFromPetrol',function()return ISLightFromPetrol end,'complete',fireBefore,fireAfter)
 -- complete runs on the server in MP. Do not speak for speculative client actions.
 install('craft','Entity/TimedActions/ISHandcraftAction',function()return ISHandcraftAction end,'performRecipe',craftBefore,craftAfter)
 install('patch','TimedActions/ISRepairClothing',function()return ISRepairClothing end,'complete',function()return true end,
  function(self,_,success)if success==true then queue(self.character,'ClothingPatched')end end)
 install('smoke','TimedActions/ISEatFoodAction',function()return ISEatFoodAction end,'complete',smokeBefore,smokeAfter)
 install('food','TimedActions/ISAddItemInRecipe',function()return ISAddItemInRecipe end,'complete',foodBefore,
  function(self,_,success)if success==true and self.baseItem and instanceof(self.baseItem,'Food') then queue(self.character,'MealPrepared')end end)
end

return A
