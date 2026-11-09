local M={repeatMs=90000,meaningRepeatMs=30000}
-- Only audited equivalents share a short cooldown. Needs keep their severity,
-- and danger/injury events are not placed behind this additional gate.
local meanings={StillAlive_1='survived',StillAlive_2='survived',StillAlive_3='survived',
 AfterZombieSteady_2='survived',InjuryAftermath_1='survived',InjuryAftermath_3='survived',
 Thirst_1='water1',Thirst_2='water2',Thirst_3='water3',NeedThirst_3='water3',
 ThirstCritical_1='water4',ThirstCritical_2='water4',ThirstCritical_3='water4',
 Hungry_1='food1',Hungry_2='food2',Hungry_3='food3',NeedHungry_4='food4',
 HungerSevere_1='food3',HungerSevere_2='food3',HungerSevere_3='food3'}
function M.meaning(line)return meanings[M.source(line.id)]end
function M.source(id)
 local nextId=require('CSV/Expressions').source(id) or id:match('^Whisper_(.+)$')
 if nextId and nextId~=id then return M.source(nextId)end
 return id
end
function M.key(line)
 -- Recorded wording, not event group, owns repetition across reused clips and deliveries.
 return 'text:'..(line.text or M.source(line.id)):lower():gsub('[%p%s]+',' ')
end
function M.stamp(history,line)
 return math.max(history[M.key(line)] or 0,history[M.source(line.id)] or 0,history[line.id] or 0)
end
function M.recent(history,line,now)
 local at=M.stamp(history,line)
 if at>0 and now>=at and now-at<M.repeatMs then return true end
 local meaning=M.meaning(line);local used=meaning and history['meaning:'..meaning]
 return used~=nil and now>=used and now-used<M.meaningRepeatMs
end
function M.allowed(line,f)
 local id=M.source(line.id)
 if id:match('^CriticalFading_') then return type(f.health)=='number' and f.health>0 and f.health<=25 end
 if id:match('^CriticalWound_') then return type(f.health)=='number' and f.health>0 and f.health<=25 and ((f.bleeding or 0)>0 or f.acute==true) end
 if not require('CSV/KillSpeech').allowed(id,f) then return false end
 if id=='InjuryAftermath_3' then return type(f.pain)=='number' and f.pain>0 end
 if id=='MortalFear_3' then return (f.endurance or 0)>=2 or (f.panic or 0)>=4 end
 return true
end
function M.shared(C,V,player,voice,line,group,f)
 if not line or not V.extended(voice) or not require('CSV/Extras').approved then return line end
 if (group=='Panic' or group=='PanicCallback') and (f.panic or 0)>=3 and require('CSV/Concealment').active(f) and not f.fire then
  local h=C.history[player] or {};local best=line;local stamp=M.stamp(h,line)
  for _,id in ipairs({'MortalFear_1','MortalFear_2','MortalFear_3'})do
   local candidate=V.bank(voice).extras.catalog[id]
   candidate=candidate and V.localize(voice,candidate)
   if candidate and V.clip(voice,id) and M.allowed(candidate,f) then
    local used=M.stamp(h,candidate)
    if used<stamp then best=candidate;stamp=used end
   end
  end
  return best
 end
 return line
end
function M.remember(h,line,now)
 h[M.key(line)]=now;h[M.source(line.id)]=now
 local meaning=M.meaning(line);if meaning then h['meaning:'..meaning]=now end
end
return M
