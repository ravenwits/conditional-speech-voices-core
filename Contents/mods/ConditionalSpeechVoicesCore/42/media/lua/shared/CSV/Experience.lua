local E={fields={zombie=true,human=true,injury=true,raid=true}}
local sessions=setmetatable({},{__mode='k'})
local function count(value,limit)
 local n=tonumber(value)
 if not n or n~=n or n==math.huge or n==-math.huge then return 0 end
 return math.floor(math.max(0,math.min(limit or 100000,n)))
end
local function normalize(e)
 for field in pairs(E.fields)do e[field]=count(e[field])end
 e.zombieEncounters=count(e.zombieEncounters)
 e.humanEncounters=count(e.humanEncounters)
 e.nativeZombieKills=count(e.nativeZombieKills,2147483647)
 if type(e.historyUnknown)~='boolean' then e.historyUnknown=true end
 return e
end
function E.get(player)
 local md=player:getModData()
 local saved=md.csvExperience
 local e
 if type(saved)=='table' and saved.version~=nil and saved.version~=1 then
  -- A downgrade must not rewrite a newer schema. Keep only a session-local view.
  local session=sessions[player]
  if not session or session.source~=saved then
   session={source=saved,value={version=1,historyUnknown=true,unsupportedVersion=saved.version}}
   sessions[player]=session
  end
  e=session.value
 else
  sessions[player]=nil
  if type(saved)~='table' then saved={historyUnknown=true};md.csvExperience=saved end
  saved.version=1;e=saved
 end
 normalize(e)
 local native=require('CSV/Actors').call(player,'getZombieKills')
 if type(native)=='number' and native==native and native>=0 and native<math.huge then
  e.nativeZombieKills=count(native,2147483647)
 end
 return e
end
function E.snapshot(player)
 local e=E.get(player);local out={}
 for field in pairs(E.fields)do out[field]=e[field]end
 for _,field in ipairs({'version','nativeZombieKills','zombieEncounters','humanEncounters','historyUnknown','unsupportedVersion'})do out[field]=e[field]end
 return out
end
function E.mark(player,field)
 if not E.fields[field] then return end
 local e=E.get(player);e[field]=math.min(100000,e[field]+1)
end
function E.encounter(player,field)
 if field~='zombie' and field~='human' then return end
 local e=E.get(player);local key=field..'Encounters';e[key]=math.min(100000,e[key]+1)
end
function E.level(player,field)
 local e=E.get(player);local n=count(e[field])
 if field=='zombie' then n=math.max(n,e.nativeZombieKills)end
 if field=='zombie' or field=='human' then n=math.max(n,e[field..'Encounters'])end
 local familiar=require('CSV/PsychologyPolicy').familiarity[field] or 5
 return n>=familiar and 'practiced' or 'uncertain'
end
return E
