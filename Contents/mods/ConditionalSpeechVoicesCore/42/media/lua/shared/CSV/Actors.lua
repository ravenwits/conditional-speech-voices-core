local A={}
local Diagnostics=require 'CSV/ApiDiagnostics'
function A.call(o,k,...)
 if o==nil then return nil end
 local ok,fn=pcall(function()return o[k]end)
 if not ok then Diagnostics.failure('lookup.'..k,fn);return nil end
 if fn==nil then return nil end
 local good,v=pcall(fn,o,...)
 if good then return v end
 Diagnostics.failure('call.'..k,v)
end
function A.isNpc(o)
 local interop=ProjectALife and ProjectALife.Interop
 if interop and interop.isNpc then local ok,v=pcall(interop.isNpc,o);if ok and v then return true end end
 local d=A.call(o,'getModData')
 if type(d)=='table' and (d.ProjectALifeOwned==true or d.ProjectALifeActor==true) then return true end
 local v=A.call(o,'getVariableString','ALifeActor');return v==true or v=='true'
end
function A.kind(o)
 if not o then return 'unknown' end
 if A.isNpc(o) then return 'npc' end
 local function is(c)local ok,v=pcall(function()return instanceof(o,c)end);return ok and v==true end
 if is('IsoPlayer') then return 'player' end
 if is('IsoZombie') then return 'zombie' end
 return 'unknown'
end
function A.key(o)
 if A.isNpc(o) then
  local d=A.call(o,'getModData') or {};local uid=d.ProjectALifeUID or A.call(o,'getVariableString','ALifeUID')
  local generation=d.ProjectALifeGeneration or A.call(o,'getVariableString','ALifeGeneration')
  if uid and generation then return 'npc:'..tostring(uid)..':'..tostring(generation) end
 end
 local id=A.call(o,'getOnlineID');if type(id)=='number' and id>=0 then return A.kind(o)..':'..id end
 return nil
end
return A
