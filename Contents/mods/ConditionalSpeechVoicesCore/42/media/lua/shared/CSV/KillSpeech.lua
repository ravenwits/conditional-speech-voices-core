local K={}
function K.distressed(f)
 local contact=(f.directAttack or 0)>0
 return (f.panic or 0)>=3 or type(f.health)=='number' and f.health<=35
  or contact and ((f.endurance or 0)>=3 or (f.pain or 0)>=3 or (f.bleeding or 0)>=2)
end
function K.dark(f,experience)
 local t=f.traits or {}
 return experience=='practiced' and t.desensitized==true and (f.panic or 0)<=1
  and (f.unhappy or 0)<2 and (f.endurance or 0)<2 and (f.health or 0)>65 and not K.distressed(f)
end
function K.angry(f)return (f.anger or 0)>=2 and not K.distressed(f)end
function K.pool(f,experience)
 if K.distressed(f) then return 'KillDesperate' end
 if (f.traits or {}).pacifist and f.near==0 and f.visible==0 and not f.humanThreat then return 'TraitReluctant' end
 if K.angry(f) then return 'KillAngry' end
 if (f.unhappy or 0)>=3 or (f.traits or {}).cowardly and (f.panic or 0)>0 or (f.traits or {}).hemophobic and (f.bleeding or 0)>0 then return 'KillUneasy' end
 if K.dark(f,experience) then return 'KillDark' end
 if experience=='practiced' or (f.traits or {}).desensitized then return 'KillControlled' end
 return 'KillUneasy'
end
function K.allowed(id,f)
 if id:match('^KillAngry_') then return K.angry(f)end
 if id:match('^KillDark_') then return K.dark(f,f.psychology and f.psychology.experience)end
 local countIndex=tonumber(id:match('^KillCount_(%d+)$'))
 if countIndex then
  local e=f.psychology
  return e and e.kind=='zombieKill' and e.verified==true and f.zombieKills==({31,50,100,200})[countIndex]
   and not f.sneaking and not K.distressed(f) and (f.panic or 0)<=1 and (f.unhappy or 0)<2
   and (e.experience=='practiced' or (f.traits or {}).desensitized==true)
 end
 if id=='Kill_2' or id:match('^KillDesperate_') then
  if not K.distressed(f) then return false end
 end
 if id=='Kill_3' then return f.acute==true end
 if id=='KillControlled_1' or id=='KillDesperate_4' or id=='KillDesperate_5' then
  return (f.near or 0)>=2 or (f.visible or 0)>=2
 end
 return true
end
function K.choose(C,V,player,voice,f,experience)
 if not V.extended(voice) or not require('CSV/Extras').approved then return nil end
 local pool=K.pool(f,experience or require('CSV/Experience').level(player,'zombie'))
 -- Existing quiet takes remain available without turning concealed kills into shouts.
 if f.sneaking then
  if pool=='TraitReluctant' then
   local line=C.extraLine(player,voice,pool);if line then return line end
  end
  local id=pool=='KillDesperate' and 'Kill_2' or 'Kill_1'
  local data=V.bank(voice).data
  for _,line in ipairs(data.groups.Kill or {})do if line.id==id and V.clip(voice,id) and K.allowed(id,f) then return line end end
  return nil
 end
 local milestone=C.extraLine(player,voice,'KillCount',function(id)return K.allowed(id,f)end)
 if milestone and not require('CSV/SemanticSpeech').recent(C.history[player] or {},milestone,V.now()) then return milestone end
 local line=C.extraLine(player,voice,pool,function(id)return K.allowed(id,f)end)
 if pool=='KillDark' or pool=='KillAngry' then
  local semantic=require('CSV/SemanticSpeech');local h=C.history[player] or {}
  if not line or semantic.recent(h,line,V.now()) then
   local fallback=C.extraLine(player,voice,'KillControlled',function(id)return K.allowed(id,f)end)
   if fallback and (not line or semantic.stamp(h,fallback)<semantic.stamp(h,line))then line=fallback end
  end
 end
 if pool=='KillControlled' and require('CSV/Traits').dryCoping(f) then
  local dry=C.extraLine(player,voice,'DryCoping');local semantic=require 'CSV/SemanticSpeech'
  local history=C.history[player] or {}
  if dry and (not line or semantic.stamp(history,dry)<semantic.stamp(history,line)) then line=dry end
 end
 -- Pleading is a distressed fallback, after the broader set has been used.
 if pool=='KillDesperate' then
  local history=C.history[player] or {};local semantic=require 'CSV/SemanticSpeech'
  for _,legacy in ipairs(V.bank(voice).data.groups.Kill or {})do
   if legacy.id=='Kill_2' and K.allowed(legacy.id,f) and (not line or semantic.stamp(history,legacy)<semantic.stamp(history,line)) then line=legacy end
  end
 end
 return line
end
return K
