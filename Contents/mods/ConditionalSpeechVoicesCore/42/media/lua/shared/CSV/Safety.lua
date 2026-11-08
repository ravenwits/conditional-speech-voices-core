local M={}
function M.clear(s)
 if s.near~=0 or type(s.visible)~='number' or s.humanThreat==true or s.nativeAlert or require('CSV/Concealment').active(s) then return false end
 return s.encounterThreat==false or s.visible==0 and s.encounterThreat~=true
end
function M.settled(s)return M.clear(s) and s.recentThreat==false end
return M
