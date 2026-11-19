local Traits=require 'CSV/Traits'
local matches=Traits.matches
local R={groups={TraitRest='Tired',TraitWound='Pain',TraitFumble='Explore',TraitReading='Explore',TraitStudy='Explore',TraitFall='Explore',TraitScratch='Pain',TraitIlliterate='Explore'}}

-- A completed activity can have just a trait-specific recording. The game does
-- not require a generic take or start an activity on behalf of the character.
R.specialistRoutines={
 CropHarvested={acting="calm",forTraits={GARDENER="Gardener"}},
 FishCaught={acting="relieved",forTraits={FISHING="Angler"}},
 TraitGlasswork={acting="calm",forTraits={ARTISAN="Artisan"}},
 TraitForgeWork={acting="calm",forTraits={BLACKSMITH="Blacksmith Knowledge", BLACKSMITH2="Blacksmith Knowledge"}},
 TraitMasonry={acting="calm",forTraits={MASON="Mason"}},
 TraitWhittling={acting="calm",forTraits={WHITTLER="Whittler"}},
}

local controlledTakes={}
local traitTakes={}
local variantById={}
local coverage=require('CSV/VoiceCoverage').pools
local function addSource(source,id)
 local list=traitTakes[source] or {}
 traitTakes[source]=list
 table.insert(list,id)
end
for id,entry in pairs(require('CSV/VoiceAlternates'))do
 if entry.traitControlled then
  local group=controlledTakes[entry.group] or {normal={},whisper={}}
  controlledTakes[entry.group]=group
  table.insert(group[entry.delivery],id)
 elseif entry.forTraits then
  variantById[id]=entry
  addSource(entry.source,id)
  -- In a sparse pack another approved recording can cover the same meaning.
  -- Wet uses distinct intensities, even within its general coverage pool.
  if entry.group~='Wet' then
   for _,slot in ipairs(coverage[entry.group..'|{}'] or {})do
    local source=entry.delivery=='whisper' and 'Whisper_'..slot or slot
    if source~=entry.source then addSource(source,id) end
   end
  end
 end
end

for group,entry in pairs(R.specialistRoutines)do
 local id=group..'_1'
 variantById[id]={group=group,source=id,forTraits=entry.forTraits}
 addSource(id,id)
end

local function qualifies(player,entry,f)
 if entry.traitCondition=='panic' and (f.panic or 0)<3 then return false end
 if entry.traitCondition=='visible' and (f.visible or 0)<1 then return false end
 for key in pairs(entry.forTraits)do
  local constant=CharacterTrait and CharacterTrait[key]
  if constant and require('CSV/Actors').call(player,'hasTrait',constant)==true then return true end
 end
 return false
end

function R.preferredRecording(V,player,voice,source,f,history,prefs)
 -- Fear or exertion can already have changed the delivery of a panic line.
 -- Illness, intoxication and whispering retain their own audible delivery.
 if source:match('^Expr_') then
  local expression=V.bank(voice).expressions.catalog[source]
  if expression and expression.source:match('^PanicEscape_') and
   (expression.profile=='frightened' or expression.profile=='breathless') then source=expression.source end
 end
 local choices=traitTakes[source]
 if not choices or f.fire or not V.extended(voice) then return nil end
 local semantic=require 'CSV/SemanticSpeech'
 local best,stamp
 for _,id in ipairs(choices)do
  local entry=variantById[id]
  if (source==entry.source or not V.clip(voice,entry.source)) and V.clip(voice,id) and qualifies(player,entry,f) and require('CSV/Profanity').allowed(id,prefs,voice) then
   local line=V.localize(voice,{id=id,group=entry.group})
   if line and semantic.allowed(line,f) and not semantic.recent(history,line,V.now()) then
    local used=semantic.stamp(history,line)
    if not best or used<stamp or used==stamp and id<best.id then best,stamp=line,used end
   end
  end
 end
 return best
end

-- These existing recordings work in older packs and when an optional take is absent.
R.controlledFallbacks={closeThreat='ThreatTense_2',safePanic='PanicGrounding_2'}
local function controlledFallback(line,f)
 if line.group=='MortalFear' or line.group=='ContextPanicEscape' then
  return R.controlledFallbacks.closeThreat
 end
 if line.group=='Panic' and (f.panic or 0)>=3 then
  if require('CSV/Safety').settled(f) then return R.controlledFallbacks.safePanic end
  if f.threatKind=='attacking' or f.threatKind=='targeting' or f.threatKind=='approaching' then
   return R.controlledFallbacks.closeThreat
  end
 end
end

function R.controlledTake(V,C,player,voice,line,f,delivery)
 if not line or f.fire or not V.extended(voice) or not Traits.prefersControlledSpeech(f) then return nil end
 local takes=controlledTakes[line.group]
 local fallback=controlledFallback(line,f)
 if not takes and not fallback then return nil end
 local history=C.history[player] or {}
 local semantic=require('CSV/SemanticSpeech')
 local profanity=require('CSV/Profanity')
 local prefs=C.preferences()
 local best,stamp
 for _,id in ipairs(takes and takes[delivery] or {})do
  if V.clip(voice,id) and profanity.allowed(id,prefs,voice) then
   local take=V.localize(voice,{id=id,group=line.group})
   if take then
    local used=semantic.stamp(history,take)
    if not best or used<stamp or used==stamp and id<best.id then best,stamp=take,used end
   end
  end
 end
 if best or not fallback then return best end
 local id=delivery=='whisper' and ('Whisper_'..fallback) or fallback
 if V.clip(voice,id) and profanity.allowed(id,prefs,voice) then
  return V.localize(voice,{id=id,group=line.group})
 end
end

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
