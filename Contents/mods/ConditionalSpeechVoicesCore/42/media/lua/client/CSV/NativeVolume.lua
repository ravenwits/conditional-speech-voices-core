-- Native voice events use GameSound user volume, separate from dialogue handles.
local M={changed={},nextUpdate=0}
local suffixes={'','MeleeStab','MeleeStabOnGround','MeleeAttackHeavy','MeleeAttack','MeleeShove','MeleeStomp','PainFromBite','PainFromScratch','PainFromLacerate','PainFromGlassCut','PainFromFallHigh','PainFromFallLow','PainFromHitBlunt','PainFromRunIntoWall','ShoutHey','ShoutMegaphoneHey','SneezeLight','SneezeHeavy','JumpLow','JumpHigh','DeathAlone','DeathEaten','WhisperHey','WhisperPsst','WhisperMegaphoneHey','WhisperMegaphonePsst','ClimbWindow','Cough','MuffledCough','Sleep','Vomit','ApplyBandage','SighBored','SighReliefed','SighSad','LureTsk','LureCmon','DeathFall','DrunkHic','Exercise','FreezeShiver','Smoke','PainMoodle','CorpseDragging','CorpseHighEffort','CorpseLowEffort'}
function M.update()
 if not GameSounds or not GameSounds.isKnownSound then return end
 local V=require 'CSV/Core';local now=V.now()
 if now<M.nextUpdate then return end;M.nextUpdate=now+250
 local desired={};local C=V.client
 if C and (not V.config or V.config.enabled) then
  for i=0,getNumActivePlayers()-1 do
   local p=getSpecificPlayer(i);local voice=p and V.voice(p)
   if voice then
    local prefix=p:getDescriptor():getVoicePrefix()
    local native=V.bank(voice).native
    -- Every voice uses the same gain and engine cap; definitions stay intact.
    local requested=C.volumeGain(true)*10^(5/20)
    local function add(suffix)desired[prefix..suffix]=requested end
    for _,suffix in ipairs(suffixes)do add(suffix)end
    if native then
     for _,suffix in ipairs(native.suffixes or {})do add(suffix)end
     for _,kind in ipairs({'ShoutHey','WhisperHey'})do
      for _,id in ipairs(native.replacements[kind] or {})do add('CSV'..id)end
     end
    end
   end
  end
 end
 for name,row in pairs(M.changed)do
  if not desired[name] then
   if row.sound:getUserVolume()==row.applied then row.sound:setUserVolume(row.original)end
   M.changed[name]=nil
  end
 end
 for name,gain in pairs(desired)do
  if GameSounds.isKnownSound(name) then
   local sound=GameSounds.getSound(name);local row=M.changed[name]
   if not row or row.sound~=sound then row={sound=sound,original=sound:getUserVolume()};M.changed[name]=row end
   -- GameSound.setUserVolume clamps to 0..2. Do not rebuild clips to bypass it.
   row.requested=gain;local target=math.max(0,math.min(2,gain))
   if math.abs(sound:getUserVolume()-target)>.00001 then sound:setUserVolume(target)end
   row.applied=sound:getUserVolume()
  end
 end
end
function M.export(writer)
 local names={};for name in pairs(M.changed)do names[#names+1]=name end;require('CSV/Sort').sort(names)
 writer:write('NATIVE_VOLUME mode=user-volume-only definitionsRebuilt=0\n')
 for _,name in ipairs(names)do
  local r=M.changed[name]
  writer:write('NATIVE_GAIN sound='..name..' requested='..r.requested..' applied='..r.applied..' limited='..tostring(r.applied+.00001<r.requested)..'\n')
 end
end
return M
