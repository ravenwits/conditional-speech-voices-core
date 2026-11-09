package.path='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/shared/?.lua;'..package.path
local sort=require('CSV/Sort').sort
local builtin=table.sort;table.sort=function()error('Kahlua recursive sort must not be used')end
for _,mode in ipairs({'sorted','reverse','duplicates','grouped'})do
 local t={}
 for i=1,12000 do t[i]=mode=='reverse' and 12001-i or mode=='duplicates' and i%5 or mode=='grouped' and ('voice'..(i%4)..'_'..i) or i end
 local comparisons=0
 sort(t,function(a,b)comparisons=comparisons+1;return a<b end)
 for i=2,#t do assert(t[i-1]<=t[i],mode)end
 assert(comparisons<12000*15,'bounded sorting work')
end
local rows={{rank=1,id=1},{rank=0,id=2},{rank=1,id=3}}
sort(rows,function(a,b)return a.rank<b.rank end)
assert(rows[1].id==2 and rows[2].id==1 and rows[3].id==3,'equal priority remains stable')
table.sort=builtin
print('PASS iterative sort of 12000 sorted/reverse/duplicate/grouped entries with bounded comparisons')
