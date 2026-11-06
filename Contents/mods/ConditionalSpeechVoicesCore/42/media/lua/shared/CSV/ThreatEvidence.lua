local E={}
function E.kind(s)
 if s.near==0 then return 'none' end
 if (s.attacking or 0)>0 then return 'attacking' end
 if (s.near or 0)>0 and s.accessibleNear==0 then return 'blocked' end
 if (s.reactiveNear or 0)>0 then
  if (s.approaching or 0)>0 then return 'approaching' end
  return 'targeting'
 end
 if s.reactiveNear==0 then return 'observed_only' end
 return 'unknown'
end
return E
