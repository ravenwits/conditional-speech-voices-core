local E=require('CSV/Pack').extras
function E.pick(V,voice,group,seed)
 if not E.approved or not V.extended(voice) then return nil end
 local found={};for _,line in pairs(E.catalog)do if line.group==group and V.clip(voice,line.id) then found[#found+1]=line end end
 table.sort(found,function(a,b)return a.id<b.id end)
 if #found==0 then return nil end
 return found[((seed or 0)%#found)+1]
end
return E
