-- Severity comes from Moodle:getLevel through getMoodleLevel, never raw stats.
local M={slots={
 Hungry={'Hungry_1','Hungry_2','Hungry_3','NeedHungry_4'},
 Thirst={'Thirst_1','Thirst_2','NeedThirst_3','ThirstCritical_1'},
 Tired={'Tired_1','Tired_2','Tired_3','NeedTired_4'},
 Stress={'Stress_1','Stress_2','Stress_3','NeedStress_4'},
 Panic={'Panic_1','PanicGrounding_1','NeedPanic_3','NeedPanic_4'},
 Bored={'Bored_1','Bored_2','Bored_3','NeedBored_4'},
 Unhappy={'Unhappy_1','NeedUnhappy_2','Unhappy_3','NeedUnhappy_4'},
}}
function M.choose(V,voice,group,level,maximum,facts)
 local pool=M.slots[group]
 if not pool or maximum~=4 or not pool[level] then return nil end
 local bank=V.bank(voice)
 if bank.needTiers~=1 then return nil end
 local actual=(facts.levels or {})[group]
 if actual~=level then return nil end
 if group=='Panic' and (facts.fire or require('CSV/Concealment').active(facts)
  or ((facts.accessibleNear or facts.near or 0)>0 and (facts.visible or 0)>0)) then return nil end
 local id=pool[level]
 if not V.clip(voice,id) then return nil end
 return {id=id,group=group,text=bank.lines[id],needTier=level}
end
return M
