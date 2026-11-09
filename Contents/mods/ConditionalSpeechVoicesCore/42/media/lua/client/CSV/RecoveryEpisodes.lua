local M={}
local A=require 'CSV/Actors'
local call=A.call
local Policy=require 'CSV/PsychologyPolicy'
function M.update(P,p,s,f,now)
 local safeKnown=require('CSV/Safety').settled(f) and (s.humanUntil or 0)<=now
 if safeKnown then s.safeSince=s.safeSince or now else s.safeSince=nil end
 if s.pursuer and call(s.pursuer,'isDead')==true then s.pursuer=nil;s.pursuerSeen=false end
 if s.pursuer and s.pursuerSeen and call(p,'CanSee',s.pursuer)==false and f.sneaking==true and (s.humanUntil or 0)>now then
  P.queue(p,{kind='hiddenPursuer',knownPursuer=true,subject=s.pursuer})
 end
 if s.shelterAttackAt and now-s.shelterAttackAt<=12000 and not s.raid then s.raid=true;P.queue(p,{kind='raid',homeKnown=true})end
 s.shelterAttackAt=nil
 local health=f.health
 local injury=require('CSV/State').events[p] or {}
 local knownWound=(f.bleeding or 0)>0 or injury.physicalInjury and now-injury.physicalInjury<=Policy.injuryEvidenceAge
 if knownWound and type(health)=='number' and health<Policy.severeHealth then s.severeInjury=true end
 if s.safeSince and now-s.safeSince>=Policy.safetyPeriod then
  if s.wasThreatened then P.queue(p,{kind='escape'});s.wasThreatened=false;s.pursuer=nil end
  if s.raid then P.queue(p,{kind='raidSurvived',homeKnown=true});s.raid=false end
  if s.severeInjury and type(health)=='number' and health>=Policy.recoveredHealth then P.queue(p,{kind='injurySurvived'});s.severeInjury=false end
 end
end
return M
