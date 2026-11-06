local Menu={}
local V=require 'CSV/Core'
local A=require 'CSV/Actors'
local call=A.call
function Menu.fill(P,index,menu,objects,test)
 local function state(p)return P.state(p)end
 local eligible=P.eligible
  if test or not V.client or not V.client.debugEnabled() then return end;local p=getSpecificPlayer(index);if not eligible(p) then return end
  menu=require('CSV/DebugMenu').speech(menu)
  local root=menu:addOption(getText('UI_CSV_PeopleMenu'));local sub=ISContextMenu:getNew(menu);menu:addSubMenu(root,sub)
  sub:addOption(getText('UI_CSV_MarkShelter'),p,function(x)x:getModData().csvShelter={x=x:getX(),y=x:getY(),z=x:getZ()}end)
  sub:addOption(getText('UI_CSV_StopTracking'),p,function(x)state(x).track=nil end)
  local candidates={};for body,t in pairs(state(p).people)do if V.now()-t<1000 and call(p,'CanSee',body)==true then candidates[#candidates+1]=body end end
  table.sort(candidates,function(a,b)return p:DistTo(a)<p:DistTo(b)end)
  for i=1,math.min(6,#candidates)do
   local b=candidates[i];local label=tostring(call(b,'getFullName') or getText(A.kind(b)=='npc' and 'UI_CSV_Npc' or 'UI_CSV_Player'))..' ('..math.floor(p:DistTo(b))..'m)'
   sub:addOption(getText('UI_CSV_FollowPerson',label),p,function(x)P.intent(x,b,'pursuit')end)
   sub:addOption(getText('UI_CSV_TrackFriend',label),p,function(x)P.intent(x,b,'friend')end)
  end
end
return Menu
