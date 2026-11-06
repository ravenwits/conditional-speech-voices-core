local R={policies={}}
R.policies['Agoraphobic']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['AnimalTracks']={pool={1},event=true,levels={1,2,2,3}}
R.policies['Bleeding']={pool={1,3},event=false,levels={1,1,1,3}}
R.policies['Bored']={pool={2},event=false,levels={2,2,2,2}}
R.policies['ChopTree']={pool={1,2},event=true,levels={1,2,2,3}}
R.policies['Claustrophobic']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Drunk']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Endurance']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Explore']={pool={2},event=true,levels={1,2,2,3}}
R.policies['FoodEaten']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['FoodRaw']={pool={1,2,3},event=true,levels={1,2,2,3}}
R.policies['FoodRotten']={pool={1},event=true,levels={1,2,2,3}}
R.policies['Foraged']={pool={1,3},event=true,levels={1,2,2,3}}
R.policies['FoundLoot']={pool={},event=true,levels={1,2,2,3}}
R.policies['GunJammed']={pool={1,2,3},event=true,levels={1,2,2,3}}
R.policies['HasACold']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['HeavyLoad']={pool={2,3},event=false,levels={2,2,2,3}}
R.policies['Holes']={pool={1,2},event=true,levels={1,2,2,3}}
R.policies['Hungry']={pool={1,2},event=false,levels={1,2,2,2}}
R.policies['Hyperthermia']={pool={2,3},event=false,levels={2,2,2,3}}
R.policies['Hypothermia']={pool={2,3},event=false,levels={2,2,2,3}}
R.policies['Injured']={pool={2,3},event=false,levels={2,2,2,3}}
R.policies['Kill']={pool={1,2},event=true,levels={1,2,2,3}}
R.policies['LevelUp']={pool={1,2,3},event=true,levels={1,2,2,3}}
R.policies['LowAmmo']={pool={1,2,3},event=true,levels={1,2,2,3}}
R.policies['MultiHit']={pool={},event=true,levels={1,2,2,3}}
R.policies['OnDawn']={pool={1,2},event=true,levels={1,2,2,3}}
R.policies['OnDusk']={pool={1,2,3},event=true,levels={1,2,2,3}}
R.policies['OutOfAmmo']={pool={1,2,3},event=true,levels={1,2,2,3}}
R.policies['Pain']={pool={1,3},event=false,levels={1,1,1,3}}
R.policies['Panic']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['PanicCallback']={pool={},event=false,levels={1,2,2,3}}
R.policies['Sick']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['SickFromFood']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Stress']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Thirst']={pool={1,2},event=false,levels={1,2,2,2}}
R.policies['Tired']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Unhappy']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['VehicleDamage']={pool={1,2},event=true,levels={1,2,2,3}}
R.policies['Wet']={pool={1,2},event=false,levels={1,2,2,2}}
R.policies['Windchill']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['NoxiousSmell']={pool={3},event=false,levels={3,3,3,3}}
R.policies['Uncomfortable']={pool={},event=false,levels={1,2,2,3}}
R.policies['CantSprint']={pool={1,2,3},event=false,levels={1,2,2,3}}
R.policies['Angry']={pool={1,2,3},event=false,levels={1,2,2,3}}
function R.pool(V,player,group,intensity,maximum,facts)
    local s=facts or require('CSV/State').capture(player)
    if group=='FoundLoot' then return {s.pickup==true and V.data.groups.FoundLoot[3] or V.data.groups.Explore[2]} end
    if group=='ChopTree' and s.treeDown==true then return {V.data.groups.ChopTree[3]} end
    if group=='MultiHit' and s.reactiveCrowd and s.reactiveCrowd>=3 then return V.data.groups.MultiHit end
    if group=='Wet' and s.cold and s.cold>=2 and intensity and intensity>=3 then return {V.data.groups.Wet[3]} end
    if group=='PanicCallback' then return {V.data.groups.Panic[1]} end
    local policy=R.policies[group];if not policy then return nil end
    if group=='GunJammed' and s.jammed==false then return {} end
    if group=='OutOfAmmo' and (s.empty~=true or s.jammed==true) then return {} end
    if group=='Panic' and s.fire==true then return {V.data.groups.Panic[3]} end
    local out={}
    if not policy.event and V.finite(maximum) and maximum>1 then
        local level=math.max(1,math.min(4,math.floor(1+3*(math.max(1,intensity or 1)-1)/(maximum-1)+0.5)))
        local index=policy.levels[level]
        for _,i in ipairs(policy.pool)do if i==index then out[1]=V.data.groups[group][i] end end
    else
        for _,i in ipairs(policy.pool)do out[#out+1]=V.data.groups[group][i] end
    end
    return out
end
return R
