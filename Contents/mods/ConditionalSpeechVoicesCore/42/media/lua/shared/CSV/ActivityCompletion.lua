local A={}
local call=require('CSV/Actors').call

local function craftGroup(recipe)
 local name=call(recipe,'getName')
 if name=='SawLogs' or name=='Base.SawLogs' then return 'SawLogsDone',nil,'Base.Plank' end
 local group,fullType=require('CSV/CraftOutputs').find(name)
 if group and call(call(recipe,'getModule'),'getName')=='Base' then return group,nil,fullType end
 local category=call(recipe,'getCategory')
 if category=='Tailoring' then return 'ClothingSewn','Clothing' end
 if category=='Cooking' then return 'MealPrepared','Food' end
end

local function outputs(logic)
 local result=ArrayList.new()
 logic:getCreatedOutputItems(result)
 return result
end

local function craftBefore(self,acceptGroup)
 local group,kind,fullType=craftGroup(self.craftRecipe)
 if not group or not acceptGroup(group) or not self.logic then return end
 local old=outputs(self.logic)
 local previous={}
 for i=0,old:size()-1 do previous[old:get(i):getID()]=true end
 return {group=group,kind=kind,fullType=fullType,previous=previous}
end

local function craftAfter(self,context)
 local made=outputs(self.logic)
 for i=0,made:size()-1 do
  local item=made:get(i)
  if not context.previous[item:getID()] then
   if (context.fullType and item:getFullType()==context.fullType) or (context.kind and instanceof(item,context.kind)) then
    return context.group
   end
  end
 end
end

local function harvestBefore(_,_,plant,player)
 local crops=farming_vegetableconf and farming_vegetableconf.props
 local crop=crops and plant and crops[plant.typeOfSeed]
 local produce=crop and crop.vegetableName
 if not produce then return end
 local inventory=player:getInventory()
 return {player=player,inventory=inventory,produce=produce,count=inventory:getItemCount(produce,true)}
end

local function harvestAfter(_,before)
 if before.inventory:getItemCount(before.produce,true)>before.count then return 'CropHarvested' end
end

local function catchBefore(self)
 if self.isFish and self.fishInInv==false then
  local inventory=self.character:getInventory()
  if not inventory:contains(self.item) then return inventory end
 end
end

local function catchAfter(self,inventory)
 if self.fishInInv and inventory:contains(self.item) then return 'FishCaught' end
end

local function install(name,loadAction,getAction,method,before,after,actor,notify,acceptGroup)
 require('CSV/Connections').install('activity.'..name,function(t)
  require(loadAction)
  local action=getAction()
  local original=action[method]
  local observe=require('CSV/Observers').run
  t:replace(action,method,function(self,...)
   local player=actor and actor(self,...) or self.character
   local context
   if not isClient() and player and call(player,'isDead')==false then
    local ok,value=observe('activity.'..name..'.before',before,self,acceptGroup,...)
    if ok then context=value end
   end
   local result=original(self,...)
   if context then
    observe('activity.'..name..'.confirmed',function()
     local group=after(self,context)
     if group and acceptGroup(group) then notify(player,group) end
    end)
   end
   return result
  end)
 end)
end

function A.install(notify,acceptGroup)
 acceptGroup=acceptGroup or function()return true end
 install('crop-harvest','Farming/SFarmingSystem',function()return SFarmingSystem end,'harvest',
  harvestBefore,harvestAfter,function(_,_,player)return player end,notify,acceptGroup)
 install('fish-caught','TimedActions/Fishing/TimedActions/ISPickupFishAction',function()return ISPickupFishAction end,'PickupFishUpdate',
  catchBefore,catchAfter,nil,notify,acceptGroup)
 install('craft','Entity/TimedActions/ISHandcraftAction',function()return ISHandcraftAction end,'performRecipe',
  craftBefore,craftAfter,nil,notify,acceptGroup)
end

return A
