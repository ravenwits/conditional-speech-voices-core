local M={}
function M.cases()
 local rows={
  {'Crouched: currently targeted by a close zombie','exposedZombie',1,0,true,false,4},
  {'Crouched: verified close NPC attack','exposedNpc',1,0,true,false,4},
  {'Crouched: verified close PvP attack','exposedPlayer',1,0,true,false,4},
  {'Crouched: old distant pursuer',nil,0,0,true,true,2},
  {'Crouched: close attacker and unaware bystander','exposedZombie',1,1,true,true,2},
  {'Crouched: uncertain multiplayer surroundings','exposedPlayer',1,0,false,true,2},
  {'Crouched: visible zombie is not targeting you',nil,0,1,true,true,2},
  {'Crouched: obstacle separates the enemy',nil,0,1,true,true,2},
 }
 local out={}
 for _,r in ipairs(rows)do
  local s={jammed=true,sneaking=true,panic=2,near=1,visible=1,recentThreat=true,exposureChecked=r[5],concealmentRisk=r[4]}
  if r[2] then s[r[2]]=r[3]end
  out[#out+1]={name=r[1],group='GunJammed',level=1,max=1,state=s,expect='GunJammed',mode='spoken',radius=r[7],expectWhisper=r[6],newConcealment=true,newConditions=true,prefs={whisper=true}}
 end
 return out
end
return M
