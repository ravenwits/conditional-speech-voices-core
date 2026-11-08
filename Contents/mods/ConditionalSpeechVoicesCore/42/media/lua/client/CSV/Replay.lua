-- Debug-only decision inputs. Never serialize game objects or execute a report.
local R={rows={},limit=32}
local function snapshot(value,depth,budget)
 local kind=type(value)
 if kind=='number' and value==value and math.abs(value)<math.huge then return value end
 if kind=='boolean' then return value end
 if kind=='string' and #value<=512 then return value end
 if kind~='table' or depth<=0 or budget.left<=0 then budget.partial=true;return nil end
 local copy={}
 for key,item in pairs(value)do
  if budget.left<=0 then budget.partial=true;break end
  budget.left=budget.left-1
  if type(key)=='string' and #key<=512 or type(key)=='number' then copy[key]=snapshot(item,depth-1,budget)
  else budget.partial=true end
 end
 return copy
end
local function json(value)
 local kind=type(value)
 if kind=='nil' then return 'null' end
 if kind=='string' then
  return '"'..value:gsub('[%z\1-\31\\"]',function(c)
   if c=='\\' or c=='"' then return '\\'..c end
   return string.format('\\u%04x',string.byte(c))
  end)..'"'
 end
 if kind~='table' then return tostring(value) end
 local rows={}
 local size=#value
 if size>0 then
  local dense=true
  for key in pairs(value)do
   if type(key)~='number' or key%1~=0 or key<1 or key>size then dense=false;break end
  end
  if dense then
   for i=1,size do rows[i]=json(value[i]) end
   return '['..table.concat(rows,',')..']'
  end
 end
 for key,item in pairs(value)do rows[#rows+1]=json(tostring(key))..':'..json(item) end
 table.sort(rows)
 return '{'..table.concat(rows,',')..'}'
end
function R.capture(V,C,plan,player,voice,group,level,maximum,facts,prefs)
 local budget={left=512}
 local bank=V.bank(voice)
 local row={at=V.now(),version=V.version,bank=bank.id,revision=bank.revision,voice=voice,group=group,
  level=level,maximum=maximum,facts=snapshot(facts,4,budget),prefs=snapshot(prefs or {},3,budget),
  settings=snapshot(C.preferences(),3,budget),history=snapshot(C.history[player] or {},2,budget),rolls={}}
 local previous=V.selectionRandom
 V.selectionRandom=function(n)
  local result=(previous or ZombRand)(n)
  row.rolls[#row.rolls+1]=result
  return result
 end
 local ok,line,decision=pcall(plan,player,voice,group,level,maximum,facts,prefs)
 V.selectionRandom=previous
 if not ok then error(line,0) end
 row.line=line and line.id;row.mode=decision.mode;row.reason=decision.reason
 row.partial=budget.partial or prefs==nil
 if #R.rows>=R.limit then table.remove(R.rows,1) end
 R.rows[#R.rows+1]=row
 return line,decision
end
function R.export(writer)
 for _,row in ipairs(R.rows)do
  local render=function()return 'CSV_REPLAY '..json(row)..'\n' end
  if type(writer)=='table' and writer.defer then writer:defer(render) else writer:write(render()) end
 end
end
return R
