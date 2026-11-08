local UI=require 'CSV/DebugUI'
local function t(key)return UI.text(key)end
local P={}
function P.open(player)
 require 'ISUI/ISPanel';require 'ISUI/ISComboBox';require 'ISUI/ISButton'
 local V=require 'CSV/Core'
 if P.panel then P.panel:removeFromUIManager()end
 local panel=ISPanel:new(120,120,650,250);panel:initialise();panel:instantiate();panel.moveWithMouse=true;P.panel=panel
 local choices=ISComboBox:new(20,50,270,28,panel,nil);choices:initialise();panel:addChild(choices)
 for _,label in ipairs({'-100','0','100'})do choices:addOption(label)end;choices.selected=2
 local values={-100,0,100};panel.status=t('Ready')
 local function button(x,label,fn)local b=ISButton:new(x,100,190,30,label,panel,fn);b:initialise();panel:addChild(b)end
 button(20,t('GameVoice'),function()
  local ok,err=pcall(function()
   local manager=getSoundManager();local emitter=manager:getUIEmitter()
   if P.handle then emitter:stopSound(P.handle)end
   if require('CSV/NativeVoice').supported(V.voice(player)) then
    -- Compare the same take and delivery through both playback paths.
    P.handle=manager:playUISound('CSV_'..V.voice(player)..'_'..V.pack.voices[V.voice(player)].preview..'_Self')
    emitter:setPitch(P.handle,V.pitchMultiplier(values[choices.selected],V.voice(player)))
   else
    P.handle=manager:playUISound(player:getDescriptor():getVoicePrefix()..'ShoutHey')
    emitter:setParameterValueByName(P.handle,'CharacterVoicePitch',values[choices.selected])
    emitter:setParameterValueByName(P.handle,'CharacterVoiceType',player:getDescriptor():getVoiceType())
   end
   emitter:tick()
  end)
  panel.status=ok and getText('UI_CSV_Aud_Queued') or getText('UI_CSV_Aud_NotStarted')
 end)
 button(230,t('ModVoice'),function()
  local ok,reason=V.client.preview(player,require('CSV/NativeVoice').supported(V.voice(player)) and V.pack.voices[V.voice(player)].preview or 'Thirst_1',nil,15,values[choices.selected]);panel.status=ok and getText('UI_CSV_Aud_Queued') or getText('UI_CSV_Aud_NotStarted')
 end)
 button(440,getText('UI_CSV_Aud_Close'),function()
  if P.handle then pcall(function()getSoundManager():getUIEmitter():stopSound(P.handle)end);P.handle=nil end
  panel:removeFromUIManager();P.panel=nil
 end)
 panel.prerender=function(self)
  ISPanel.prerender(self);self:drawText(getText('UI_CSV_Pitch'),20,15,1,1,1,1,UIFont.Medium)
  self:drawText(self.status,20,155,1,1,1,1,UIFont.Small)
 end
 panel:addToUIManager()
end
return P
