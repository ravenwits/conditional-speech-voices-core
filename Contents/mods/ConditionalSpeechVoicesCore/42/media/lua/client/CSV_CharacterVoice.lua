if next(require('CSV/Pack').extraVoices) then
 local adapter=require 'CSV/CharacterVoice'
 local function install()
  require 'OptionScreens/CharacterCreationMain'
  adapter.install(CharacterCreationMain)
  require 'ISUI/ISEmoteRadialMenu'
  require('CSV/AlpCallout').install(ISEmoteRadialMenu)
 end
 Events.OnGameBoot.Add(install)
 Events.OnCreatePlayer.Add(adapter.created)
 local native=require 'CSV/NativeVoice'
 Events.OnCreatePlayer.Add(function(_,player)native.safeApply(player)end)
 Events.OnPlayerUpdate.Add(native.update)
end
