-- Add speech choices without editing the game's screen or inventing FMOD types.
local M={pending=nil}
local pack=require 'CSV/Pack'
local styles={}
for _,id in ipairs(pack.voiceOrder)do
 local voice=id;local v=pack.voices[voice]
 if not v.vanilla and not v.builtinPrefix then styles[voice]={getName=function()return v.styleName or 'CSV_'..voice end,
 getPrefix=function()return require('CSV/NativeVoice').tryEnsure(0,voice) or v.base end,
 getVoiceType=function()return 0 end,getBodyTypeDefault=function()return v.base=='VoiceFemale' and 1 or 2 end}end
end
function M.choice(screen)
 local combo=screen.voiceTypeCombo;local item=combo and combo:getOptionData(combo.selected)
 for id,style in pairs(styles)do if item==style then return id end end
 if item and item.getPrefix and item.getVoiceType and item:getVoiceType()==0 then
  for _,id in ipairs(pack.voiceOrder)do
   if pack.voices[id].builtinPrefix==item:getPrefix() then return id end
  end
 end
end
function M.selected(screen)return M.choice(screen)~=nil end
function M.created(index,player)
 if not M.pending or not player or index~=0 then return end
 local choice=M.pending;M.pending=nil
 local md=player:getModData()
 md.csvVoice=choice.voice
 if choice.voice then require('CSV/NativeVoice').safeApply(player)end
 if player.transmitModData then player:transmitModData()end
end
local function nextPreview(screen,voice,core)
 local definition=pack.voices[voice]
 screen.csvPreviews=screen.csvPreviews or {}
 local state=screen.csvPreviews[voice] or {remaining={}}
 screen.csvPreviews[voice]=state
 local remaining=state.remaining
 if #remaining==0 then
  for _,line in ipairs(definition.previewLines or {definition.preview})do
   if core.clip(voice,line) then remaining[#remaining+1]=line end
  end
 end
 local candidates={}
 for index,line in ipairs(remaining)do
  if #remaining==1 or line~=definition.previewLast then candidates[#candidates+1]=index end
 end
 -- Avoid a repeat across rounds when another eligible sample exists.
 if #candidates>1 then
  for i=#candidates,1,-1 do if remaining[candidates[i]]==state.last then table.remove(candidates,i)end end
 end
 if #candidates==0 then return end
 local index=candidates[ZombRand(#candidates)+1]
 return remaining[index],state,index
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
  if button.internal~='PLAYDEMOVOICE' then return click(self,button,...)end
  local voice=M.choice(self)
  if not voice then return click(self,button,...)end
  local core=require 'CSV/Core'
  local line,state,index=nextPreview(self,voice,core)
  if not line then return click(self,button,...)end
  local clip=core.clip(voice,line)
  local mix={packet={voice=voice},line=line,ownVoice=true,preview=true,
   baseVolume=core.deliveryGain(voice,line),balance=clip.gain or 1}
  local client=core.client
  local gain=client and client.entryGain and client.entryGain(mix)
   or core.outputGain(voice,line,mix.baseVolume*mix.balance)
  if self.soundRef and self.soundPlayer:isPlaying(self.soundRef) then self.soundPlayer:stopSound(self.soundRef)end
  local manager=getSoundManager()
  manager:setMusicState('InGame');manager:resumeSoundAndMusic()
  self.soundRef=manager:playUISound(clip.sound..'_Self')
  if self.soundRef and self.soundRef~=0 then
   self.soundPlayer:setVolume(self.soundRef,gain)
   self.soundPlayer:setPitch(self.soundRef,core.pitchMultiplier(self:getVoicePitch(),voice))
   self.soundPlayer:tick()
   table.remove(state.remaining,index);state.last=line
  end
  self:disableBtn()
 end
end
return M
