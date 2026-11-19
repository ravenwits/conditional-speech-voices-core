local T={}
local call=require('CSV/Actors').call
local radius=6
local quietGap=12000

local function opening(o)
 if not o then return end
 if instanceof(o,'IsoBarricade') then o=call(o,'getBarricadedObject') end
 if not o or not (instanceof(o,'IsoDoor') or instanceof(o,'IsoWindow')
  or instanceof(o,'IsoThumpable') and call(o,'isDoor')==true) then return end
 local square=call(o,'getSquare')
 local north=call(o,'isNorth')
 if north==nil then north=call(o,'getNorth')end
 if square and type(north)=='boolean' then
  return square:getX(),square:getY(),square:getZ(),north
 end
end

local function at(o,x,y,z)
 local square=call(o,'getSquare')
 return square and square:getX()==x and square:getY()==y and square:getZ()==z
end

-- Build 42 door, window and barricade Thump() emit this world sound on impact.
-- getThumpTarget alone is set before the swing.
function T.impact(x,y,z,soundRadius,volume,source,lookup)
 if soundRadius~=20 or volume~=20 or not source or not instanceof(source,'IsoZombie') then return end
 local target=call(source,'getThumpTarget')
 if target then
  if at(target,x,y,z) then return opening(target) end
  -- A barricade may emit from the opposite side of its door or window.
  local near=call(target,'getBarricadeForCharacter',source)
  local far=call(target,'getBarricadeOppositeCharacter',source)
  if at(near,x,y,z) or at(far,x,y,z) then return opening(target) end
  return
 end
 -- The dedicated server can process a ZombieHitThumpable packet without
 -- having the client's thump target. Resolve only an unambiguous opening.
 if not lookup then return end
 local origin=call(source,'getCurrentSquare')
 if not origin or origin:getZ()~=z or math.abs(origin:getX()-x)>1 or math.abs(origin:getY()-y)>1 then return end
 local square=lookup(x,y,z)
 local objects=call(square,'getSpecialObjects')
 if not objects then return end
 local match,ox,oy,oz,north
 for i=0,objects:size()-1 do
  local obj=objects:get(i)
  local a,b,c,n=opening(obj)
  if a and call(obj,'isOpen')~=true and call(obj,'IsOpen')~=true then
   if match and (a~=ox or b~=oy or c~=oz or n~=north) then return end
   match,ox,oy,oz,north=true,a,b,c,n
  end
 end
 return ox,oy,oz,north
end

function T.near(p,x,y,z,north,lookup)
 if not p or call(p,'isDead')~=false or call(p,'isAsleep')==true or call(p,'getVehicle') then return false end
 if type(x)~='number' or type(y)~='number' or type(z)~='number' or type(north)~='boolean' then return false end
 local square=call(p,'getCurrentSquare')
 if not square or square:getZ()~=z then return false end
 local dx,dy=square:getX()-x,square:getY()-y
 if dx*dx+dy*dy>radius*radius then return false end
 local building=square:getBuilding()
 if not building then return false end
 local edge=lookup(x,y,z)
 local opposite=lookup(x-(north and 0 or 1),y-(north and 1 or 0),z)
 return building==call(edge,'getBuilding') or building==call(opposite,'getBuilding')
end

function T.first(seen,p,x,y,z,north,now)
 local key=x..':'..y..':'..z..':'..(north and 'N' or 'W')
 local strikes=seen[p] or {};seen[p]=strikes
 local prior=strikes[key]
 for id,at in pairs(strikes) do if now-at>=quietGap then strikes[id]=nil end end
 strikes[key]=now
 return not prior or now-prior>=quietGap
end

function T.square(x,y,z)
 local cell=getCell()
 return cell and cell:getGridSquare(x,y,z)
end

return T
