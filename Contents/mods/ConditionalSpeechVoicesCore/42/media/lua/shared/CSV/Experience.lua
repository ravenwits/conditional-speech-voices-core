local E={fields={zombie=true,human=true,injury=true,raid=true}}
function E.get(player)
 local md=player:getModData()
 if type(md.csvExperience)~='table' or md.csvExperience.version~=1 then
  md.csvExperience={version=1,zombie=0,human=0,injury=0,raid=0,historyUnknown=true}
 end
 local e=md.csvExperience
 local native=require('CSV/Actors').call(player,'getZombieKills')
 if type(native)=='number' and native==native and native>=0 and native<math.huge then
  e.nativeZombieKills=math.floor(native)
 end
 e.zombieEncounters=tonumber(e.zombieEncounters) or 0;e.humanEncounters=tonumber(e.humanEncounters) or 0
 return e
end
function E.mark(player,field)
 if not E.fields[field] then return end
 local e=E.get(player);e[field]=math.min(100000,math.max(0,tonumber(e[field]) or 0)+1)
end
function E.encounter(player,field)
 if field~='zombie' and field~='human' then return end
 local e=E.get(player);local key=field..'Encounters';e[key]=math.min(100000,e[key]+1)
end
function E.level(player,field)
 local e=E.get(player);local n=tonumber(e[field]) or 0
 if field=='zombie' then n=math.max(n,e.nativeZombieKills or 0)end
 if field=='zombie' or field=='human' then n=math.max(n,e[field..'Encounters'] or 0)end
 local familiar=require('CSV/PsychologyPolicy').familiarity[field] or 5
 return n>=familiar and 'practiced' or 'uncertain'
end
return E
