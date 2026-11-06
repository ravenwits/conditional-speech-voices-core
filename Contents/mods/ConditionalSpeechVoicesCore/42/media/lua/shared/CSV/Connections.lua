local H={groups={}}
-- A transaction owns only its own wrappers and event registrations.
function H.install(name,build)
 local existing=H.groups[name]
 if existing and existing.installed then return true end
 local record={installed=false,undo={},errors=(existing and existing.errors or 0)}
 local transaction={}
 function transaction:set(object,key,value)
  local original=object[key];object[key]=value
  record.undo[#record.undo+1]=function()if object[key]==value then object[key]=original end end
 end
 function transaction:replace(object,key,replacement)
  assert(object and type(object[key])=='function','missing function '..key)
  local original=object[key];object[key]=replacement
  record.undo[#record.undo+1]=function()if object[key]==replacement then object[key]=original end end
  return original
 end
 function transaction:event(event,callback)
  assert(event and type(event.Add)=='function' and type(event.Remove)=='function','event registration/removal unavailable')
  event.Add(callback);record.undo[#record.undo+1]=function()event.Remove(callback)end
 end
 function transaction:removeEvent(event,callback)
  assert(event and type(event.Remove)=='function' and type(event.Add)=='function','event removal unavailable')
  event.Remove(callback);record.undo[#record.undo+1]=function()event.Add(callback)end
 end
 local ok,err=pcall(build,transaction)
 if not ok then
  for i=#record.undo,1,-1 do pcall(record.undo[i])end
  record.undo={};record.errors=record.errors+1;record.lastError=tostring(err)
 else record.installed=true end
 H.groups[name]=record
 return ok,err
end
function H.remove(name)
 local record=H.groups[name];if not record or not record.installed then return end
 for i=#record.undo,1,-1 do pcall(record.undo[i])end
 record.installed=false;record.undo={}
end
return H
