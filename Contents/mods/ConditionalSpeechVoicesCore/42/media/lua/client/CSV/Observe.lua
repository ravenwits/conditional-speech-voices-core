local O={}
local S=require 'CSV/State'
local function report(player,event,group)
 if not player or not player:isLocalPlayer() or player:isDead() then return end
 local now=getTimestampMs();local e=S.events[player] or {}
 if e[event] and now-e[event]<3000 then return end
 S.record(player,event)
 local speech=require 'ConditionalSpeech_Core'
 if not speech.isPanicking(player) then speech.generateSpeechFrom(player,group,1,1,false,false) end
end
function O.transfer(self,item)
 local p=self.character;local src,dst=self.srcContainer,self.destContainer
 if p and src and dst and item and src~=dst and not src:isInCharacterInventory(p)
  and dst:isInCharacterInventory(p) and item:getContainer()==dst and dst:contains(item) then
  if not p:isLocalPlayer() or p:isDead() then return end
  local V=require 'CSV/Core'
  if V.config.enabled and V.extended(V.voice(p)) then S.record(p,'pickup');require('CSV/Loot').received(p,item)
  else report(p,'pickup','FoundLoot') end
 end
end
function O.tree(self,wasStanding)
 if wasStanding and self.tree and self.tree:getObjectIndex()<0 then report(self.character,'treeDown','ChopTree') end
end
function O.install()
 if O.installed then return true end
 local first=require('CSV/Connections').install('inventory-observer',function(t)
  require 'TimedActions/ISInventoryTransferAction'
  local original=ISInventoryTransferAction.playTransferCompleteSound
  t:replace(ISInventoryTransferAction,'playTransferCompleteSound',function(self,item,...)
   local result={original(self,item,...)}
   local good,err=pcall(O.transfer,self,item);if not good and not O.transferError then O.transferError=true;print('[CSV] transfer observer: '..tostring(err)) end
   return unpack(result)
  end)
 end)
 local second=require('CSV/Connections').install('tree-observer',function(t)
  require 'TimedActions/ISChopTreeAction'
  local original=ISChopTreeAction.animEvent
  t:replace(ISChopTreeAction,'animEvent',function(self,event,...)
   local valid,standing=pcall(function()return event=='ChopTree' and not isClient() and self.axe~=nil and self.tree:getObjectIndex()>=0 end)
   local result={original(self,event,...)}
   if valid and standing then local good,err=pcall(O.tree,self,true)
    if not good and not O.treeError then O.treeError=true;print('[CSV] tree observer: '..tostring(err)) end
   end
   return unpack(result)
  end)
 end)
 O.installed=first and second
 return O.installed
end
return O
