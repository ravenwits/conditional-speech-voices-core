local T={}
function T.cases()
 local rows={
 {'Hungry','TraitHunger','hearty','hunger',1},
 {'Hungry','TraitHunger','fastMetabolism','hunger',2},
 {'Thirst','TraitThirst','highThirst','thirst',1},
 {'HeavyLoad','TraitLoad','weak','load',2},
 {'HeavyLoad','TraitLoad','feeble','load',2},
 {'HeavyLoad','TraitLoad','disorganized','load',2},
 {'HasACold','TraitCold','illness','coldSymptoms',1},
 {'Sick','TraitNausea','weakStomach','sick',1},
 {'FoodEaten','TraitFull','slowMetabolism','hunger',0},
 {'Darkness','TraitSight','shortSighted'},
 {'Threat','TraitVigilant','deaf'},
 {'Threat','TraitVigilant','hardHearing'},
 {'Threat','TraitVigilant','conspicuous'},
 {'Threat','TraitDriver','sunday'},
 }
 local out={}
 for _,r in ipairs(rows)do
  for _,hidden in ipairs({false,true})do
   local f={traits={[r[3]]=true},near=0,visible=0,recentThreat=false,sneaking=hidden,panic=0,endurance=1}
   if r[4] then f[r[4]]=r[5]end
   if r[1]=='Threat' then f.near=1;f.visible=1;f.accessibleNear=1;f.reactiveNear=0;f.targeted=0;f.traitDriver=r[3]=='sunday' end
   if r[1]=='Darkness' then f.outcome={kind='darkness',completed=true,after={awake=true,light=.1}}end
   out[#out+1]={name=r[3]..': '..(hidden and 'whisper' or 'normal'),group=r[1],level=1,max=4,state=f,prefs={safeSpeech=true,whisper=true},expect=r[2],mode='spoken',newTraits=true}
  end
 end
 return out
end
return T
