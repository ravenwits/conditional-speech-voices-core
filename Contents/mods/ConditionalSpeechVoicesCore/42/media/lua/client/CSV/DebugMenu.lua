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
 local speechLabel=getText('UI_CSV_DebugMenu')
 local existing=debugMenu.getOptionFromName and debugMenu:getOptionFromName(speechLabel)
 if existing and existing.subOption then return debugMenu:getSubMenu(existing.subOption) end
 local speech=debugMenu:addOption(speechLabel)
 local sub=ISContextMenu:getNew(debugMenu);debugMenu:addSubMenu(speech,sub)
 return sub
end
return M
