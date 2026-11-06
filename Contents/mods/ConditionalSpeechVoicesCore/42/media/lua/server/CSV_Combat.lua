if not isServer() then return end
local H=require 'CSV/Connections'
local O=require 'CSV/Observers'
local observer=require('CSV/CombatEvidence').new(getTimestampMs,function(player,event)
 event.playerId=player:getOnlineID();sendServerCommand(player,'CSVCombat','fact',event)
end)
local function safe(name,fn,...)return O.run('server.'..name,fn,...)end
local function optional()
 require('CSV/ALifeBridge').install(observer)
 if Events.ProjectALife_NpcDied then H.install('alife-server-death',function(t)
  t:event(Events.ProjectALife_NpcDied,function(body,uid,killer)safe('alifeDeath',observer.death,observer,body,killer,true)end)
 end)end
end
H.install('combat-server',function(t)
 t:event(Events.OnWeaponHitCharacter,function(a,b)safe('hit',observer.hit,observer,a,b)end)
 t:event(Events.OnZombieDead,function(body)safe('death',observer.death,observer,body,nil,false)end)
 t:event(Events.OnCharacterDeath,function(body)safe('characterDeath',observer.death,observer,body,nil,false)end)
 t:event(Events.OnTick,function()safe('settle',observer.settle,observer)end)
 t:event(Events.OnGameStart,optional)
 if Events.OnServerStarted then t:event(Events.OnServerStarted,optional)end
end)
optional()
