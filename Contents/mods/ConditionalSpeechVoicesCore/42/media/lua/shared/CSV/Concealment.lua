local C={lastHit=setmetatable({},{__mode='k'}),lastActive=setmetatable({},{__mode='k'}),attacks=setmetatable({},{__mode='k'}),motion=setmetatable({},{__mode='k'})}
local A=require 'CSV/Actors';local H=require 'CSV/Hearing';local call=A.call
function C.record(victim,attacker)
 if not victim then return end
 C.lastHit[victim]={at=getTimestampMs(),attacker=attacker}
 require('CSV/State').invalidate(victim)
 if not attacker then return end
 local rows=C.attacks[victim] or setmetatable({},{__mode='k'});C.attacks[victim]=rows
 rows[attacker]=getTimestampMs();require('CSV/State').invalidate(victim)
end
function C.active(s)return (s.directAttack or 0)>0 or (s.activePursuit or 0)>0 end
function C.observe(s,p,body,kind,d)
 if not d then local dx,dy=body:getX()-p:getX(),body:getY()-p:getY();d=dx*dx+dy*dy end
 if d>36 and s.sneaking~=true then return end
 kind=kind or (A.isNpc(body) and 'npc' or 'zombie')
 local riskRadius=s.sneaking==true and H.radius(body,kind) or 0
 if d>36 and d>riskRadius*riskRadius then return end
 local at=(C.attacks[p] or {})[body];local now=getTimestampMs()
 local hit=at~=nil and now-at>=0 and now-at<=1500
 local a,b=call(p,'getSquare'),call(body,'getSquare')
 local blocked=a and b and math.abs(a:getX()-b:getX())<=1 and math.abs(a:getY()-b:getY())<=1 and call(a,'isBlockedTo',b)==true
 local target=kind=='zombie' and call(body,'getTarget')==p
 local seen=call(body,'CanSee',p)==true
 local direct=d<=36 and hit or target and d<=6.25 and not blocked and call(body,'isAttacking')==true
 local approaching=false
 if target and d<=36 and seen and not blocked then
  local rows=C.motion[p] or setmetatable({},{__mode='k'});C.motion[p]=rows;local last=rows[body]
  if last and now-last.at>=250 and now-last.at<=1500 then
   local oldx,oldy=last.x-p:getX(),last.y-p:getY()
   approaching=math.sqrt(oldx*oldx+oldy*oldy)-math.sqrt(d)>.2
   if approaching then last.approachUntil=now+350 end
  end
  if last and (last.approachUntil or 0)>=now then approaching=true end
  if not last or now-last.at>=250 then rows[body]={x=body:getX(),y=body:getY(),at=now,approachUntil=last and last.approachUntil}end
 end
 if direct then s.directAttack=(s.directAttack or 0)+1
 elseif approaching then s.activePursuit=(s.activePursuit or 0)+1 end
 if s.sneaking~=true then return end
 local radius=riskRadius
 if d>radius*radius then return end
 s.hearingRiskRadius=math.max(s.hearingRiskRadius or 0,radius)
 local known=not blocked and seen and (target or hit)
 if known and d<=36 then
  local key=kind=='zombie' and 'exposedZombie' or kind=='npc' and 'exposedNpc' or 'exposedPlayer';s[key]=(s[key] or 0)+1
 else
  s.concealmentRisk=(s.concealmentRisk or 0)+1
  if d<=(riskRadius/2)^2 then s.whisperRisk=(s.whisperRisk or 0)+1 end
 end
end
function C.finish(s,p)
 local now=getTimestampMs()
 local hit=C.lastHit[p]
 if hit and now-hit.at>=0 and now-hit.at<=1500 and call(hit.attacker,'isDead')~=true then s.directAttack=math.max(s.directAttack or 0,1)end
 if C.active(s) then C.lastActive[p]={at=now,x=p:getX(),y=p:getY(),z=p:getZ()}
 else
  local last=C.lastActive[p]
  s.attackGrace=last~=nil and now-last.at>=0 and now-last.at<=600 and p:getZ()==last.z and (p:getX()-last.x)^2+(p:getY()-last.y)^2<=1
 end
end
function C.open(s)
 return s.sneaking==true and s.exposureChecked==true and s.concealmentRisk==0
  and ((s.exposedZombie or 0)+(s.exposedNpc or 0)+(s.exposedPlayer or 0)>0)
end
return C
