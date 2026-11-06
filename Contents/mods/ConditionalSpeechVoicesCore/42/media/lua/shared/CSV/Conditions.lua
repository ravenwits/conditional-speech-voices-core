local X={enabled=true}
X.sourceGroups={AmmoCount='LowAmmo',ChamberEmpty='OutOfAmmo'}
X.replacements={Bored='BoredMore',Explore='ExploreMore',AnimalTracks='TracksMore',FoodRotten='RottenMore',SickFromFood='FoodSuspect'}
function X.choose(V,C,player,voice,group,f)
 if not X.enabled or not V.extended(voice) then return nil,false end
 if group=='AmmoCount' then
  if f.jammed or type(f.rounds)~='number' or f.rounds<1 or f.rounds%1~=0 then return nil,true end
  if require('CSV/AmmoCounts').contains(f.rounds) then local id='AmmoCount_'..string.format('%d',f.rounds);local line=require('CSV/Extras').catalog[id];return line and V.clip(voice,id) and line or nil,true end
  return C.extraLine(player,voice,'AmmoReserve'),true
 end
 if (group=='OutOfAmmo' or group=='ChamberEmpty') and f.jammed~=true and f.hasChamber==true and f.chamber==false and (f.rounds or 0)>0 then return C.extraLine(player,voice,'ChamberEmpty'),true end
 if group=='ChamberEmpty' then return nil,true end
 local replacement=X.replacements[group]
 if replacement then
  local fresh=C.extraLine(player,voice,replacement)
  local index=({Bored=2,Explore=2,AnimalTracks=1,FoodRotten=1})[group]
  if index then
   local old=V.data.groups[group][index];local h=C.history[player] or {}
   if V.clip(voice,old.id) and (not fresh or (h[old.id] or 0)<=(h[fresh.id] or 0)) then return {id=old.id,text=old.text,group=group},true end
  end
  return fresh,true
 end
 return nil,false
end
return X
