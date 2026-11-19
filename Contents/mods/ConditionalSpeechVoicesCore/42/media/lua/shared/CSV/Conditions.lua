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
  local slot=({Bored='Bored_2',Explore='Explore_2',AnimalTracks='AnimalTracks_1',FoodRotten='FoodRotten_1'})[group]
  local history=C.history[player] or {}
  for _,old in ipairs(V.bank(voice).data.groups[group] or {})do
   if old.id==slot and V.clip(voice,slot) and (not fresh or (history[slot] or 0)<=(history[fresh.id] or 0)) then
    return {id=slot,text=old.text,group=group},true
   end
  end
  if group=='AnimalTracks' and not fresh and f.sneaking~=true then
   return require('CSV/TraitSpeechRules').preferredRecording(V,player,voice,'AnimalTracks_1',f,C.history[player] or {},C.preferences()),true
  end
  return fresh,true
 end
 return nil,false
end
return X
