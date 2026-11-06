-- Add speech choices without editing the game's screen or inventing FMOD types.
local M={pending=nil}
local pack=require 'CSV/Pack'
local styles={}
for _,id in ipairs(pack.voiceOrder)do
 local voice=id;local v=pack.voices[voice]
 if not v.vanilla then styles[voice]={getName=function()return v.styleName or 'CSV_'..voice end,
 getPrefix=function()return require('CSV/NativeVoice').tryEnsure(0,voice) or v.base end,
 getVoiceType=function()return 0 end,getBodyTypeDefault=function()return v.base=='VoiceFemale' and 1 or 2 end}end
end
function M.choice(screen)
 local combo=screen.voiceTypeCombo;local item=combo and combo:getOptionData(combo.selected)
 for id,style in pairs(styles)do if item==style then return id end end
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
  for _,id in ipairs(pack.voiceOrder)do
   local style=styles[id]
   if style then
    local found=false
    for i in ipairs(self.voiceTypeCombo.options)do if self.voiceTypeCombo:getOptionData(i)==style then found=true end end
    if not found then self.voiceTypeCombo:addOptionWithData(pack.voices[id].name,style)end
   end
  end
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
  self.soundRef=manager:playUISound('CSV_'..M.choice(self)..'_'..pack.voices[M.choice(self)].preview..'_Self')
  if self.soundRef~=0 then
   self.soundPlayer:setPitch(self.soundRef,require('CSV/Core').pitchMultiplier(self:getVoicePitch(),M.choice(self)))
   self.soundPlayer:tick()
  end
  self:disableBtn()
 end
end
return M
