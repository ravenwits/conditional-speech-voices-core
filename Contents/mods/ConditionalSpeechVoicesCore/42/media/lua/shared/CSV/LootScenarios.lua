local S={}
function S.facts(group)
 local f={owned=true,inventoryComplete=true}
 if group=='LootWeapon' then f.usefulWeapon=true
 elseif group=='LootFood' then f.edible=true;f.hunger=2
 elseif group=='LootBandage' then f.bandage=true;f.openWounds=1
 elseif group=='LootPainMedicine' then f.painMedicine=true;f.pain=2
 elseif group=='LootStomach' then f.stomachAid=true;f.foodSickness=20
 elseif group=='LootWater' then f.cleanWater=true;f.thirst=2
 elseif group=='LootLight' then f.workingLight=true;f.dark=true;f.otherWorkingLight=false
 elseif group=='LootClothing' then f.betterDryClothing=true;f.cold=2;f.heat=0
 elseif group=='LootCanOpener' then f.neededOpener=true
 elseif group=='LootMagazine' then f.neededMagazine=true
 elseif group=='LootAmmo' then f.compatibleAmmo=true;f.reserve=4;f.capacity=15 end
 return f
end
function S.cases()
 local cases={}
 for _,group in ipairs({'LootWeapon','LootFood','LootBandage','LootPainMedicine','LootStomach','LootAmmo','LootWater','LootLight','LootClothing','LootCanOpener','LootMagazine'})do
  for _,mode in ipairs({'safe','whisper','concealed','danger','unknown'})do
   local state={loot=S.facts(group),sneaking=mode=='whisper' or mode=='concealed',near=mode=='danger' and 2 or 0,visible=mode=='danger' and 2 or 0,recentThreat=mode=='danger',panic=0}
   if mode=='unknown' then state.near=nil end
   cases[#cases+1]={name=group..': '..mode,group=group,level=1,max=1,state=state,prefs={whisper=mode=='whisper'},expect=group,kate='none',mode=(mode=='safe' or mode=='whisper') and 'spoken' or 'silent',newLoot=true}
  end
  local resolved=S.facts(group)
  if group=='LootFood' then resolved.hunger=0 elseif group=='LootBandage' then resolved.openWounds=0 elseif group=='LootPainMedicine' then resolved.pain=0 elseif group=='LootStomach' then resolved.foodSickness=0 elseif group=='LootAmmo' then resolved.reserve=999 elseif group=='LootWater' then resolved.thirst=0 elseif group=='LootLight' then resolved.dark=false elseif group=='LootClothing' then resolved.cold=0 elseif group=='LootCanOpener' then resolved.neededOpener=false elseif group=='LootMagazine' then resolved.neededMagazine=false else resolved.usefulWeapon=false end
  cases[#cases+1]={name=group..': need resolved before speech',group=group,level=1,max=1,state={loot=resolved,sneaking=false,near=0,visible=0,recentThreat=false},expect='none',kate='none',newLoot=true}
  for _,mode in ipairs({0,1})do
   local expectedMode=(mode==0 or group=='LootWeapon') and 'silent' or 'spoken'
   cases[#cases+1]={name=group..': loot option '..mode,group=group,level=1,max=1,state={loot=S.facts(group),sneaking=false,near=0,visible=0,recentThreat=false},prefs={lootMode=mode},expect=group,kate='none',mode=expectedMode,newLoot=true}
  end
  local f=S.facts(group);f.owned=false
  cases[#cases+1]={name=group..': item no longer owned',group=group,level=1,max=1,state={loot=f,sneaking=false,near=0,visible=0,recentThreat=false},expect='none',kate='none',newLoot=true}
 end
 return cases
end
return S
