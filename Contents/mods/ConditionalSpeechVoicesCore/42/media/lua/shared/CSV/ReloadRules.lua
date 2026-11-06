local R={groups={ReloadPanic=true,ReloadBreathless=true,ReloadSteady=true,ReloadShaken=true}}
function R.group(f)
 local active=require('CSV/Concealment').active(f)
 local threat=active or (f.near or 0)>0 and (f.visible or 0)>0 or f.humanThreat==true
 if not threat then return nil,'no_verified_threat' end
 if f.fire then return nil,'on_fire' end
 if f.sneaking and not active then return nil,'concealed' end
 if (f.endurance or 0)>=3 then return 'ReloadBreathless' end
 if (f.panic or 0)>=4 then return 'ReloadPanic' end
 if (f.unhappy or 0)>=3 and (f.stress or 0)>=2 then return 'ReloadShaken' end
 local traits=f.traits or {}
 if (traits.brave or traits.desensitized) and (f.panic or 0)<3 then return 'ReloadSteady' end
 if (f.panic or 0)>=2 then return 'ReloadPanic' end
 return 'ReloadSteady'
end
function R.allowed(id,event)
 return not (id=='ReloadPanic_3' and event and event.insert)
end
return R
