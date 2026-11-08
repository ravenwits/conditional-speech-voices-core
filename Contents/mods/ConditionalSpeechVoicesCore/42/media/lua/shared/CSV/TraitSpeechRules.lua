local R={groups={TraitRest='Tired',TraitWound='Pain',TraitFumble='Explore',TraitReading='Explore',TraitStudy='Explore',TraitFall='Explore',TraitScratch='Pain',TraitIlliterate='Explore'}}
local function above(value,min)return type(value)=='number' and value>=min end
function R.context(group,s)
 local t=s.traits or {}
 if s.fire or require('CSV/Concealment').active(s) or above(s.attacking,1) or s.humanThreat then return end
 if group=='Threat' and above(s.near,1) and s.panic==0 then
  if t.sunday and s.traitDriver==true then return 'TraitDriver' end
  if (t.deaf or t.hardHearing or t.conspicuous) and above(s.visible,1) then return 'TraitVigilant' end
 end
 if above(s.near,1) then return end
 if group=='Hungry' and (t.hearty or t.fastMetabolism) and above(s.hunger,1) and s.hunger<3 then return 'TraitHunger' end
 if group=='Thirst' and t.highThirst and above(s.thirst,1) and s.thirst<3 then return 'TraitThirst' end
 if group=='HeavyLoad' and (t.weak or t.feeble or t.disorganized) and above(s.load,1) and above(s.endurance,1) then return 'TraitLoad' end
 if group=='HasACold' and t.illness and above(s.coldSymptoms,1) then return 'TraitCold' end
 if group=='Sick' and t.weakStomach and above(s.sick,1) then return 'TraitNausea' end
 if group=='FoodEaten' and (t.lightEater or t.slowMetabolism) and s.hunger==0 then return 'TraitFull' end
 if group=='Darkness' and t.shortSighted and require('CSV/OutcomeRules').classify(s.outcome)=='Darkness' then return 'TraitSight' end
end
function R.classify(e)
 if not e or not e.verified or not e.completed or e.cancelled then return end
 local f=e.after or {};local t=f.traits or {};local g=e.traitGroup
 if not f.awake then return end
 if e.actionObject and f.actionObject~=e.actionObject then return end
 if e.cutAt and f.cutAt~=e.cutAt then return end
 if g=='TraitRest' and (t.restless or t.sleepy) and above(f.tired,2) then return g end
 if g=='TraitWound' and t.slowHealer and f.lingering then return g end
 if g=='TraitFumble' and t.allThumbs and f.action=='ISInventoryTransferAction' and above(f.visible,1) then return g end
 if g=='TraitReading' and t.slowReader and f.action=='ISReadABook' and above(f.stress,1) then return g end
 if g=='TraitStudy' and t.slowLearner and f.action=='ISResearchRecipe' then return g end
 if g=='TraitFall' and t.clumsy and f.falling==false then return g end
 if g=='TraitScratch' and t.thinSkin and f.recentCut then return g end
 if g=='TraitIlliterate' and t.illiterate and f.inspectLiterature then return g end
end
return R
