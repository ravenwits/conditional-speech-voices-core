local W=require('CSV/Pack').whispers
function W.pick(V,voice,line)
 if not W.approved or not V.extended(voice) or not line then return nil end
 local item=W.catalog[line.id];if item and V.clip(voice,item.id) then return item end
end
function W.contains(id)
 if not W.approved or type(id)~='string' then return false end
 local original=id:match('^Whisper_(.+)$');return original~=nil and W.catalog[original]~=nil
end
return W
