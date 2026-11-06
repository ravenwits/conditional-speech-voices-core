local H={}
function H.bind(options)
 for _,o in ipairs(options.data or {})do
  local c=o.element
  if c and o.tooltip then
   if o.type=='combobox' and c.setToolTipMap then local tips={};for _,v in ipairs(o.values)do tips[v]=o.tooltip end;c:setToolTipMap(tips)
   elseif o.type=='slider' and not c.csvHelp then
    local text=o.tooltip;c.csvHelp=true;c.toolTipText=text;c.doToolTip=false
    local original=c.prerender
    c.prerender=function(self,...)
     if original then original(self,...)end
     if self:isMouseOver() then
      if not self.csvTooltip then self.csvTooltip=ISToolTip:new();self.csvTooltip:initialise();self.csvTooltip:setOwner(self);self.csvTooltip.maxLineWidth=420 end
      local t=self.csvTooltip;t.description=text;t:addToUIManager();t:setVisible(true);t:bringToTop()
     elseif self.csvTooltip then self.csvTooltip:setVisible(false);self.csvTooltip:removeFromUIManager()end
    end
   else c.tooltip=o.tooltip end
  end
 end
end
function H.apply(options)
 for _,o in ipairs(options.data or {})do if type(o.tooltip)=='string' then o.tooltip=o.tooltip:gsub('%. ','. <LINE> ')end end
 if MainOptions and not MainOptions.csvHelpInstalled then
  MainOptions.csvHelpInstalled=true;local original=MainOptions.addModOptionsPanel
  MainOptions.addModOptionsPanel=function(self,...)
   local result=original(self,...);H.bind(options);return result
  end
 end
end
return H
