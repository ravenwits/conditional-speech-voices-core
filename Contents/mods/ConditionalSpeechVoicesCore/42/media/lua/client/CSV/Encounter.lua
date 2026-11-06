local E={players=setmetatable({},{__mode='k'})}
function E.reaction(group,s)
 if require('CSV/VehicleCombatRules').groups[group] and s.outcome and s.outcome.verified and (s.outcome.event=='crowd' or s.outcome.event=='siege') then return true end
 if group=='Psychology' and s.psychology and s.psychology.verified and (s.psychology.kind=='humanAttack' or s.psychology.kind=='raid') then return true end
 return group=='Startle' or (group=='Threat' or group=='Panic' or group=='PanicCallback') and not s.fire and ((s.near or 0)>0 or s.recentThreat==true or s.nativeAlert or require('CSV/Concealment').active(s))
end
function E.observe(p,s)
 local e=E.players[p]
 local clear=s.encounterThreat==false or s.encounterThreat==nil and s.near==0 and s.visible==0 and s.recentThreat==false
 if e and clear and not s.nativeAlert and not e.soundPlaying and not s.humanThreat and not require('CSV/Concealment').active(s) then E.players[p]=nil;e=nil end
 return e
end
function E.escalates(e,s)
 return e and e.reacted and not e.escalated and (e.panic or 0)<3 and (s.panic or 0)>=3 and (s.panic or 0)-(e.panic or 0)>=2 and (require('CSV/Concealment').active(s) or s.outcome and s.outcome.kind=='vehicle_combat' and s.outcome.verified and (s.outcome.attacks or 0)>0)
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
 local e=E.players[p] or {};E.players[p]=e;if E.escalates(e,s) then e.escalated=true end;e.reacted=true;e.panic=math.max(e.panic or 0,s.panic or 0)
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
