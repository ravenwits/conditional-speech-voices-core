-- A transient UI control. The descriptor belongs to the saved character;
-- this option must never become a global ModOptions preference.
local M={}
local function current()
 local p=getPlayer and getPlayer()
 if not p or not p:isLocalPlayer() or p:isDead() then return nil end
 local d=p:getDescriptor()
 if not d or not d.getVoicePitch or not d.setVoicePitch then return nil end
 return p,d
end
function M.sync()
 local o=M.option;if not o then return end
 local p,d=current();M.owner=p
 o:setEnabled(p~=nil)
 o:setValue(d and d:getVoicePitch() or 0)
end
function M.apply(value)
 local p,d=current()
 if not p or p~=M.owner or not require('CSV/Core').finite(value) then return false end
 d:setVoicePitch(math.floor(math.max(-100,math.min(100,value))+.5))
 require('CSV/NativeVoice').safeApply(p)
 return true
end
function M.install(options)
 local o=options:getOption('characterPitch') or options:addSlider('characterPitch',getText('UI_CSV_PitchOffset'),-100,100,1,0,getText('UI_CSV_PitchOffsetHelp'))
 M.option=o
 -- Vanilla serializes only entries with getValue. The UI uses value directly.
 o.getValue=nil
 o.onChangeApply=function(_,value)M.apply(value)end
 if MainOptions and not MainOptions.csvCharacterPitch then
  MainOptions.csvCharacterPitch=true
  local build=MainOptions.addModOptionsPanel
  MainOptions.addModOptionsPanel=function(self,...)
   local result=build(self,...);M.sync();return result
  end
  local toUI=MainOptions.toUI
  MainOptions.toUI=function(self,...)
   M.sync();return toUI(self,...)
  end
 end
 M.sync()
end
return M
