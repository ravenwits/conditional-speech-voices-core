local A={}
local V=require 'CSV/Core'
local call=require('CSV/Actors').call

local function queue(p,group,action,skillBook)
 if not p or not p:isLocalPlayer() or p:isDead() or not V.config.enabled then return false end
 local voice=V.voice(p)
 if not voice or not V.extended(voice) or not V.languageSupported() then return false end
 local source=group..'_1'
 local traits=require 'CSV/TraitSpeechRules'
 local available=not traits.specialistRoutines[group] and V.clip(voice,source)
 if not available then available=traits.preferredRecording(V,p,voice,source,{},{},nil) end
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
    local ok,value=observe('routine.'..name..'.before',before,self,...)
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

local received=setmetatable({},{__mode='k'})
local function receive(module,command,event)
 if module~='CSVActivities' or command~='completed' or type(event)~='table' then return end
 if not require('CSV/TraitSpeechRules').specialistRoutines[event.group] then return end
 local playerId,sequence=event.playerId,event.sequence
 if not V.finite(playerId) or playerId<0 or playerId%1~=0
  or not V.finite(sequence) or sequence<1 or sequence%1~=0 then return end
 for i=0,getNumActivePlayers()-1 do
  local player=getSpecificPlayer(i)
  if call(player,'isLocalPlayer')==true and call(player,'getOnlineID')==playerId then
   if sequence<=(received[player] or 0) then return end
   received[player]=sequence
   return queue(player,event.group)
  end
 end
end

function A.install()
 if isClient() then
  require('CSV/Connections').install('activity-client',function(t)
   t:event(Events.OnServerCommand,receive)
   t:event(Events.OnConnected,function()received=setmetatable({},{__mode='k'})end)
  end)
 elseif not isServer() then
  require('CSV/ActivityCompletion').install(queue)
 end
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
 install('patch','TimedActions/ISRepairClothing',function()return ISRepairClothing end,'complete',function()return true end,
  function(self,_,success)if success==true then queue(self.character,'ClothingPatched')end end)
 install('smoke','TimedActions/ISEatFoodAction',function()return ISEatFoodAction end,'complete',smokeBefore,smokeAfter)
 install('food','TimedActions/ISAddItemInRecipe',function()return ISAddItemInRecipe end,'complete',foodBefore,
  function(self,_,success)if success==true and self.baseItem and instanceof(self.baseItem,'Food') then queue(self.character,'MealPrepared')end end)
end

return A
