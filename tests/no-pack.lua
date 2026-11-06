local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local V=require 'CSV/Core'
assert(not V.available() and not V.extended('bob') and not V.extended('kate'))
assert(V.voice({})==nil and V.clip('bob','StartleNormal_1')==nil)
assert(V.choose('Panic',1)==nil and not V.languageSupported())
assert(not require('CSV/Extras').approved)
assert(not require('CSV/Whispers').approved)
assert(not require('CSV/Expressions').approved)
assert(require('CSV/Profanity').allowed('unknown',{}))
assert(not V.validPacket({version=1,actor=0,seq=1,line='StartleNormal_1',voice='bob',pitch=0,radius=4}))
print('PASS core without any voice pack has no voice, candidates or playback')

