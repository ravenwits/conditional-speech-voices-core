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
local R=require 'CSV/Registry'
local function provider(mod,module)
 local ok,definition=pcall(require,module)
 if ok then local valid,err=pcall(R.register,mod,definition);if not valid then print('[CSV] Rejected provider '..mod..': '..tostring(err))end end
end
-- Legacy packs remain loadable while subscribers receive updates separately.
local en=loadBank('Conditional-Speech-Voices-English','CSV_EN/Manifest','csv.en','EN')
local tr=loadBank('Conditional-Speech-Voices-Turkish','CSV_TR/Manifest','csv.tr','TR')
if en then R.register('Conditional-Speech-Voices-English',{schema=1,bank=en,voices={{id='bob',name='Bob (US)',vanilla=true},{id='kate',name='Kate (US)',vanilla=true}}})end
if tr then
 local voices={{id='alp',styleName='CSV_Alp_Turkish',name='Alp (Turkish)',prefix='VoiceCSVAlpP',base='VoiceMale',preview='AlpPanicGrounding_1'}}
 if tr.mujdeComplete then voices[#voices+1]={id='mujde',styleName='CSV_Mujde_Turkish',name='Mujde (Turkish)',prefix='VoiceCSVMujdeP',base='VoiceFemale',preview='AlpPanicGrounding_1'}end
 R.register('Conditional-Speech-Voices-Turkish',{schema=1,bank=tr,voices=voices})
end
if type(getActivatedMods)=='function' then
 local active=getActivatedMods()
 if active and active.size and active.get then
  local ids={};for i=0,active:size()-1 do ids[#ids+1]=active:get(i)end;table.sort(ids)
  for _,id in ipairs(ids)do if not R.providers[id] and id:match('^CSV%-Voice%-[%w_%-]+$')then provider(id,'CSV_Packs/'..id)end end
 end
end
R.locked=true
local bank={};for k,v in pairs(en or tr or empty)do bank[k]=v end
bank.extraVoices={};bank.voices={};bank.voiceOrder={}
local keys={};for id in pairs(R.providers)do keys[#keys+1]=id end;table.sort(keys)
for _,id in ipairs(keys)do
 local p=R.providers[id]
 if bank.id==false then for k,v in pairs(p.bank)do bank[k]=v end end
 for _,v in ipairs(p.voices)do
  bank.voices[v.id]=v;bank.voiceOrder[#bank.voiceOrder+1]=v.id
  if not v.vanilla then bank.extraVoices[v.id]=p.bank end
 end
end
-- Merge into fresh tables, never into a provider's own bank.
for _,field in ipairs({'data','extras','whispers','expressions','profanity','peaklimits'})do
 local copy={};for k,v in pairs(bank[field])do copy[k]=v end;bank[field]=copy
 local fields=field=='data' and {'clips','groups'} or field=='expressions' and {'catalog','bySource'} or (field=='extras' or field=='whispers') and {'catalog'} or field=='profanity' and {'ids'} or {}
 for _,f in ipairs(fields)do local merged={};for _,id in ipairs(keys)do for k,v in pairs(R.providers[id].bank[field][f] or {})do if merged[k]==nil then merged[k]=v end end end;copy[f]=merged end
 if field=='peaklimits' then for _,id in ipairs(keys)do for k,v in pairs(R.providers[id].bank.peaklimits)do copy[k]=v end end end
end
return bank
