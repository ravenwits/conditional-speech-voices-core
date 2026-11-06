-- Bounded counts, not per-frame logging. Missing optional methods are not failures.
local D={total=0,overflow=0,count=0,rows={}}
function D.failure(key,err)
 D.total=D.total+1
 local row=D.rows[key]
 if not row then
  if D.count>=64 then D.overflow=D.overflow+1;return end
  row={count=0};D.rows[key]=row;D.count=D.count+1
 end
 row.count=row.count+1
 row.last=tostring(err):gsub('[\r\n]',' '):sub(1,240)
end
function D.read(key,fn)
 local ok,value=pcall(fn)
 if ok then return value end
 D.failure(key,value)
end
return D
