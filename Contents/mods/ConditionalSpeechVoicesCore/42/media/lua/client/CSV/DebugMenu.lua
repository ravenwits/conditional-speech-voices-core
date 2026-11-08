local M={}
function M.speech(context)
 local label='Debug'
 local option=context.getOptionFromName and context:getOptionFromName(label)
 if not option and context.getOptionFromName then
  option=context:getOptionFromName(getText('ContextMenu_Debug'))
  if option then option.name=label end
 end
 local debugMenu=option and option.subOption and context:getSubMenu(option.subOption)
 if not debugMenu then
  option=option or context:addOption(label)
  debugMenu=ISContextMenu:getNew(context);context:addSubMenu(option,debugMenu)
 end
 local speechLabel='Conditional Voices'
 local existing=debugMenu.getOptionFromName and debugMenu:getOptionFromName(speechLabel)
 if existing and existing.subOption then return debugMenu:getSubMenu(existing.subOption) end
 local speech=debugMenu:addOption(speechLabel)
 local sub=ISContextMenu:getNew(debugMenu);debugMenu:addSubMenu(speech,sub)
 return sub
end
function M.healthRows(player,write,localize)
 local V=require 'CSV/Core'
 local registry=require 'CSV/Registry'
 local native=require 'CSV/NativeVoice'
 write('CORE '..V.version)
 local ids={};for id in pairs(registry.providers)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do
  local pack=registry.providers[id]
  write(id..' | '..pack.bank.revision..' | '..tostring(pack.contract or '-'))
  for _,voice in ipairs(pack.voices)do
   local state=native.failures[voice.id] or (native.installed[voice.id] and 'ready' or native.supported(voice.id) and 'pending' or 'unsupported')
   if localize and not native.failures[voice.id] then
    local labels={ready='UI_CSV_Short_Ready',pending='UI_CSV_PackPending',unsupported='UI_CSV_PackUnsupported'}
    state=getText(labels[state])
   end
   write(voice.name..' | '..state)
  end
 end
 for id,reason in pairs(registry.rejected)do write(id..' | '..reason) end
 if player then
  local last=require('CSV/Debug').last
  if last then write(last.group..' | '..last.outcome..' | '..tostring(last.policy or '-')) end
 end
end
function M.health(menu,player)
 local option=menu:addOption(getText('UI_CSV_PackHealth'))
 local sub=ISContextMenu:getNew(menu);menu:addSubMenu(option,sub)
 M.healthRows(player,function(text)local row=sub:addOption(text);row.notAvailable=true end,true)
end
return M
