-- Provider modules return data; they must not require CSV/Core or CSV/Pack.
local R={providers={},rejected={},locked=false}
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a)do if not same(v,b[k]) then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function checkSemantics(bank,strict)
 local rules=require 'CSV/PackSemantics'
 for group,rows in pairs(bank.data.groups)do
  local expected=rules.groups[group]
  assert(expected or not strict,'Unknown group '..group)
  if expected then
   local ids={};for i,row in ipairs(rows)do ids[i]=row.id end
   assert(same(ids,expected),'Conflicting group '..group)
  end
 end
 for _,row in ipairs(bank.data.contextLines or {})do
  local expected=rules.contexts[row.id]
  assert(expected or not strict,'Unknown context '..tostring(row.id))
  if expected then
   local fields={};for k,v in pairs(row)do if k~='text' and k~='voice' then fields[k]=v end end
   assert(same(fields,expected),'Conflicting context '..row.id)
  end
 end
 local aliases={}
 for canonical,recording in pairs(bank.aliases or {})do
  assert(type(recording)=='string' and not aliases[recording],'Conflicting recording alias')
  assert(not bank.aliases[recording] or recording==canonical,'Chained recording alias')
  aliases[recording]=canonical
 end
 for _,provider in pairs(R.providers)do
  for canonical,recording in pairs(provider.bank.aliases or {})do
   assert(not aliases[recording] or aliases[recording]==canonical,'Conflicting recording alias '..recording)
  end
 end
 for _,kind in ipairs({'extras','whispers','expressions'})do
  for id,row in pairs(bank[kind].catalog)do
   local expected=rules[kind][id]
   assert(expected or not strict,'Unknown '..kind..' entry '..id)
   if expected then
    local fields={};for k,v in pairs(row)do if k~='text' then fields[k]=v end end
    assert(same(fields,expected),'Conflicting '..kind..' entry '..id)
   end
  end
 end
end
function R.register(mod,definition)
 assert(not R.locked,'Voice registry already loaded')
 assert(type(mod)=='string' and mod:match('^[%w_%-]+$'),'Invalid provider ID')
 assert(not R.providers[mod],'Duplicate provider '..mod)
 assert(type(definition)=='table' and definition.schema==1 and type(definition.bank)=='table' and type(definition.voices)=='table','Invalid provider schema')
 local b=definition.bank
 for _,k in ipairs({'data','extras','whispers','expressions','profanity','peaklimits'})do assert(type(b[k])=='table','Missing bank '..k)end
 assert(type(b.data.clips)=='table' and type(b.data.groups)=='table','Invalid bank data')
 for _,pair in ipairs({{'extras','catalog'},{'whispers','catalog'},{'expressions','catalog'},{'expressions','bySource'},{'profanity','ids'}})do assert(type(b[pair[1]][pair[2]])=='table','Invalid bank catalog')end
 assert(type(b.id)=='string' and type(b.language)=='string' and type(b.revision)=='string','Missing bank identity')
 checkSemantics(b,definition.contract~=nil)
 local ids,prefixes,builtins={},{},{}
 for _,p in pairs(R.providers)do for _,v in ipairs(p.voices)do ids[v.id]=true;if v.prefix then prefixes[v.prefix]=true end;if v.builtinPrefix then builtins[v.builtinPrefix]=true end end end
 for _,v in ipairs(definition.voices)do
  assert(type(v.id)=='string' and v.id:match('^[a-z][a-z0-9_]*$') and not ids[v.id],'Invalid or duplicate voice ID')
  assert(type(v.name)=='string','Missing voice name');ids[v.id]=true
  if v.builtinPrefix then
   assert((v.builtinPrefix=='VoiceMale' or v.builtinPrefix=='VoiceFemale') and not builtins[v.builtinPrefix],'Invalid or duplicate built-in voice binding')
   builtins[v.builtinPrefix]=true
  end
  if v.pitchOffset~=nil then assert(type(v.pitchOffset)=='number' and v.pitchOffset>=-4 and v.pitchOffset<=4,'Invalid pitch calibration') end
  for _,gain in pairs(v.deliveryGains or {})do assert(type(gain)=='number' and gain>0 and gain<=2,'Invalid delivery gain') end
  if not v.vanilla then
   assert(type(v.prefix)=='string' and v.prefix:match('^VoiceCSV%w+P$') and not prefixes[v.prefix],'Invalid or duplicate voice prefix')
   assert(v.base=='VoiceMale' or v.base=='VoiceFemale','Invalid base voice')
   assert(type(v.preview)=='string' and type(b.native)=='table' and type(b.lines)=='table','Missing native voice data')
   assert(type(b.native.suffixes)=='table' and type(b.native.replacements)=='table' and type(b.native.pain)=='table','Invalid native bank')
   assert(type(b.native.replacements.ShoutHey)=='table' and type(b.native.replacements.WhisperHey)=='table','Missing callout pools')
   prefixes[v.prefix]=true
  end
 end
 if definition.contract ~= nil then
  local errors = require('CSV/VoiceContract').check(definition)
  assert(#errors == 0, 'Incomplete voice contract: '..table.concat(errors, '; '))
 end
 R.providers[mod]=definition
end
return R
