local M={}
local V=require 'CSV/Core'
local A=require 'CSV/Actors'
local call=A.call
local Policy=require 'CSV/PsychologyPolicy'
function M.update(P,p,s,f,now)
 local visible=0
 local function person(body)
  if body==p or call(body,'isDead')~=false or (A.kind(body)~='npc' and A.kind(body)~='player') then return end
  if call(p,'CanSee',body)~=true or not V.near(p,body,20) then return end
  visible=visible+1;s.people[body]=now
  if call(body,'getTarget')==p and call(body,'isAttacking')==true then
   s.pursuer=body;s.pursuerSeen=true;s.humanUntil=now+12000;s.wasThreatened=true
   P.queue(p,{kind='humanAttack',actorKind=A.kind(body)})
  end
 end
 for _,body in ipairs(f.visiblePeople or {})do person(body)end
 if visible>=2 and (s.visibleCount or 0)<2 then P.queue(p,{kind='humanGroup',visibleCount=visible})end
 for body,t in pairs(s.people)do if now-t>60000 then s.people[body]=nil end end
 s.visibleCount=visible
end
return M
