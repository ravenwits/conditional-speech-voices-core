local W={}
local call=require('CSV/Actors').call
local regions={Head='Head',Neck='Neck',Torso_Upper='Chest',Torso_Lower='Belly',Groin='Groin',
 Hand_L='Hand',Hand_R='Hand',ForeArm_L='Arm',ForeArm_R='Arm',UpperArm_L='Arm',UpperArm_R='Arm',
 UpperLeg_L='Leg',UpperLeg_R='Leg',LowerLeg_L='Leg',LowerLeg_R='Leg',Foot_L='Foot',Foot_R='Foot'}

W.slots={BiteUnspecified_1={group='BiteWound'},BleedingUnspecified_1={group='BleedingSite'},BloodOnSkin_1={group='BloodOnSkin'}}
for _,region in pairs(regions)do
 W.slots['Injured'..region..'_1']={group='WoundSite',region=region}
 W.slots['Bleeding'..region..'_1']={group='BleedingSite',region=region}
 W.slots['Bite'..region..'_1']={group='BiteWound',region=region}
end

-- A wound and a blood stain are independent. Keep the location only when
-- exactly one part meets the condition. Unknown part types stay generic.
function W.readBody(parts,s)
 local wounds,bleeds,bandages,dirty=0,0,0,0
 local bites,bleedingBites=0,0
 local biteRegion,bleedingBiteRegion
 local complete,bitesKnown=true,true
 local woundRegion,bleedRegion,bleedingCut
 for i=0,parts:size()-1 do
  local part=parts:get(i)
  if part:bandaged() then
   bandages=bandages+1
   if part:getBandageLife()<=0 then dirty=dirty+1 end
  end
  local injured=call(part,'HasInjury')
  local bleeding=part:bleeding()
  if injured==nil then complete=false end
  local bitten=call(part,'bitten')
  if bitten==nil then bitesKnown=false end
  if injured or bleeding or bitten then
   local kind=call(part,'getType')
   local region=kind and BodyPartType and regions[BodyPartType.ToString(kind)]
   if bitten then
    bites=bites+1;biteRegion=region
    if bleeding then bleedingBites=bleedingBites+1;bleedingBiteRegion=region end
   end
   if injured then wounds=wounds+1;woundRegion=region end
   if bleeding then
    bleeds=bleeds+1;bleedRegion=region
    if call(part,'isCut')==true then bleedingCut=true end
   end
  end
 end
 s.bandages=bandages;s.dirty=dirty;s.bleeding=bleeds
 s.wounds=complete and wounds or nil
 s.woundRegion=complete and wounds==1 and woundRegion or nil
 s.bleedRegion=bleeds==1 and bleedRegion or nil
 s.bleedingCut=bleedingCut==true
 s.bites=bites;s.bleedingBites=bleedingBites
 s.biteRegion=bitesKnown and bites==1 and biteRegion or nil
 s.bleedingBiteRegion=bitesKnown and bleedingBites==1 and bleedingBiteRegion or nil
end

function W.bloodOnSkin(player)
 local visual=call(player,'getHumanVisual')
 if not visual or not BloodBodyPartType then return false end
 for i=0,BloodBodyPartType.MAX:index()-1 do
  if visual:getBlood(BloodBodyPartType.FromIndex(i))>0 then return true end
 end
 return false
end
return W
