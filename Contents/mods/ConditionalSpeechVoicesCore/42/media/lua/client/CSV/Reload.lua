local V=require 'CSV/Core'
local A=require 'CSV/Actors'
local S=require 'CSV/State'
local R=require 'CSV/ReloadRules'
local M={active=setmetatable({},{__mode='k'}),nextTick=0,metrics={starts=0,ineligible=0,evaluations=0,requests=0,finished=0,cancelled=0},hooks={}}
function M.valid(e)
 return e and M.active[e.player]==e and not e.ended and not e.consumed
  and A.call(e.player,'isDead')==false and A.call(e.player,'getPrimaryHandItem')==e.weapon
end
function M.begin(action,insert)
 M.metrics.starts=M.metrics.starts+1
 local p=action.character
 if A.call(p,'isLocalPlayer')~=true or not V.extended(V.voice(p)) then M.metrics.ineligible=M.metrics.ineligible+1;return end
 local old=M.active[p];if old then old.ended=true end
 M.active[p]={player=p,weapon=action.gun,action=action,insert=insert,at=V.now()}
end
function M.finish(action,cancelled)
 local e=M.active[action.character]
 if not e or e.action~=action then return end
 M.metrics[cancelled and 'cancelled' or 'finished']=M.metrics[cancelled and 'cancelled' or 'finished']+1
 e.ended=true;M.active[action.character]=nil
 if not cancelled then return end -- An already spoken phrase may finish naturally.
 local C=V.client
 for i=#C.active,1,-1 do local sound=C.active[i]
  if sound.player==e.player and sound.line:match('^Reload') then C.cancel(sound,'reload_ended',true)end
 end
end
function M.tick()
 local now=V.now();if now<M.nextTick then return end;M.nextTick=now+200
 for p,e in pairs(M.active)do if M.valid(e) then
  local f=S.capture(p);local group,reason=R.group(f)
  M.metrics.evaluations=M.metrics.evaluations+1
  M.last={group=group or '-',reason=reason or group or '-',panic=f.panic,near=f.near,visible=f.visible,sneaking=f.sneaking,at=now}
  if e.lastReason~=(group or reason) then
   e.lastReason=group or reason;require('CSV/ProductionReport').observe('reload_'..tostring(e.lastReason),f)
  end
  if group then
   M.metrics.requests=M.metrics.requests+1
   S.reload=S.reload or setmetatable({},{__mode='k'});S.reload[p]=e
   local ok,err=pcall(require('ConditionalSpeech_Core').generateSpeechFrom,p,group,1,1,false,false)
   S.reload[p]=nil
   if not ok then error(err)end
   if require('CSV/Pending').accepted(V.client.lastAttempt[p],group) then e.consumed=true end
  end
 end end
end
function M.install()
 for _,row in ipairs({{'ISReloadWeaponAction',false},{'ISInsertMagazine',true}})do
  require('TimedActions/'..row[1]);local class=_G[row[1]]
  if class and not class.csvReloadPressure then
   class.csvReloadPressure=true
   local start=class.start
   class.start=function(self,...)local result=start(self,...);M.begin(self,row[2]);return result end
   M.hooks[row[1]]={class=class,start=class.start}
   for _,method in ipairs({'stop','perform'})do local original=class[method]
    class[method]=function(self,...)M.finish(self,method=='stop');return original(self,...)end
   end
  end
 end
end
return M
