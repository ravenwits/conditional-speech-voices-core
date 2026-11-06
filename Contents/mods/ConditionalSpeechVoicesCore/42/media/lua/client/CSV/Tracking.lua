local M={}
local V=require 'CSV/Core'
local A=require 'CSV/Actors'
local call=A.call
local Policy=require 'CSV/PsychologyPolicy'
function M.update(P,p,s,f,now)
 local t=s.track
 if t then
  if now-t.started>Policy.trackLifetime or call(t.body,'isDead')==true then s.track=nil
  else
   local seen=call(p,'CanSee',t.body)==true and V.near(p,t.body,Policy.trackRange)
   if t.visible and not seen then t.lostAt=now
   elseif seen and not t.visible and t.lostAt and now-t.lostAt>=Policy.lostSightDelay then P.queue(p,{kind='reacquired',seenBefore=true,subject=t.body})end
   if not seen and t.lostAt and now-t.lostAt>=Policy.lostSightDelay and not t.announced then
    P.queue(p,{kind=t.mode=='friend' and 'friendSearch' or 'lostTarget',seenBefore=true,intent=true,subject=t.body});t.announced=true
   end
   if seen then t.seenAt=now;t.announced=false end;t.visible=seen
  end
 end
end
return M
