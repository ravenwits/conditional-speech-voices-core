local F={}
function F.normalize(option)
 -- The game loader stores old slider records in value, combo records in selected.
 -- Keep the same option ID so existing choices survive the control change.
 local old=option.value
 if type(old)=='number' and old==old then
  option.selected=math.max(0,math.min(2,math.floor(old)))+1
  option.value=nil
 end
 local selected=option.selected
 if type(selected)~='number' or selected~=selected or selected<1 or selected>3 or selected~=math.floor(selected) then option.selected=2 end
 return option.selected-1
end
function F.create(options)
 local option=options:getOption('talkFrequency')
 if not option then
  option=options:addComboBox('talkFrequency',getText('UI_CSV_Option_18'),getText('UI_CSV_Option_19'))
  option:addItem(getText('UI_CSV_Option_13'));option:addItem(getText('UI_CSV_Option_14'),true);option:addItem(getText('UI_CSV_Option_15'))
 end
 return option
end
return F
