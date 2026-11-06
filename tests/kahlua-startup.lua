local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
next=nil
local V=require 'CSV/Core'
assert(not V.languageSupported())
local pack=V.pack;pack.id='fixture';pack.hasCustomVoices=true
assert(V.languageSupported())
local count=0;local event={Add=function()count=count+1 end}
Events={OnGameBoot=event,OnCreatePlayer=event,OnPlayerUpdate=event}
package.loaded['CSV/CharacterVoice']={created=function()end}
package.loaded['CSV/NativeVoice']={safeApply=function()end,update=function()end}
dofile(base..'client/CSV_CharacterVoice.lua');assert(count==4)
pack.hasCustomVoices=false;pack.language='EN';Translator={getLanguage=function()return {name=function()return 'EN'end}end}
assert(V.languageSupported())
Translator.getLanguage=function()return {name=function()return 'TR'end}end
assert(not V.languageSupported())
count=0;dofile(base..'client/CSV_CharacterVoice.lua');assert(count==0)
print('PASS startup without next: native hooks and language gates')
