-- Provider modules return data; they must not require CSV/Core or CSV/Pack.
local R={providers={},locked=false}
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
 local ids,prefixes={},{}
 for _,p in pairs(R.providers)do for _,v in ipairs(p.voices)do ids[v.id]=true;if v.prefix then prefixes[v.prefix]=true end end end
 for _,v in ipairs(definition.voices)do
  assert(type(v.id)=='string' and v.id:match('^[a-z][a-z0-9_]*$') and not ids[v.id],'Invalid or duplicate voice ID')
  assert(type(v.name)=='string','Missing voice name');ids[v.id]=true
  if not v.vanilla then
   assert(type(v.prefix)=='string' and v.prefix:match('^VoiceCSV%w+P$') and not prefixes[v.prefix],'Invalid or duplicate voice prefix')
   assert(v.base=='VoiceMale' or v.base=='VoiceFemale','Invalid base voice')
   assert(type(v.preview)=='string' and type(b.native)=='table' and type(b.lines)=='table','Missing native voice data')
   assert(type(b.native.suffixes)=='table' and type(b.native.replacements)=='table' and type(b.native.pain)=='table','Invalid native bank')
   assert(type(b.native.replacements.ShoutHey)=='table' and type(b.native.replacements.WhisperHey)=='table','Missing callout pools')
   prefixes[v.prefix]=true
  end
 end
 R.providers[mod]=definition
end
return R
