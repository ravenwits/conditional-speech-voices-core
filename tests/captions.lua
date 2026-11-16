local lua='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=lua..'shared/?.lua;'..lua..'client/?.lua;'..package.path

local rendered={}
local speech={
    generateSpeechFrom=function()end,
    ProcessSpeech=function()end,
    Say=function()end,
    applyVolumetricColor_Say=function(_,text,volume)
        rendered[#rendered+1]={text=text,volume=volume}
    end,
}
package.loaded.ConditionalSpeech_Core=speech
package.loaded.ConditionalSpeech_PhraseSet={}
local debug,captions=true,true
UIFont={Dialogue='bold'}
local player={
    isLocalPlayer=function()return true end,
    isDead=function()return false end,
    addLineChatElement=function(_,text,r,g,b,font,volume,tag,bbcode)
        rendered[#rendered+1]={text=text,font=font,volume=volume,r=r,g=g,b=b,bbcode=bbcode}
    end,
}
local C={
    contexts={},
    debugEnabled=function()return debug end,
    captionsEnabled=function()return captions end,
}
local V={config={enabled=true},voice=function()return 'local_bob' end}
require('CSV/SpeechAdapter').install(C,V,{speechAvailable=function()return true end})
local render=speech.applyVolumetricColor_Say
render(player,'Player chat',6)
assert(rendered[1].text=='Player chat')
C.contexts[player]={voice='local_bob',line={id='AfterHumanShaken_1',text='Cam açık.'},playbackEntry={line='AfterHumanShaken_2'}}
render(player,'Cam açık.',6)
assert(rendered[2].text=='AfterHumanShaken_2' and rendered[2].font=='bold' and rendered[2].volume==6)
assert(rendered[2].r==1 and rendered[2].g==0.25 and rendered[2].b==0.25 and rendered[2].bbcode==false)
assert(rendered[3].text=='Cam açık.')
debug=false
render(player,'Cam açık.',6)
assert(rendered[4].text=='Cam açık.')
debug=true
C.contexts[player].playbackFailed=true
render(player,'Cam açık.',0)
assert(rendered[5].text=='Cam açık.')
captions=false
render(player,'Cam açık.',6)
assert(#rendered==5)
C.contexts[player]=nil
render(player,'Player chat',6)
assert(rendered[6].text=='Player chat')
print('PASS CSV recording label, caption setting and unrelated text passthrough')
