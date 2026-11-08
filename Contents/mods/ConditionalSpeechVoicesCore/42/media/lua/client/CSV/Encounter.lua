local E={players=setmetatable({},{__mode='k'})}
function E.reaction(group,s)
 if require('CSV/VehicleCombatRules').groups[group] and s.outcome and s.outcome.verified and (s.outcome.event=='crowd' or s.outcome.event=='siege') then return true end
 if group=='Psychology' and s.psychology and s.psychology.verified and (s.psychology.kind=='humanAttack' or s.psychology.kind=='raid') then return true end
 return group=='Startle' or (group=='Threat' or group=='Panic' or group=='PanicCallback') and not s.fire and ((s.near or 0)>0 or s.recentThreat==true or s.nativeAlert or require('CSV/Concealment').active(s))
end
function E.observe(p,s)
 local e=E.players[p]
 -- An empty current scan is not a new encounter. State retains recentThreat
 -- across brief occlusion; unknown evidence must not clear speech history.
 local clear=s.encounterThreat~=true and s.near==0 and s.visible==0 and s.recentThreat==false
 if e then
  local inactive=s.encounterThreat==false and s.near==0 and type(s.visible)=='number'
   and not s.nativeAlert and not e.soundPlaying and not s.humanThreat and not require('CSV/Concealment').active(s)
  if inactive then
   local now=require('CSV/Core').now();e.clearSince=e.clearSince or now
   clear=clear or now-e.clearSince>=10000
  else e.clearSince=nil end
  if clear and not s.nativeAlert and not e.soundPlaying and not s.humanThreat and not require('CSV/Concealment').active(s) then E.players[p]=nil;e=nil end
 end
 return e
end
local function attacking(s)
 return require('CSV/Concealment').active(s)
  or s.outcome and s.outcome.kind=='vehicle_combat' and s.outcome.verified and (s.outcome.attacks or 0)>0
end
function E.escalation(e,s)
 if not e or not e.reacted then return nil end
 if not e.escalated and (e.panic or 0)<3 and (s.panic or 0)>=3 and (s.panic or 0)-(e.panic or 0)>=2
  and ((s.near or 0)>0 or s.humanThreat==true or attacking(s)) then return 'panic_rise' end
 if not e.attackReacted and attacking(s) then return 'active_attack' end
end
function E.escalates(e,s)
 return E.escalation(e,s)~=nil
end
function E.blocked(p,group,s)
 local e=E.observe(p,s)
 if group=='Startle' and s.nativeAlert then
  return e and e.alertReacted==true or false
 end
 return E.reaction(group,s) and e and e.reacted==true and not E.escalates(e,s)
end
function E.record(p,group,s)
 if not E.reaction(group,s) then return end
 if group=='Startle' and s.nativeAlert then
  local alert=E.players[p] or {};E.players[p]=alert;alert.alertReacted=true
 end
 local e=E.players[p] or {};E.players[p]=e
 if E.escalation(e,s)=='panic_rise' then e.escalated=true end
 if attacking(s) then e.attackReacted=true end
 e.reacted=true;e.panic=math.max(e.panic or 0,s.panic or 0)
end
function E.sound(p,playing)
 local e=E.players[p]
 if playing then e=e or {};E.players[p]=e end
 if e then
  if playing and not e.soundPlaying then e.alertReacted=false end
  e.soundPlaying=playing
 end
end
return E
