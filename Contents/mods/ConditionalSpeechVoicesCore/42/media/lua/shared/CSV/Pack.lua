-- Require the provider explicitly: never depend on automatic Lua file order.
-- A missing/unsupported bank leaves upstream text speech working without audio.
local empty={id=false,language=false,schema=1,revision=false,
 data={groups={},clips={},contextLines={}},extras={approved=false,catalog={}},
 whispers={approved=false,catalog={}},expressions={approved=false,catalog={},bySource={}},
 profanity={ids={}},peaklimits={}}
local R=require 'CSV/Registry'
local function loadBank(mod,module,id,language)
 if type(getActivatedMods)=='function' then
  local ok,active=pcall(function()return getActivatedMods():contains(mod)end)
  if ok and not active then return nil end
 end
 local ok,b=pcall(require,module)
 if not ok or type(b)~='table' or b.schema~=1 or b.id~=id or b.language~=language or type(b.revision)~='string' then R.rejected[mod]='manifest_unavailable_or_invalid';return nil end
 for _,key in ipairs({'data','extras','whispers','expressions','profanity','peaklimits'})do if type(b[key])~='table' then R.rejected[mod]='invalid_bank';return nil end end
 if type(b.data.groups)~='table' or type(b.data.clips)~='table' or type(b.extras.catalog)~='table' or type(b.whispers.catalog)~='table' or type(b.expressions.catalog)~='table' or type(b.profanity.ids)~='table' then R.rejected[mod]='invalid_bank';return nil end
 return b
end
local function provider(mod,module)
 local ok,definition=pcall(require,module)
 if not ok then R.rejected[mod]='manifest_unavailable_or_invalid';return end
 local valid,err=pcall(R.register,mod,definition)
 if not valid then R.rejected[mod]=tostring(err):sub(1,240);print('[CSV] Rejected provider '..mod..': '..R.rejected[mod])end
end
-- Legacy packs remain loadable while subscribers receive updates separately.
local en=loadBank('Conditional-Speech-Voices-English','CSV_EN/Manifest','csv.en','EN')
local tr=loadBank('Conditional-Speech-Voices-Turkish','CSV_TR/Manifest','csv.tr','TR')
for _,entry in ipairs({
 {'Conditional-Speech-Voices-English',en},
 {'Conditional-Speech-Voices-Turkish',tr},
}) do
 local mod,providerBank=entry[1],entry[2]
 if providerBank then
  local ok,err=pcall(R.register,mod,{schema=1,contract=providerBank.contract,bank=providerBank,voices=providerBank.voices})
  if not ok then R.rejected[mod]=tostring(err):sub(1,240);print('[CSV] Rejected provider '..mod..': '..R.rejected[mod]) end
 end
end
if type(getActivatedMods)=='function' then
 local active=getActivatedMods()
 if active and active.size and active.get then
  local ids={};for i=0,active:size()-1 do ids[#ids+1]=active:get(i)end;table.sort(ids)
  for _,id in ipairs(ids)do if not R.providers[id] and id:match('^CSV%-Voice%-[%w_%-]+$')then provider(id,'CSV_Packs/'..id)end end
 end
end
R.locked=true
local bank={};for k,v in pairs(empty)do bank[k]=v end
bank.extraVoices={};bank.voices={};bank.voiceBanks={};bank.voiceOrder={};bank.hasCustomVoices=false;bank.semanticAliases={}
local keys={};for id in pairs(R.providers)do keys[#keys+1]=id end;table.sort(keys)
for _,id in ipairs(keys)do
 local p=R.providers[id]
 for canonical,recording in pairs(p.bank.aliases or {})do bank.semanticAliases[recording]=canonical end
 if bank.id==false then for k,v in pairs(p.bank)do bank[k]=v end end
 for _,v in ipairs(p.voices)do
  bank.voices[v.id]=v;bank.voiceBanks[v.id]=p.bank;bank.voiceOrder[#bank.voiceOrder+1]=v.id
  if not v.vanilla then bank.extraVoices[v.id]=p.bank;bank.hasCustomVoices=true end
 end
end
-- Merge into fresh tables, never into a provider's own bank.
for _,field in ipairs({'data','extras','whispers','expressions','profanity','peaklimits'})do
 local copy={};for k,v in pairs(bank[field])do copy[k]=v end;bank[field]=copy
 if copy.approved~=nil then
  copy.approved=false
  for _,id in ipairs(keys)do if R.providers[id].bank[field].approved then copy.approved=true;break end end
 end
 local fields=field=='data' and {'clips','groups'} or field=='expressions' and {'catalog','bySource'} or (field=='extras' or field=='whispers') and {'catalog'} or field=='profanity' and {'ids'} or {}
 for _,f in ipairs(fields)do local merged={};for _,id in ipairs(keys)do for k,v in pairs(R.providers[id].bank[field][f] or {})do if merged[k]==nil then merged[k]=v end end end;copy[f]=merged end
 if field=='peaklimits' then for _,id in ipairs(keys)do for k,v in pairs(R.providers[id].bank.peaklimits)do copy[k]=v end end end
end
return bank
