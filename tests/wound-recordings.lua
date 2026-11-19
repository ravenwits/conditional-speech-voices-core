local base='Contents/mods/ConditionalSpeechVoicesCore/42/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
local wounds=require 'CSV/Wounds'
local traits=require 'CSV/Traits'
local function part(name,injury,bleed,cut,bitten)
 return {getType=function()return name end,HasInjury=function()return injury end,
  bitten=function()return bitten==true end,bleeding=function()return bleed end,isCut=function()return cut end,bandaged=function()return false end}
end
BodyPartType={ToString=function(value)return value end}
local function observed(...)
 local list={...}
 local facts={health=80,sneaking=false}
 wounds.readBody({size=function()return #list end,get=function(_,index)return list[index+1] end},facts)
 return facts
end
local arm=part('ForeArm_R',true,true,true)
local knee=part('LowerLeg_L',true,false,false)
local hand=part('Hand_L',true,true,false)
local f=observed(arm,knee)
assert(f.woundRegion==nil and f.bleedRegion=='Arm' and f.bleedingCut)
assert(observed(arm,hand).bleedRegion==nil)
assert(observed(part('Unknown',true,true,false)).bleedRegion==nil)
assert(observed(hand).woundRegion=='Hand' and not observed(hand).bleedingCut)
assert(not observed(knee,part('Unknown',nil,false,false)).woundRegion)

local catalog={}
local clips={}
for id,entry in pairs(wounds.slots)do catalog[id]={id=id,group=entry.group,text=id};clips[id]=true end
local pack={extras={approved=true,catalog=catalog},expressions={approved=false},data={groups={Bleeding={
 {id='Bleeding_1'},{id='Bleeding_2'},{id='Bleeding_3'}}}}}
local V={bank=function()return pack end,extended=function()return true end,clip=function(_,id)return clips[id] end,
 now=function()return 200000 end,localize=function(_,line)return line end,
 choose=function(group)return (pack.data.groups[group] or {})[1] end,contextLine=function()end,
 finite=function(n)return type(n)=='number' end}
package.loaded['CSV/Extras']={approved=true}
local C={preferences=function()return {} end}
require('CSV/Selection').install(C,V)
local actor={}
local function choose(group,facts)
 return C.chooseBaseLine(actor,'test',group,2,4,facts)
end
assert(choose('Bleeding',f).id=='BleedingArm_1')
assert(choose('Injured',observed(knee)).id=='InjuredLeg_1')
assert(not choose('Injured',observed(knee,arm)))
clips.BleedingArm_1=nil;clips.Bleeding_1=true
assert(choose('Bleeding',f).id=='Bleeding_1')
assert(choose('Bleeding',observed(arm,hand)).id=='Bleeding_1')
clips.BleedingHand_1=nil
assert(choose('Bleeding',observed(hand)).id=='BleedingUnspecified_1')
assert(not choose('Bleeding',observed(knee)))
local bittenHand=part('Hand_L',true,false,false,true)
local bittenCalf=part('LowerLeg_R',true,true,false,true)
assert(choose('Injured',observed(bittenHand,knee)).id=='BiteHand_1')
assert(choose('Injured',observed(bittenHand,bittenCalf)).id=='BiteUnspecified_1')
assert(choose('Bleeding',observed(bittenHand,bittenCalf)).id=='BiteLeg_1')
assert(choose('Bleeding',observed(bittenHand,hand)).id=='BleedingUnspecified_1','a separate bleed cannot claim a bite')
clips.BiteHand_1=nil
assert(choose('Injured',observed(bittenHand)).id=='BiteUnspecified_1')
clips.BiteUnspecified_1=nil
assert(choose('Injured',observed(bittenHand)).id=='InjuredHand_1','old packs still have a wound reaction')
local risk={traits={hemophobic=true},panic=1,sneaking=false}
risk.bloodOnSkin=true;risk.bleeding=1
assert(traits.context('Stress',risk)=='BloodAversion')
risk.bleeding=0
assert(traits.context('Stress',risk)=='BloodOnSkin')
risk.bloodOnSkin=false
assert(not traits.context('Stress',risk))
risk.bloodOnSkin=true;risk.traits={}
assert(not traits.context('Stress',risk))
local sem=require 'CSV/SemanticSpeech'
assert(not sem.allowed({id='Whisper_Bleeding_1'},observed(hand)))
assert(not sem.allowed({id='Whisper_DisinfectDone_1'},{outcome={selfTreatment=false}}))
assert(sem.allowed({id='DisinfectDone_1'},{outcome={selfTreatment=true}}))
assert(not require('CSV/VoiceCoverage').pools['context / treeFelled'])
local retired=require 'CSV/VoiceRetired'
for _,id in ipairs({'ChopTree_1','Expr_slurred_ChopTree_1','Whisper_ChopTree_3','Whisper_MultiHit_1','Whisper_RepeatedHit_3'})do assert(retired[id],id) end
V.config={enabled=true};V.languageSupported=function()return true end;V.voice=function()return 'test' end
package.loaded['CSV/Core']=V
local injury=require 'CSV/Injury'
local victim={isLocalPlayer=function()return true end,isDead=function()return false end}
local recorded={}
injury.emit=function(_,kind)table.insert(recorded,kind)end
injury.observe(victim,{[0]={scratch=1,bite=0,health=98}},1000)
injury.players[victim].clockKnown=true
injury.observe(victim,{[0]={scratch=.7,bite=.5,bitten=false,health=94}},1250)
assert(#recorded==1 and recorded[1]=='scratch')
injury.observe(victim,{[0]={scratch=.7,bite=1,bitten=true,health=90}},1500)
assert(#recorded==2 and recorded[2]=='bite')
print('PASS bites, injury locations, cuts, blood stains, ambiguous injuries, pack fallback and self-treatment')
