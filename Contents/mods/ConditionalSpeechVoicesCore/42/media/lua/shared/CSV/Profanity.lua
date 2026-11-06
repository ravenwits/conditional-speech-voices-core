local pack=require 'CSV/Pack'
local P=pack.profanity
function P.allowed(id,prefs,voice)
 local bank=voice and pack.extraVoices[voice]
 local ids=bank and bank.profanity.ids or P.ids
 return not prefs or prefs.profanity~=false or ids[id]~=true
end
return P
