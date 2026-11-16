local matches=require('CSV/Traits').matches
local R={groups={TraitRest='Tired',TraitWound='Pain',TraitFumble='Explore',TraitReading='Explore',TraitStudy='Explore',TraitFall='Explore',TraitScratch='Pain',TraitIlliterate='Explore'}}
local function above(value,min)return type(value)=='number' and value>=min end
function R.context(group,s)
 local t=s.traits or {}
 if s.fire or require('CSV/Concealment').active(s) or above(s.attacking,1) or s.humanThreat then return end
 if group=='Threat' and above(s.near,1) and s.panic==0 then
  if matches('TraitDriver',t) and s.traitDriver==true then return 'TraitDriver' end
  if matches('TraitVigilant',t) and above(s.visible,1) then return 'TraitVigilant' end
 end
 if above(s.near,1) then return end
 if group=='Hungry' and matches('TraitHunger',t) and above(s.hunger,1) and s.hunger<3 then return 'TraitHunger' end
 if group=='Thirst' and matches('TraitThirst',t) and above(s.thirst,1) and s.thirst<3 then return 'TraitThirst' end
 if group=='HeavyLoad' and matches('TraitLoad',t) and above(s.load,1) and above(s.endurance,1) then return 'TraitLoad' end
 if group=='HasACold' and matches('TraitCold',t) and above(s.coldSymptoms,1) then return 'TraitCold' end
 if group=='Sick' and matches('TraitNausea',t) and above(s.sick,1) then return 'TraitNausea' end
 if group=='FoodEaten' and matches('TraitFull',t) and s.hunger==0 then return 'TraitFull' end
 if group=='Darkness' and matches('TraitSight',t) and require('CSV/OutcomeRules').classify(s.outcome)=='Darkness' then return 'TraitSight' end
end
function R.classify(e)
 if not e or not e.verified or not e.completed or e.cancelled then return end
 local f=e.after or {};local t=f.traits or {};local g=e.traitGroup
 if not f.awake then return end
 if e.actionObject and f.actionObject~=e.actionObject then return end
 if e.cutAt and f.cutAt~=e.cutAt then return end
 if g=='TraitRest' and matches(g,t) and above(f.tired,2) then return g end
 if g=='TraitWound' and matches(g,t) and f.lingering then return g end
 if g=='TraitFumble' and matches(g,t) and f.action=='ISInventoryTransferAction' and above(f.visible,1) then return g end
 if g=='TraitReading' and matches(g,t) and f.action=='ISReadABook' and above(f.stress,1) then return g end
 if g=='TraitStudy' and matches(g,t) and f.action=='ISResearchRecipe' then return g end
 if g=='TraitFall' and matches(g,t) and f.falling==false then return g end
 if g=='TraitScratch' and matches(g,t) and f.recentCut then return g end
 if g=='TraitIlliterate' and matches(g,t) and f.inspectLiterature then return g end
end
return R
