local P={}
function P.rank(urgent,warning)return urgent and 3 or warning and 2 or 1 end
function P.before(a,b,rank,time)
 local x,y=rank(a),rank(b)
 if x~=y then return x<y end
 return time(a)>time(b)
end
function P.interrupt(incoming,current)return incoming>=3 and incoming>current end
return P
