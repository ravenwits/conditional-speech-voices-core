local T={players=setmetatable({},{__mode='k'}),nextTick=0}
local V=require 'CSV/Core'
local call=require('CSV/Actors').call
local woundMethods={'getScratchTime','getCutTime','getDeepWoundTime','getBiteTime'}
local function state(p)
 local s=T.players[p]
 if not s then
  local data=call(p,'getModData')
  local wounds=type(data)=='table' and data.CSV_traitWounds
  if type(wounds)~='table' then wounds={} end
  if type(data)=='table' then data.CSV_traitWounds=wounds end
  s={last={},wounds=wounds};T.players[p]=s
 end
 return s
end
local function eligible(p)
 return p and V.config.enabled and call(p,'isLocalPlayer')==true and call(p,'isDead')==false and V.extended(V.voice(p)) and V.languageSupported()
end
function T.snapshot(p)
 local s=state(p);local traits=require('CSV/Traits').read(p)
 local moods=call(p,'getMoodles');local stats=call(p,'getStats')
 local queue=ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[p]
 local action=queue and queue.current
 local awake=call(p,'isAsleep');if type(awake)=='boolean' then awake=not awake else awake=nil end
 local f={traits=traits,awake=awake,tired=call(moods,'getMoodleLevel',MoodleType.TIRED),stress=call(moods,'getMoodleLevel',MoodleType.STRESS),visible=call(stats,'getNumVisibleZombies'),falling=call(p,'isFalling'),action=action and action.Type,actionObject=action,wounded=false,lingering=false,inspectLiterature=s.bookUntil and V.now()<=s.bookUntil}
 f.cutAt=s.cutAt
 if traits.slowHealer or traits.thinSkin then
  local parts=call(call(p,'getBodyDamage'),'getBodyParts');local count=call(parts,'size')
  local hours=call(getGameTime and getGameTime(),'getWorldAgeHours')
  if type(count)=='number' and type(hours)=='number' then
   for i=0,math.min(count,32)-1 do
    local part=call(parts,'get',i)
    for _,method in ipairs(woundMethods)do
     local value=call(part,method);local key=tostring(i)..method
     if type(value)=='number' and value>0 then
      f.wounded=true
      local wound=s.wounds[key]
      if type(wound)~='table' or type(wound.since)~='number' or hours<wound.since or value>(wound.value or value)+.001 then wound={since=hours};s.wounds[key]=wound end
      wound.value=value
      if hours-wound.since>=48 then f.lingering=true end
      if s.cutPart==i and s.cutMethod==method then f.recentCut=true end
     elseif value==0 then s.wounds[key]=nil end
    end
   end
  end
 end
 return f
end
function T.queue(p,group,f)
 if not eligible(p) then return false end
 local s=state(p);local now=V.now()
 if s.last[group] and now-s.last[group]<300000 then return false end
 local e={kind='trait',traitGroup=group,verified=true,completed=true,player=p,obj=p,before={},after=f,actionObject=(group=='TraitFumble' or group=='TraitReading' or group=='TraitStudy') and f.actionObject or nil,cutAt=group=='TraitScratch' and f.cutAt or nil}
 if require('CSV/TraitSpeechRules').classify(e)~=group then return false end
 if require('CSV/Outcomes').queue(e,group) then s.last[group]=now;return true end
 return false
end
function T.observe(p,f,now)
 local s=state(p);local previous=s.before
 if previous and previous.awake==false and f.awake==true then T.queue(p,'TraitRest',f) end
 if previous and previous.falling==true and f.falling==false then s.fallDue=now+5000 end
 if s.fallDue and now>=s.fallDue then T.queue(p,'TraitFall',f);s.fallDue=nil end
 if s.cutDue and now>=s.cutDue then T.queue(p,'TraitScratch',f);s.cutDue=nil end
 if f.lingering and not (previous and previous.lingering) then T.queue(p,'TraitWound',f) end
 if f.actionObject~=s.action then s.action=f.actionObject;s.actionAt=now;s.actionDone=false end
 if f.actionObject and not s.actionDone and now-s.actionAt>=1000 then
  if f.action=='ISInventoryTransferAction' then s.actionDone=T.queue(p,'TraitFumble',f)
  elseif now-s.actionAt>=20000 and f.action=='ISReadABook' then s.actionDone=T.queue(p,'TraitReading',f)
  elseif now-s.actionAt>=20000 and f.action=='ISResearchRecipe' then s.actionDone=T.queue(p,'TraitStudy',f) end
 end
 s.before=f
end
function T.injury(p,kind,part)
 if (kind=='scratch' or kind=='cut') and type(part)=='number' then
  local s=state(p);s.cutAt=V.now();s.cutDue=s.cutAt+8000;s.cutPart=part;s.cutMethod=kind=='cut' and 'getCutTime' or 'getScratchTime'
 end
end
function T.tick()
 local now=V.now();if now<T.nextTick then return end;T.nextTick=now+1000
 for i=0,getNumActivePlayers()-1 do
  local p=getSpecificPlayer(i)
  if eligible(p) then T.observe(p,T.snapshot(p),now)end
 end
end
function T.literature(index,context,items)
 local p=getSpecificPlayer(index)
 if not eligible(p) or not require('CSV/Traits').read(p).illiterate or type(items)~='table' then return end
 -- Read is disabled for this trait. Inspecting written literature is the observable action.
 -- Only selected rows are checked. No inventory or stack expansion.
 for i=1,math.min(#items,32)do
  local item=items[i]
  if type(item)=='table' and item.items then item=item.items[1] end
  if call(call(item,'getScriptItem'),'isItemType',ItemType.LITERATURE)==true
   and call(item,'hasTag',ItemTag.PICTUREBOOK)==false and call(item,'hasTag',ItemTag.PICTURE)==false and call(item,'hasTag',ItemTag.UNINTERESTING)==false then
   state(p).bookUntil=V.now()+10000;T.queue(p,'TraitIlliterate',T.snapshot(p));return
  end
 end
end
function T.install()
 return require('CSV/Connections').install('trait.literature-inspect',function(transaction)
  transaction:event(Events.OnFillInventoryObjectContextMenu,function(...)
   require('CSV/Observers').run('trait.literature',T.literature,...)
  end)
 end)
end
return T
