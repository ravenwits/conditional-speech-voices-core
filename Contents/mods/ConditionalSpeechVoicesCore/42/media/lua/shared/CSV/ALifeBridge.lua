local B={status='not_checked'}
function B.install(observer)
 local executor=ProjectALife and ProjectALife.Executor
 if not executor or type(executor.woundPlayer)~='function' then B.status='absent';return false,'optional A-Life unavailable' end
 local version=ProjectALife.Interop and ProjectALife.Interop.VERSION
 if version and version~=1 then B.status='unsupported';return false,'unsupported A-Life interop version '..tostring(version) end
 local ok,err=require('CSV/Connections').install('alife-wound',function(t)
  local original=executor.woundPlayer
  t:replace(executor,'woundPlayer',function(victim,weaponType,weapon,part,attacker)
   local result=original(victim,weaponType,weapon,part,attacker)
   if result==true and require('CSV/Actors').isNpc(attacker) then
    require('CSV/Observers').run('alife.attack',observer.attack,observer,victim,attacker)
   end
   return result
  end)
 end)
 executor._csvWoundObserved=ok
 B.status=ok and 'installed' or 'failed';B.lastError=err
 return ok,err
end
return B
