local A=require 'CSV/Actors'
local M={}
-- Native hit callbacks run before damage settles. Only a later death is a kill.
function M.new(now,deliver)
 local o={hits=setmetatable({},{__mode='k'}),dead=setmetatable({},{__mode='k'}),ids={},serial=0}
 function o:attack(victim,attacker)
  if A.kind(victim)~='player' or A.call(victim,'isDead')~=false then return end
  require('CSV/Concealment').record(victim,attacker)
  self.serial=self.serial+1
  deliver(victim,{kind='humanAttack',actorKind=A.kind(attacker),eventId=self.serial,attackerKey=A.key(attacker)},attacker)
 end
 function o:hit(attacker,target)
  if not attacker or not target or attacker==target then return end
  local kind=A.kind(target)
  if kind=='unknown' then return end
  self.hits[target]={attacker=attacker,at=now(),health=A.call(target,'getHealth')}
 end
 function o:death(target,killer,npcEvent)
  local kind=A.kind(target)
  if kind=='unknown' or (kind=='npc' and not npcEvent) or (kind~='npc' and npcEvent) then return false end
  if A.call(target,'isDead')~=true then return false end
  local key=kind=='npc' and A.key(target) or nil
  if self.dead[target] or key and self.ids[key] then return false end
  local hit=self.hits[target]
  if npcEvent then
   -- The A-Life lifecycle resolves its own attribution, including bleeding out.
   if A.kind(killer)~='player' then return false end
  else
   killer=A.call(target,'getAttackedBy')
   if not hit or now()-hit.at>120000 or hit.attacker~=killer or A.kind(killer)~='player' then return false end
  end
  self.dead[target]=true
  if key then self.ids[key]=now() end
  for k,t in pairs(self.ids)do if now()-t>600000 then self.ids[k]=nil end end
  self.serial=self.serial+1
  deliver(killer,{kind=kind=='zombie' and 'zombieKill' or 'humanKill',actorKind=kind,eventId=self.serial,observed=A.call(killer,'CanSee',target)==true})
  return true
 end
 function o:settle()
  for target,hit in pairs(self.hits)do
   if not hit.notified and now()-hit.at>=100 then
    hit.notified=true
    local health=A.call(target,'getHealth')
    if A.kind(target)=='player' and A.call(target,'isDead')==false and type(health)=='number' and type(hit.health)=='number' and health<hit.health then
     local kind=A.kind(hit.attacker)
     if kind=='player' or kind=='npc' then
      self:attack(target,hit.attacker)
     end
    end
   end
   if now()-hit.at>120000 then self.hits[target]=nil end
  end
 end
 return o
end
return M
