package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/shared/?.lua;'..package.path
local D=require 'CSV/ApiDiagnostics'
assert(D.read('optional',function()return nil end)==nil and D.total==0)
assert(D.read('valid',function()return 17 end)==17)
D.read('failing',function()error('bad callback')end)
assert(D.total==1 and D.rows.failing.count==1)
for i=1,10000 do D.failure('error-'..i,string.rep('x',1000))end
assert(D.count==64 and D.overflow==9937,'diagnostic storage stays bounded under many distinct errors')
D.failure('failing','repeat')
assert(D.rows.failing.count==2,'existing counters continue after capacity is reached')
for _,row in pairs(D.rows)do assert(#row.last<=240)end
print('PASS optional API handling and bounded failure storage')
