local L={groups={LootWeapon=true,LootFood=true,LootBandage=true,LootPainMedicine=true,LootStomach=true,LootAmmo=true,LootWater=true,LootLight=true,LootClothing=true,LootCanOpener=true,LootMagazine=true}}
L.gaps={[0]={between=90000,category=600000},[1]={between=30000,category=180000},[2]={between=10000,category=60000}}
function L.settings(prefs)
 prefs=prefs or {};local mode=prefs.lootMode;local frequency=prefs.lootFrequency
 if mode~=0 and mode~=1 and mode~=2 then mode=2 end
 return mode,L.gaps[frequency] or L.gaps[1]
end
function L.allowed(group,prefs)
 local mode=L.settings(prefs)
 return mode~=0 and (mode==2 or group~='LootWeapon' and group~='FoundLoot')
end
-- Pure facts: absent/unknown item properties never prove an item will help.
function L.classify(f)
 if not f or f.owned~=true then return nil,'not_owned' end
 if f.cleanWater==true and (f.thirst or 0)>0 then return 'LootWater','current_thirst' end
 if f.betterDryClothing==true and (f.cold or 0)>0 and f.heat==0 then return 'LootClothing','cold_and_better_dry_layer' end
 if f.inventoryComplete==true and f.workingLight==true and f.dark==true and f.otherWorkingLight==false then return 'LootLight','dark_without_working_light' end
 if f.bandage==true and (f.openWounds or 0)>0 then return 'LootBandage','uncovered_wound' end
 if f.stomachAid==true and (f.foodSickness or 0)>0 then return 'LootStomach','food_sickness' end
 if f.painMedicine==true and (f.pain or 0)>0 then return 'LootPainMedicine','current_pain' end
 if f.edible==true and (f.hunger or 0)>0 then return 'LootFood','current_hunger' end
 if f.inventoryComplete==true then
  if f.neededOpener==true then return 'LootCanOpener','sealed_food_without_opener' end
  if f.neededMagazine==true then return 'LootMagazine','matching_gun_without_magazine' end
  if f.compatibleAmmo==true and type(f.reserve)=='number' and f.reserve<=math.max(20,(f.capacity or 0)*2) then return 'LootAmmo','compatible_low_reserve' end
  if f.usefulWeapon==true then return 'LootWeapon','useful_working_weapon' end
 end
 return nil,'no_verified_need'
end
return L
