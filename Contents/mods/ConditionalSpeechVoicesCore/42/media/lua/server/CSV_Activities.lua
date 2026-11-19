if not isServer() then return end
local completion=require 'CSV/ActivityCompletion'
local traits=require('CSV/TraitSpeechRules').specialistRoutines
local sequence=0

completion.install(function(player,group)
 local playerId=player:getOnlineID()
 if not playerId or playerId<0 then return end
 sequence=sequence+1
 sendServerCommand(player,'CSVActivities','completed',{playerId=playerId,group=group,sequence=sequence})
end,function(group)return traits[group]~=nil end)
