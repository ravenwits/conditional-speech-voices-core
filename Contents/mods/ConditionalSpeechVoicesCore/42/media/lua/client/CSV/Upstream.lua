local U={installed=false,trees=setmetatable({},{__mode='k'}),needs=setmetatable({},{__mode='k'}),nextScan=0}
local function safe(fn)local ok,value=pcall(fn);if ok then return value end end
local function localBob(p)
 return p and p:isLocalPlayer() and not p:isDead() and require('CSV/Core').extended(require('CSV/Core').voice(p))
end
function U.countSpeech(player,text)
 if not require('CSV/Core').config.enabled or not require('CSV/Core').languageSupported() or not require('CSV/Conditions').enabled or not localBob(player) or type(text)~='string' then return false end
 local f=require('CSV/State').capture(player)
 if type(f.rounds)~='number' or f.rounds<1 or f.jammed==true then return false end
 local suffix=safe(function()return getText('UI_shotsLeft')end)
 if not suffix or text~=tostring(f.rounds)..' '..suffix then return false end
 require('ConditionalSpeech_Core').generateSpeechFrom(player,'AmmoCount',1,1,false,false)
 return true
end
function U.trackTree(action)
 local p,tree=action.character,action.tree
 if not localBob(p) or not tree or tree:getObjectIndex()<0 then return end
 local square=tree:getSquare();if not square then return end
 U.trees[p]={tree=tree,x=square:getX(),y=square:getY(),z=square:getZ(),at=getTimestampMs()}
end
function U.scanTrees(now)
 for p,t in pairs(U.trees)do
  if now-t.at>8000 or not localBob(p) or p:getZ()~=t.z or (p:getX()-t.x)^2+(p:getY()-t.y)^2>36 then U.trees[p]=nil
  elseif safe(function()return t.tree:getObjectIndex()<0 end) then
   local square=safe(function()return getCell():getGridSquare(t.x,t.y,t.z)end)
   -- Object disappearance in an unloaded chunk is not proof of a felled tree.
   if square and safe(function()return square:getTree()==nil end)==true then
    U.trees[p]=nil
    require('CSV/State').record(p,'treeDown')
    require('ConditionalSpeech_Core').generateSpeechFrom(p,'ChopTree',1,1,false,false)
    require('CSV/ProductionReport').observe('tree_removed_after_local_chop',{})
   end
  end
 end
end
function U.observeNeeds(p,f,now)
 if not localBob(p) then return end
 local old=U.needs[p];local levels=f.levels or {}
 if not old then U.needs[p]={levels=levels,pending={},at=now};return end
 local N=require('CSV/NeedTiming');local C=require('CSV/Core').client
 for group,level in pairs(levels)do
  if (level or 0)>(old.levels[group] or level) then
   local played=(N.history[p] or {})[group]
   if not played or played.at<old.at then old.pending[group]={level=level,at=now,tries=0} end
  end
 end
 old.levels=levels;old.at=now
 for group,e in pairs(old.pending)do
  local played=(N.history[p] or {})[group]
  if not require('ConditionalSpeech_Core').enabledPhraseSet(group) or type(levels[group])=='number' and levels[group]<e.level or (played and played.at>=e.at) then old.pending[group]=nil
  -- A still-current need does not become irrelevant after three rejected attempts.
  -- Wait for its own interval and for safety, then retry until it is heard or improves.
  elseif type(levels[group])=='number' and N.remaining(p,group,e.level,C.preferences().frequency,now)==0 and f.sneaking==false and f.near==0 and f.visible==0 and f.recentThreat==false and now>=(old.nextAttempt or 0) and getTimestamp()>=(p:getModData().cs_lastFoodReactionTime or 0) then
   local busy=false;for _,entry in ipairs(C.active)do if entry.player==p then busy=true end end
   if not busy then
    old.nextAttempt=now+10000;e.tries=e.tries+1
    require('CSV/ProductionReport').observe('retry_suppressed_'..group,f)
    require('ConditionalSpeech_Core').generateSpeechFrom(p,group,e.level,4,false,false)
    local attempt=C.lastAttempt[p]
    if attempt and attempt.group==group and (attempt.outcome=='played' or attempt.outcome=='local_thought' or attempt.outcome=='group_disabled') then old.pending[group]=nil end
    break
   end
  end
 end
end
function U.tick()
 if not U.installed or not require('CSV/Conditions').enabled then return end
 local now=getTimestampMs();if now<U.nextScan then return end;U.nextScan=now+1000
 U.scanTrees(now)
 for i=0,getNumActivePlayers()-1 do local p=getSpecificPlayer(i);if localBob(p) then U.observeNeeds(p,require('CSV/State').capture(p),now) end end
end
function U.install()
 if U.installed then return true end
 local ok,err=require('CSV/Connections').install('upstream-actions',function(t)
  local speech=require 'ConditionalSpeech_Core'
  require 'TimedActions/ISEatFoodAction';require 'TimedActions/ISChopTreeAction'
  assert(type(speech.load_n_set_Moodles)=='function' and type(speech.check_AteFood)=='function','upstream mood/food interface unavailable')
  assert(ISEatFoodAction and type(ISEatFoodAction.perform)=='function' and ISChopTreeAction and type(ISChopTreeAction.animEvent)=='function','timed action interface unavailable')
  local loadMoodles=speech.load_n_set_Moodles
  t:replace(speech,'load_n_set_Moodles',function(index,player)
   if player==nil and index~=nil and type(index)~='number' then player=index;index=0 end
   return loadMoodles(index,player)
  end)
  local eat=speech.check_AteFood
  t:replace(speech,'check_AteFood',function(player,food)
   local action=U.foodAction
   if action then if action._csvFoodReported then return end;action._csvFoodReported=true end
   return eat(player,food)
  end)
  local perform=ISEatFoodAction.perform
  t:replace(ISEatFoodAction,'perform',function(self,...)
   local previous=U.foodAction;U.foodAction=self;self._csvFoodReported=false
   local result={pcall(perform,self,...)}
   if result[1] and not self._csvFoodReported then require('CSV/Observers').run('food',speech.check_AteFood,self.character,self.item)end
   U.foodAction=previous
   if not result[1] then error(result[2])end
   return unpack(result,2)
  end)
  local anim=ISChopTreeAction.animEvent
  t:replace(ISChopTreeAction,'animEvent',function(self,event,...)
   if isClient() and event=='ChopTree' and self.axe then U.trackTree(self)end
   return anim(self,event,...)
  end)
  local meta=require 'ConditionalSpeech_metaValues'
  t:set(speech,'DAWN_TIME',speech.DAWN_TIME or meta.DAWN_TIME)
  t:set(speech,'DUSK_TIME',speech.DUSK_TIME or meta.DUSK_TIME)
 end)
 U.installed=ok
 return ok,err
end
return U
