local Adapter={}
local V=require 'CSV/Core'
local A=require 'CSV/Actors'
local H=require 'CSV/Connections'
local O=require 'CSV/Observers'
local function run(name,fn,...)return O.run('combat.'..name,fn,...)end
function Adapter.install(P)
 local Speech=require 'ConditionalSpeech_Core'
 local ok,err=H.install('combat-client',function(t)
  assert(type(Speech.check_ZombieKill)=='function','upstream kill callback unavailable')
  local observer=not isClient() and require('CSV/CombatEvidence').new(V.now,P.fact) or nil
  if observer then
   t:event(Events.OnWeaponHitCharacter,function(a,b)run('hit',observer.hit,observer,a,b)end)
   t:event(Events.OnZombieDead,function(b)
    local ok,claimed=run('vehicleDeath',require('CSV/VehicleCombat').death,b)
    if not (ok and claimed) then run('death',observer.death,observer,b,nil,false)end
   end)
   t:event(Events.OnCharacterDeath,function(b)
    local ok,claimed=run('vehicleDeath',require('CSV/VehicleCombat').death,b)
    if not (ok and claimed) then run('characterDeath',observer.death,observer,b,nil,false)end
   end)
  end
  t:event(Events.OnWeaponHitCharacter,function(a,b)run('outgoing',P.outgoing,a,b)end)
  t:event(Events.OnServerCommand,function(module,command,e)
   if module~='CSVCombat' or command~='fact' or type(e)~='table' or not ({zombieKill=true,humanKill=true,humanAttack=true})[e.kind] or not V.finite(e.eventId) then return end
   for i=0,getNumActivePlayers()-1 do local p=getSpecificPlayer(i);if A.call(p,'getOnlineID')==e.playerId then run('fact',P.fact,p,e)end end
  end)
  t:event(Events.OnFillWorldObjectContextMenu,function(...)run('menu',require('CSV/PeopleMenu').fill,P,...)end)
  t:removeEvent(Events.OnZombieDead,Speech.check_ZombieKill)
  P.observer=observer
 end)
 P.installed=ok;V.client.killObserverReady=ok
 if ok and P.observer then
  require('CSV/ALifeBridge').install(P.observer)
  if Events.ProjectALife_NpcDied then H.install('alife-client-death',function(t)
   t:event(Events.ProjectALife_NpcDied,function(body,uid,killer)run('alifeDeath',P.observer.death,P.observer,body,killer,true)end)
  end)end
 end
 return ok,err
end
return Adapter
