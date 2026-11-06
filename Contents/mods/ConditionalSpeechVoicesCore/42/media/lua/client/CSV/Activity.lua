local A={}
local eating={ISEatFoodAction=true,ISDrinkFromBottle=true,ISDrinkFluidAction=true}
function A.read(p)
 if not p then return nil end
 if p.isAsleep then local ok,v=pcall(p.isAsleep,p);if ok and v then return 'sleeping' end end
 local q=ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[p]
 local current=q and q.current
 if current and (eating[current.Type] or current.Type=='ISTakeWaterAction' and current.item==nil) then return 'consuming' end
end
function A.block(p,private,preview)
 local state=A.read(p)
 if state=='sleeping' then return 'sleeping' end
 if state=='consuming' and not private and not preview then return 'consuming' end
end
return A
