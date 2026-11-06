local H={quietRadius=4}
local function finite(v)return type(v)=='number' and v==v and v>=0 and v<100 end
function H.fallback()
 local option=SandboxVars and SandboxVars.ZombieLore and SandboxVars.ZombieLore.Hearing
 -- Verified against 42.21 WorldSoundManager. Random/unknown uses the most sensitive case.
 return option==2 and 1 or option==3 and .45 or 3
end
function H.multiplier(zombie)
 if getWorldSoundManager then
  local ok,value=pcall(function()return getWorldSoundManager():getHearingMultiplier(zombie)end)
  if ok and finite(value)then H.lastSource='engine';return value,'engine' end
 end
 H.lastSource='sandbox_fallback';return H.fallback(),'sandbox_fallback'
end
function H.radius(body,kind,source)
 if kind~='zombie' then return source or H.quietRadius end
 local multiplier=H.multiplier(body)
 return (source or H.quietRadius)*multiplier
end
return H
