local Actors=require 'CSV/Actors'
local Concealment=require 'CSV/Concealment'
local S={events=setmetatable({},{__mode='k'}),motion=setmetatable({},{__mode='k'}),threatClock=setmetatable({},{__mode='k'})}
local function read(fn)
 return require('CSV/ApiDiagnostics').read('State.read',fn)
end
S.metrics={captures=0,reads=0,hits=0,visits=0,readMs=0,maxReadMs=0}
function S.beginFrame()S.frame=setmetatable({},{__mode='k'})end
function S.endFrame()S.frame=nil end
function S.invalidate(player)if S.frame then S.frame[player]=nil end end
function S.record(player,event)
 S.invalidate(player)
 local e=S.events[player] or {};S.events[player]=e;e[event]=getTimestampMs()
end
local function collect(player)
 S.metrics.reads=S.metrics.reads+1
 local s={visiblePeople={},concealmentRisk=0,whisperRisk=0,exposedZombie=0,exposedNpc=0,exposedPlayer=0,directAttack=0,activePursuit=0}
 if not player then return s end
 local square=Actors.call(player,'getSquare')
 local stats=Actors.call(player,'getStats')
 local moodles=Actors.call(player,'getMoodles')
 local body=Actors.call(player,'getBodyDamage')
 s.sneaking=Actors.call(player,'isSneaking')
 s.fire=Actors.call(player,'isOnFire')
 s.visible=Actors.call(stats,'getNumVisibleZombies')
 s.engineLastSeen=Actors.call(player,'getLastSeenZomboidTime')
 s.traits=require('CSV/Traits').read(player)
 s.outside=Actors.call(square,'isOutside')
 s.nicotineStress=Actors.call(stats,'getNicotineStress')
 s.levels={}
 for group in pairs(require('CSV/NeedTiming').seconds)do
  local aliases={HeavyLoad='HEAVY_LOAD',HasACold='HAS_A_COLD',CantSprint='CANT_SPRINT',NoxiousSmell='NOXIOUS_SMELL'}
  local mt=MoodleType[aliases[group] or group:upper()]
  if mt then s.levels[group]=Actors.call(moodles,'getMoodleLevel',mt)end
 end
 s.panic=Actors.call(moodles,'getMoodleLevel',MoodleType.PANIC)
 s.endurance=Actors.call(moodles,'getMoodleLevel',MoodleType.ENDURANCE)
 s.thirst=Actors.call(moodles,'getMoodleLevel',MoodleType.THIRST)
 for _,rule in pairs(require('CSV/RecoveryRules'))do
  if s[rule.field]==nil then s[rule.field]=s.levels[rule.source] end
 end
 s.health=Actors.call(body,'getOverallBodyHealth')
 s.zombieKills=Actors.call(player,'getZombieKills')
 s.cold=Actors.call(moodles,'getMoodleLevel',MoodleType.HYPOTHERMIA)
 local weapon=Actors.call(player,'getPrimaryHandItem')
 if Actors.call(weapon,'isRanged')==true then
  s.jammed=Actors.call(weapon,'isJammed')
  s.rounds=Actors.call(weapon,'getCurrentAmmoCount');s.hasChamber=Actors.call(weapon,'haveChamber')
  if s.hasChamber==true then s.chamber=Actors.call(weapon,'isRoundChambered')
  elseif s.hasChamber==false then s.chamber=false end
  if type(s.rounds)=='number' and type(s.chamber)=='boolean' then s.empty=s.rounds==0 and not s.chamber end
 elseif weapon or player.getPrimaryHandItem then s.jammed=false end
 read(function()
  local parts=Actors.call(body,'getBodyParts');if not parts then return end;local bandages,dirty,bleeding=0,0,0
  for i=0,parts:size()-1 do local p=parts:get(i)
   if p:bandaged() then bandages=bandages+1;if p:getBandageLife()<=0 then dirty=dirty+1 end end
   if p:bleeding() then bleeding=bleeding+1 end
  end
  s.bandages=bandages;s.dirty=dirty;s.bleeding=bleeding
 end)
 read(function()
  if player.getSquare and not square then return end
  local cell=getCell and getCell();local list=Actors.call(cell,'getZombieList');if not list then return end;local near,crowd,accessible,blocked,targeted,approaching=0,0,0,0,0,0
  local motion=S.motion[player] or setmetatable({},{__mode='k'});S.motion[player]=motion
  local now=getTimestampMs();local targetKnown=true;local movingKnown=false
  local npcVisible,zombieVisible=0,0;local reactive,attacking,reactiveCrowd=0,0,0;local reactiveKnown=true;local attackKnown=true;local encounter=false
  local size=list:size()
  local px,py,pz=0,0,0
  if size>0 then
   px,py,pz=Actors.call(player,'getX'),Actors.call(player,'getY'),Actors.call(player,'getZ')
   if type(px)~='number' or type(py)~='number' or type(pz)~='number' then return end
  end
  for i=0,size-1 do local z=list:get(i);S.metrics.visits=S.metrics.visits+1
   local present=z and not z:isDead() and z:getZ()==pz
   local shown=present and player:CanSee(z)
   local d
   if present then local dx,dy=z:getX()-px,z:getY()-py;d=dx*dx+dy*dy end
   local inspect=present and (s.sneaking==true or d<=36)
   local npc=(shown or inspect) and Actors.isNpc(z)
   if inspect then Concealment.observe(s,player,z,npc and 'npc' or 'zombie',d)end
   if shown then
    if npc then npcVisible=npcVisible+1;s.visiblePeople[#s.visiblePeople+1]=z else
    zombieVisible=zombieVisible+1
    if d>36 and read(function()return z:getTarget()==player end)==true then encounter=true end
    if d<=36 then
     near=near+1
     local barrier=read(function()
      local a,b=player:getSquare(),z:getSquare()
      if not a or not b or math.abs(a:getX()-b:getX())>1 or math.abs(a:getY()-b:getY())>1 then return nil end
      return a:isBlockedTo(b)
     end)
     if barrier==true then blocked=blocked+1 else accessible=accessible+1;encounter=true end
     local target=read(function()return z:getTarget()==player end)
     if target==nil then targetKnown=false elseif target then targeted=targeted+1 end
     local attack=read(function()return z:isAttacking()end)
     if attack==nil then attackKnown=false end
     if attack and target then attacking=attacking+1 end
     local advancing=nil
     local last=motion[z]
     if last and now-last.at>=500 and now-last.at<=3000 then
      movingKnown=true
      local oldDx,oldDy=last.x-px,last.y-py
      advancing=math.sqrt(oldDx*oldDx+oldDy*oldDy)-math.sqrt(d)>.2
      if advancing then approaching=approaching+1 end
     end
     if barrier~=true then
      if target or advancing then reactive=reactive+1;if d<=9 then reactiveCrowd=reactiveCrowd+1 end
      elseif target==nil or advancing==nil then reactiveKnown=false end
     end
     if not last or now-last.at>=500 then motion[z]={x=z:getX(),y=z:getY(),at=now} end
    end
    if d<=9 then crowd=crowd+1 end
    end
   end
  end
  s.exposureChecked=true;s.encounterThreat=encounter
  s.visible=zombieVisible
  s.npcVisible=npcVisible
  s.near=near;s.crowd=crowd;s.reactiveCrowd=reactiveCrowd;s.accessibleNear=accessible;s.blockedNear=blocked
  if reactiveKnown then s.reactiveNear=reactive end
  if attackKnown and targetKnown then s.attacking=attacking end
  if targetKnown then s.targeted=targeted end
  if movingKnown then s.approaching=approaching end
 end)
 local peopleRead=read(function()
  local list=getOnlinePlayers and getOnlinePlayers()
  if not list and ((isClient and isClient()) or (isServer and isServer())) then return false end
  if list then for i=0,list:size()-1 do local person=list:get(i)
   if person~=player and not person:isDead() and person:getZ()==player:getZ() then
    Concealment.observe(s,player,person,'player')
    if player:CanSee(person) then s.visiblePeople[#s.visiblePeople+1]=person end
   end
  end end
  return true
 end)
 if peopleRead~=true then s.exposureChecked=false end
 Concealment.finish(s,player)
 local now=getTimestampMs()
 local clock=S.threatClock[player] or {};S.threatClock[player]=clock
 if (s.near or 0)>0 or (s.visible or 0)>0 then clock.hadThreat=true;clock.clearSince=nil;s.recentThreat=true
 elseif s.near==0 and s.visible==0 then
  clock.clearSince=clock.clearSince or now;s.recentThreat=clock.hadThreat==true and now-clock.clearSince<10000
 else clock.clearSince=nil;s.recentThreat=nil end
 local e=S.events[player] or {}
 s.acute=e.acute~=nil and now-e.acute<3000
 s.pickup=e.pickup~=nil and now-e.pickup<3000
 s.treeDown=e.treeDown~=nil and now-e.treeDown<3000
 return s
end
function S.capture(player)
 S.metrics.captures=S.metrics.captures+1
 local raw=S.frame and S.frame[player]
 if raw then S.metrics.hits=S.metrics.hits+1 else
  local started=getTimestampMs();raw=collect(player);local elapsed=getTimestampMs()-started;S.metrics.readMs=S.metrics.readMs+elapsed;S.metrics.maxReadMs=math.max(S.metrics.maxReadMs,elapsed)
  if S.frame and player then S.frame[player]=raw end
 end
 -- Consumers can attach event context without mutating the shared snapshot.
 local s={};for k,v in pairs(raw)do s[k]=v end
 if raw.traits then s.traits={};for k,v in pairs(raw.traits)do s.traits[k]=v end end
 if raw.levels then s.levels={};for k,v in pairs(raw.levels)do s.levels[k]=v end end
 if S.loot then s.loot=S.loot[player];if s.loot then s.lootKind=require('CSV/LootRules').classify(s.loot);s.lootItem=s.loot.itemType end end
 if S.outcome then
  s.outcome=S.outcome[player];s.outcomeGroup=s.outcome and require('CSV/OutcomeRules').classify(s.outcome)
  s.outcomeKind=s.outcome and s.outcome.kind;s.outcomeNativeSound=s.outcome and s.outcome.nativeSound
   s.vehicleCause=s.outcome and s.outcome.nativeCause;s.vehicleManual=s.outcome and s.outcome.manual;s.vehicleSynchronous=s.outcome and s.outcome.synchronous
 end
 -- The game Lua environment does not expose the standard package library.
 -- Psychology registers this reader when it loads; shared/server use stays independent.
 if S.psychologyFacts then s.humanThreat,s.psychology=S.psychologyFacts(player);if s.humanThreat then s.recentThreat=true end end
 if S.vehicleFacts then S.vehicleFacts(player,s)end
 s.nativeAlert=S.nativeAlert and S.nativeAlert[player]==true or false
 s.reload=S.reload and S.reload[player]
 return s
end
return S
