local T={}
local names={brave='BRAVE',cowardly='COWARDLY',desensitized='DESENSITIZED',agoraphobic='AGORAPHOBIC',claustrophobic='CLAUSTROPHOBIC',hemophobic='HEMOPHOBIC',smoker='SMOKER'}
function T.read(player)
 local result={}
 for name,constant in pairs(names)do
  local trait=CharacterTrait and CharacterTrait[constant]
  if trait then local ok,value=pcall(function()return player:hasTrait(trait)end);if ok and type(value)=='boolean' then result[name]=value end end
 end
 return result
end
function T.startle(s)
 local t=s.traits or {}
 -- Actual distress wins over a character-sheet preference. Do not add panic twice.
 if (s.panic or 0)>=3 then return 'StartleCowardly' end
 if t.desensitized then return 'StartleDesensitized' end
 if t.cowardly then return 'StartleCowardly' end
 if t.brave then return 'StartleBrave' end
 return 'StartleNormal'
end
function T.phobiaAllowed(group,s)
 local t=s.traits or {}
 if group=='Agoraphobic' then return t.agoraphobic~=false and s.outside~=false end
 if group=='Claustrophobic' then return t.claustrophobic~=false and s.outside~=true end
 return true
end
function T.context(group,s)
 local t=s.traits or {}
 if s.fire or require('CSV/Concealment').active(s) or (s.near or 0)>0 or s.humanThreat then return nil end
 if (group=='Stress' or group=='Panic') and t.hemophobic and (s.bleeding or 0)>0 and (s.panic or 0)>0 then return 'BloodAversion' end
 if group=='Stress' and t.smoker and (s.nicotineStress or 0)>0 then return 'NicotineNeed' end
 if group=='Endurance' and (s.endurance or 0)>=3 and s.sneaking==false and (s.pain or 0)==0 and (s.bleeding or 0)==0 and (s.drunk or 0)==0 and (s.coldSymptoms or 0)==0 then return 'ExhaustedCoping' end
end
function T.startleAllowed(id,s)
 local n=tonumber(id:match('_(%d+)$')) or 0
 if s.sneaking and not require('CSV/Concealment').active(s) then return n<=2 end
 if n>=7 and not require('CSV/Concealment').active(s) then return false end
 if id=='StartleCowardly_8' and (s.panic or 0)<3 then return false end
 return true
end
function T.dryCoping(s)
 local e=s.psychology;local t=s.traits or {}
 return e and e.verified and e.kind=='zombieKill' and e.experience=='practiced' and t.desensitized==true
  and s.sneaking==false and s.near==0 and s.visible==0 and s.recentThreat==false and not s.humanThreat and not s.fire
  and s.panic==0 and s.pain==0 and s.bleeding==0 and (s.endurance or 4)<2 and s.drunk==0 and s.coldSymptoms==0
end
return T
