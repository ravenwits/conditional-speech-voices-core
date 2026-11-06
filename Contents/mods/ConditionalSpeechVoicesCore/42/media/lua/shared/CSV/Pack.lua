-- Require the provider explicitly: never depend on automatic Lua file order.
-- A missing/unsupported bank leaves upstream text speech working without audio.
local empty={id=false,language=false,schema=1,revision=false,
 data={groups={},clips={},contextLines={}},extras={approved=false,catalog={}},
 whispers={approved=false,catalog={}},expressions={approved=false,catalog={},bySource={}},
 profanity={ids={}},peaklimits={}}
local function loadBank(mod,module,id,language)
 if type(getActivatedMods)=='function' then
  local ok,active=pcall(function()return getActivatedMods():contains(mod)end)
  if ok and not active then return nil end
 end
 local ok,b=pcall(require,module)
 if not ok or type(b)~='table' or b.schema~=1 or b.id~=id or b.language~=language or type(b.revision)~='string' then return nil end
 for _,key in ipairs({'data','extras','whispers','expressions','profanity','peaklimits'})do if type(b[key])~='table' then return nil end end
 if type(b.data.groups)~='table' or type(b.data.clips)~='table' or type(b.extras.catalog)~='table' or type(b.whispers.catalog)~='table' or type(b.expressions.catalog)~='table' or type(b.profanity.ids)~='table' then return nil end
 return b
end
local en=loadBank('Conditional-Speech-Voices-English','CSV_EN/Manifest','csv.en','EN')
local tr=loadBank('Conditional-Speech-Voices-Turkish','CSV_TR/Manifest','csv.tr','TR')
local bank=en or tr or empty
bank.extraVoices=tr and {alp=tr} or {}
if tr and tr.mujdeComplete then bank.extraVoices.mujde=tr end
if en and tr then
 for _,pair in ipairs({{en.data.clips,tr.data.clips},{en.extras.catalog,tr.extras.catalog},{en.whispers.catalog,tr.whispers.catalog},{en.profanity.ids,tr.profanity.ids},{en.peaklimits,tr.peaklimits}})do
  for key,value in pairs(pair[2])do if pair[1][key]==nil then pair[1][key]=value end end
 end
end
return bank
