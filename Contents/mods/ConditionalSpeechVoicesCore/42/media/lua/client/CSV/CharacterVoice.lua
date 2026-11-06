-- Add speech choices without editing the game's screen or inventing FMOD types.
local M={pending=nil}
local style={getName=function()return 'CSV_Alp_Turkish'end,
 getPrefix=function()return require('CSV/NativeVoice').tryEnsure(0) or 'VoiceMale'end,getVoiceType=function()return 0 end,
 getBodyTypeDefault=function()return 2 end}
local female={getName=function()return 'CSV_Mujde_Turkish'end,
 getPrefix=function()return require('CSV/NativeVoice').tryEnsure(0,'mujde') or 'VoiceFemale'end,
 getVoiceType=function()return 0 end,getBodyTypeDefault=function()return 1 end}
function M.choice(screen)
 local combo=screen.voiceTypeCombo;local item=combo and combo:getOptionData(combo.selected)
 local name=item and item:getName()
 return name==style:getName() and 'alp' or name==female:getName() and 'mujde' or nil
end
function M.selected(screen)return M.choice(screen)~=nil end
function M.created(index,player)
 if not M.pending or not player or index~=0 then return end
 local choice=M.pending;M.pending=nil
 local md=player:getModData()
 md.csvVoice=choice.voice
 if choice.voice then require('CSV/NativeVoice').apply(player)end
 if player.transmitModData then player:transmitModData()end
end
function M.install(screen)
 if screen.csvVoiceInstalled then return end
 screen.csvVoiceInstalled=true
 local create=screen.createVoiceTypeBtn
 screen.createVoiceTypeBtn=function(self,...)
  M.pending=nil
  create(self,...)
  local hasAlp,hasMujde=false,false
  for i in ipairs(self.voiceTypeCombo.options)do
   local item=self.voiceTypeCombo:getOptionData(i);local name=item and item:getName()
   hasAlp=hasAlp or name==style:getName();hasMujde=hasMujde or name==female:getName()
  end
  if not hasAlp then self.voiceTypeCombo:addOptionWithData('Alp (Turkish)',style)end
  if not hasMujde and require('CSV/Pack').extraVoices.mujde then self.voiceTypeCombo:addOptionWithData('Mujde (Turkish)',female)end
 end
 local init=screen.initPlayer
 screen.initPlayer=function(self,...)
  local result=init(self,...)
  M.pending={voice=M.choice(self)}
  return result
 end
 local click=screen.onOptionMouseDown
 screen.onOptionMouseDown=function(self,button,...)
  if button.internal~='PLAYDEMOVOICE' or not M.selected(self) then return click(self,button,...)end
  if self.soundRef and self.soundPlayer:isPlaying(self.soundRef) then self.soundPlayer:stopSound(self.soundRef)end
  local manager=getSoundManager()
  manager:setMusicState('InGame');manager:resumeSoundAndMusic()
  self.soundRef=manager:playUISound('CSV_'..M.choice(self)..'_AlpPanicGrounding_1_Self')
  if self.soundRef~=0 then
   self.soundPlayer:setPitch(self.soundRef,require('CSV/Core').pitchMultiplier(self:getVoicePitch(),M.choice(self)))
   self.soundPlayer:tick()
  end
  self:disableBtn()
 end
end
return M
