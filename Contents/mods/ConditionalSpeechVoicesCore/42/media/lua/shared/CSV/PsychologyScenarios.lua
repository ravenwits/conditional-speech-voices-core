local S={}
-- Independent expected meanings: do not call the production selector here.
local expected={
 zombieKill={'KillDesperate','KillDesperate'},humanKill={'AfterHumanShaken','AfterHumanSteady'},
 humanAttack={'MortalFear','MortalFear'},escape={'StillAlive','StillAlive'},hiddenPursuer={'KeepHidden','KeepHidden'},
 lostTarget={'LostPerson','LostPerson'},reacquired={'FoundPerson','FoundPerson'},pursuit={'PursuitUneasy','PursuitSteady'},
 friendSearch={'FriendMissing','FriendMissing'},humanGroup={'HumanGroup','HumanGroup'},injurySurvived={'InjuryAftermath','StillAlive'},
 raid={'ShelterThreat','HumanDanger'},raidSurvived={'ShelterAftermath','StillAlive'}}
local aftermath={humanKill=true,escape=true,injurySurvived=true,raidSurvived=true}
function S.cases()
 local out={}
 for kind,meanings in pairs(expected)do
  for _,experience in ipairs({'uncertain','practiced'})do
   for _,mode in ipairs({'safe','whisper','concealed','unverified','danger'})do
    local e={kind=kind,verified=mode~='unverified',experience=experience,knownPursuer=true,seenBefore=true,intent=true,visibleCount=2,homeKnown=true}
    local f={psychology=e,sneaking=mode=='whisper' or mode=='concealed',near=0,visible=0,recentThreat=mode=='danger',humanThreat=mode=='danger',panic=3}
    local pool=e.verified and meanings[experience=='practiced' and 2 or 1] or nil
    if kind=='zombieKill' and e.verified and f.sneaking then pool='Kill' end
    local silent=mode=='concealed' or mode=='unverified' or mode=='danger' and aftermath[kind]
    out[#out+1]={name='Psychology '..kind..' '..experience..' '..mode,group='Psychology',level=1,max=1,state=f,prefs={whisper=mode=='whisper'},expect=pool or 'none',mode=silent and 'silent' or 'spoken',newPsychology=true,limited='none'}
   end
  end
 end
 for _,row in ipairs({{'pursuit',false,0,1,0,'spoken'},{'direct attack',false,1,1,0,'silent'},{'hidden observer',true,0,0,1,'silent'},{'unverified',false,0,0,0,'silent'}})do
  out[#out+1]={name='Fresh zombie kill: '..row[1],group='Psychology',level=1,max=1,
   state={psychology={kind='zombieKill',verified=row[1]~='unverified',experience='practiced'},sneaking=row[2],directAttack=row[3],activePursuit=row[4],whisperRisk=row[5],near=2,visible=2,recentThreat=true,panic=0},
   prefs={whisper=true},expect=row[1]=='unverified' and 'none' or row[2] and 'Kill' or 'KillControlled',mode=row[6],newPsychology=true,limited='none'}
 end
 for _,experience in ipairs({'uncertain','practiced'})do
  for _,mode in ipairs({'safe','renewed danger','unknown safety'})do
   local safe=mode=='safe';local renewed=mode=='renewed danger'
   local f={psychology={kind='zombieKill',verified=true,experience=experience,aftermath=true},sneaking=false,
    near=renewed and 1 or 0,visible=renewed and 1 or 0,recentThreat=renewed,humanThreat=false,panic=0}
   if safe then f.encounterThreat=false elseif renewed then f.encounterThreat=true;f.directAttack=1 end
   out[#out+1]={name='Zombie aftermath '..experience..' '..mode,group='Psychology',level=1,max=1,state=f,
    prefs={whisper=false},expect=safe and (experience=='practiced' and 'AfterZombieSteady' or 'AfterZombieShaken') or 'none',mode=safe and 'spoken' or 'silent',newPsychology=true,limited='none'}
  end
 end
 for _,row in ipairs({
  {name='Experienced, calm, brave, ongoing fight',state={panic=0,traits={brave=true}},expect='KillControlled'},
  {name='Experienced, high panic overrides bravery',state={panic=4,traits={brave=true}},expect='KillDesperate'},
  {name='Experienced, exhaustion without contact',state={panic=0,endurance=3},expect='KillControlled'},
  {name='Experienced, exhaustion during contact',state={panic=0,endurance=3,directAttack=1},expect='KillDesperate',silent=true},
  {name='Experienced, critically low health',state={panic=0,health=25},expect='KillDesperate'},
  {name='Novice without panic',state={panic=0},experience='uncertain',expect='KillUneasy'}
 })do
  local f={psychology={kind='zombieKill',verified=true,experience=row.experience or 'practiced'},sneaking=false,near=2,visible=2,recentThreat=true,encounterThreat=true,activePursuit=1,health=100}
  for key,value in pairs(row.state)do f[key]=value end
  out[#out+1]={name='Kill context: '..row.name,group='Psychology',level=1,max=1,state=f,prefs={whisper=false},expect=row.expect,mode=row.silent and 'silent' or 'spoken',newPsychology=true,limited='none'}
 end
 for _,row in ipairs({
  {name='Recent shock after zombie fight',kind='zombieKill',recent=true,expect='AfterZombieShaken'},
  {name='Settled after zombie fight',kind='zombieKill',recent=false,expect='AfterZombieSteady'},
  {name='Recent shock after human fight',kind='humanKill',recent=true,expect='AfterHumanShaken'},
  {name='Settled after human fight',kind='humanKill',recent=false,expect='AfterHumanSteady'}
 })do
  out[#out+1]={name=row.name,group='Psychology',level=1,max=1,
   state={psychology={kind=row.kind,verified=true,experience='practiced',aftermath=true},sneaking=false,
    near=0,visible=0,recentThreat=false,encounterThreat=false,humanThreat=false,panic=0,health=100,recentDistress=row.recent},
   prefs={whisper=false},expect=row.expect,mode='spoken',newPsychology=true,limited='none'}
 end
 require('CSV/Sort').sort(out,function(a,b)return a.name<b.name end);return out
end
return S
