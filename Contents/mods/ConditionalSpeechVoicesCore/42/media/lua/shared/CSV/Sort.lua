-- Iterative stable merge sort. Kahlua's recursive quicksort can overflow on large banks.
local M={}
function M.sort(values,less)
 less=less or function(a,b)return a<b end
 local count=#values;local width=1;local buffer={}
 while width<count do
  for left=1,count,width*2 do
   local middle=math.min(left+width,count+1);local finish=math.min(left+width*2,count+1)
   local a,b=left,middle
   for index=left,finish-1 do
    if a<middle and (b>=finish or not less(values[b],values[a])) then buffer[index]=values[a];a=a+1
    else buffer[index]=values[b];b=b+1 end
   end
  end
  for index=1,count do values[index]=buffer[index]end
  width=width*2
 end
 return values
end
return M
