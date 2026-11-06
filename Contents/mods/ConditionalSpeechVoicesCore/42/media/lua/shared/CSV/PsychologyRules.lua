local R={groups={Psychology='Panic'}}
R.events={zombieKill=true,humanKill=true,humanAttack=true,escape=true,hiddenPursuer=true,lostTarget=true,reacquired=true,pursuit=true,friendSearch=true,humanGroup=true,injurySurvived=true,raid=true,raidSurvived=true}
function R.pool(e,f)
 if not e or e.verified~=true or not R.events[e.kind] then return nil end
 local practiced=e.experience=='practiced'
 if e.kind=='zombieKill' then
  local safe=f.encounterThreat==false and f.near==0 and f.visible==0 and f.recentThreat==false and f.humanThreat~=true and f.fire~=true and not require('CSV/Concealment').active(f)
  if safe then return practiced and not require('CSV/KillSpeech').distressed(f) and 'AfterZombieSteady' or 'AfterZombieShaken' end
  if e.aftermath then return nil end
  return 'Kill'
 elseif e.kind=='humanKill' then return practiced and 'AfterHumanSteady' or 'AfterHumanShaken'
 elseif e.kind=='humanAttack' then return (f.panic or 0)>=3 and 'MortalFear' or 'HumanDanger'
 elseif e.kind=='escape' then return 'StillAlive'
 elseif e.kind=='hiddenPursuer' and e.knownPursuer then return 'KeepHidden'
 elseif e.kind=='lostTarget' and e.seenBefore then return 'LostPerson'
 elseif e.kind=='reacquired' and e.seenBefore then return 'FoundPerson'
 elseif e.kind=='pursuit' and e.intent then return practiced and 'PursuitSteady' or 'PursuitUneasy'
 elseif e.kind=='friendSearch' and e.intent then return 'FriendMissing'
 elseif e.kind=='humanGroup' and (e.visibleCount or 0)>=2 then return 'HumanGroup'
 elseif e.kind=='injurySurvived' then return practiced and 'StillAlive' or 'InjuryAftermath'
 elseif e.kind=='raid' and e.homeKnown then return practiced and 'HumanDanger' or 'ShelterThreat'
 elseif e.kind=='raidSurvived' and e.homeKnown then return practiced and 'StillAlive' or 'ShelterAftermath' end
end
function R.allowed(id,f)
 if id=='AfterZombieShaken_2' then return (f.panic or 0)>=2 end
 return id~='InjuryAftermath_3' or type(f.pain)=='number' and f.pain>0 end
function R.urgent(e)return e and (e.kind=='humanAttack' or e.kind=='raid') end
function R.priority(e)return require('CSV/Priority').rank(R.urgent(e),e and e.kind=='hiddenPursuer') end
function R.defer(e)return e and (e.kind=='zombieKill' and e.aftermath==true or e.kind=='humanKill' or e.kind=='escape' or e.kind=='injurySurvived' or e.kind=='raidSurvived') end
return R
