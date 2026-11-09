local UI=require 'CSV/DebugUI'
local function t(key)return getText('UI_CSV_Aud_'..key)end
local A={entries={

 {group='Pain'}, {group='Angry'},
 {group='FoodRotten'}, {group='FoodEaten'},
 {group='Unhappy'}, {group='Stress'},
 {group='Hypothermia'}, {group='Endurance'},
 {group='GunJammed'},
 {group='ReliefAnger'}, {group='ReliefBoredom'}, {group='ReliefSobriety'},
 {group='ChamberEmpty'}, {group='AmmoCount'},
 {group='Bored'}, {group='Explore'},
 {group='AnimalTracks'},
 {group='SickFromFood'},
 {group='Panic'}, {group='Agoraphobic'},
 {group='Claustrophobic'}, {group='Hyperthermia'},
 {group='Drunk'}, {group='HasACold'},
 {group='LootWeapon'}, {group='LootFood'},
 {group='LootBandage'}, {group='LootPainMedicine'},
 {group='LootStomach'}, {group='LootAmmo'},
 {group='LootWater'}, {group='LootLight'}, {group='LootClothing'},
{group="WeaponBroken"},
{group="JamCleared"},
{group="WeaponReady"},
{group="FuelLow"},
{group="BatteryDead"},
{group="EngineFailed"},
{group="EngineRecovered"},
{group="VehicleCrowdDriver"},
{group="VehicleCrowdPassenger"},
{group="VehicleSiegeDriver"},
{group="VehicleSiegePassenger"},
{group="VehicleImpactDriver"},
{group="VehicleImpactPassenger"},
{group="VehicleKillDriver"},
{group="VehicleKillPassenger"},
{group="EngineStalled"},
{group="FuelEmpty"},
{group="HotwireDone"},
{group="CarAlarm"},
{group="HeadlightsFailed"},

{group="BandageDone"},
{group="DisinfectDone"},
{group="DoorLocked"},
{group="DoorBlocked"},
{group="LootCanOpener"},
{group="LootMagazine"},
{group="AfterZombieShaken"},
{group="AfterZombieSteady"},
{group="AfterHumanShaken"},
{group="AfterHumanSteady"},
{group="MortalFear"},
{group="HumanDanger"},
{group="StillAlive"},
{group="KeepHidden"},
{group="LostPerson"},
{group="FoundPerson"},
{group="PursuitUneasy"},
{group="PursuitSteady"},
{group="FriendMissing"},
{group="HumanGroup"},
{group="InjuryAftermath"},
{group="ShelterThreat"},
{group="ShelterAftermath"},
{group="DryCoping"},
{group="ExhaustedCoping"},
{group="StartleNormal"},
{group="StartleBrave"},
{group="StartleCowardly"},
{group="StartleDesensitized"},
{group="NicotineNeed"},
{group="BloodAversion"},
}}
function A.bank(V,group,voice)
 local tiers=voice and V.bank(voice).needTiers==1 and require('CSV/NeedTiers').slots[group]
 if tiers then
  local bank=V.bank(voice);local lines={}
  for i,id in ipairs(tiers)do lines[i]={id=id,text=bank.lines[id],group=group} end
  return lines
 end
 voice=voice or V.pack.voiceOrder[1]
 local bank=V.bank(voice);local data=bank.data;local catalog=bank.extras.catalog
 if not V.extended(voice) then return data.groups[group] or {} end
 if bank.native and bank.native.groups and bank.native.groups[group] then return bank.native.groups[group] end
 local X=require 'CSV/Conditions'
 if X.enabled and X.replacements[group] then
  local list={};local index=({Bored=2,Explore=2,AnimalTracks=1,FoodRotten=1})[group]
  if index then list[1]=data.groups[group][index] end
  for _,entry in pairs(catalog)do if entry.group==X.replacements[group] then list[#list+1]=entry end end
  require('CSV/Sort').sort(list,function(a,b)if group=='AmmoCount' then return tonumber(a.id:match('_(%d+)$'))<tonumber(b.id:match('_(%d+)$')) end;return a.id<b.id end);return list
 end
 if data.groups[group] then return data.groups[group]end
 local list={};for _,entry in pairs(catalog)do if entry.group==group then list[#list+1]=entry end end
 require('CSV/Sort').sort(list,function(a,b)if group=='AmmoCount' then return tonumber(a.id:match('_(%d+)$'))<tonumber(b.id:match('_(%d+)$')) end;return a.id<b.id end);return list
end
function A.open(player,selectedGroup)
 require 'ISUI/ISPanel'
 require 'ISUI/ISComboBox'
 require 'ISUI/ISButton'
 local V=require 'CSV/Core'
 if A.panel then if A.panel.stopPreview then A.panel.stopPreview()end;A.panel:removeFromUIManager() end
 local panel=ISPanel:new(100,80,820,510);panel:initialise();panel:instantiate()
 panel.moveWithMouse=true;panel.backgroundColor={r=0.08,g=0.08,b=0.08,a=0.97}
 A.panel=panel
 panel.entries={};local seen={}
 for _,entry in ipairs(A.entries)do if not seen[entry.group] then panel.entries[#panel.entries+1]=entry;seen[entry.group]=true end end
 local more={}
 for group in pairs(V.data.groups)do if not seen[group] then more[group]=true end end
 for _,bank in pairs(V.pack.voiceBanks)do
  for group in pairs(bank.data.groups)do if not seen[group] then more[group]=true end end
  for group in pairs(bank.native and bank.native.groups or {})do if not seen[group] then more[group]=true end end
 end
 for _,entry in pairs(require('CSV/Extras').catalog)do if not seen[entry.group] then more[entry.group]=true end end
 local names={};for group in pairs(more)do names[#names+1]=group end;require('CSV/Sort').sort(names)
 for _,group in ipairs(names)do panel.entries[#panel.entries+1]={group=group}end
 local delivery=ISComboBox:new(20,65,350,28,panel,nil);delivery:initialise();panel:addChild(delivery)
 if delivery.setEditable then delivery:setEditable(true)end
 for i,e in ipairs(panel.entries)do delivery:addOption(e.group);if e.group==selectedGroup then delivery.selected=i end end
 local voice=ISComboBox:new(390,65,410,28,panel,nil);voice:initialise();panel:addChild(voice)
 for _,id in ipairs(require('CSV/Pack').voiceOrder)do voice:addOption(require('CSV/Pack').voices[id].name)end
 for i,id in ipairs(V.pack.voiceOrder)do if id==V.voice(player)then voice.selected=i end end
 local sentence=ISComboBox:new(20,125,150,28,panel,nil);sentence:initialise();panel:addChild(sentence)
 local refreshActing
 local function refreshSentences()
  if panel.stopPreview then panel.stopPreview();panel.playback=nil end
  panel.contextResult=false;panel.status=UI.text('Ready')
  if sentence.clear then sentence:clear()else sentence.options={}end
  local group=panel.entries[delivery.selected].group
  if V.pack.extraVoices[V.pack.voiceOrder[voice.selected]]~=nil and #A.bank(V,group,V.pack.voiceOrder[voice.selected])==0 then
   for i,entry in ipairs(panel.entries)do if #A.bank(V,entry.group,V.pack.voiceOrder[voice.selected])>0 then delivery.selected=i;group=entry.group;break end end
  end
  for i,line in ipairs(A.bank(V,group,require('CSV/Pack').voiceOrder[voice.selected]))do sentence:addOption(group=='AmmoCount' and line.id:match('_(%d+)$') or tostring(i))end
  sentence.selected=1
  if refreshActing then refreshActing()end
 end
 delivery.onChange=refreshSentences;delivery.onChangeArgs={};voice.onChange=refreshSentences;voice.onChangeArgs={};refreshSentences()
 local situation,acting
 panel.status=UI.text('Ready');panel.sentence=''
 panel.prerender=function(self)
  ISPanel.prerender(self)
  self:drawText(getText('UI_CSV_Audition'),20,12,1,1,1,1,UIFont.Medium)
  self:drawText(t('Event'),20,42,1,1,1,1,UIFont.Small)
  self:drawText(t('Voice'),390,42,1,1,1,1,UIFont.Small)
  self:drawText(t('Sentence'),20,102,1,1,1,1,UIFont.Small)
  self:drawText(t('Acting'),190,102,1,1,1,1,UIFont.Small)
  if not self.contextResult then self.sentence=(A.bank(V,panel.entries[delivery.selected].group,require('CSV/Pack').voiceOrder[voice.selected])[sentence.selected] or {text=t('Missing')}).text end
  self:drawText(t('Situation'),20,285,1,1,1,1,UIFont.Small)
  local y=178;local row=''
  for word in self.sentence:gmatch('%S+')do
   local nextRow=row=='' and word or row..' '..word
   local width=getTextManager and getTextManager():MeasureStringX(UIFont.Small,nextRow) or #nextRow*8
   if width>775 and row~='' then self:drawText(row,20,y,1,1,1,1,UIFont.Small);y=y+20;row=word else row=nextRow end
  end
  self:drawText(row,20,y,1,1,1,1,UIFont.Small)

  if self.playback then
   local e=self.playback
   self:drawText(getText('UI_CSV_Playback')..': '..e.line..' / '..UI.playback(e),20,420,.8,.8,.8,1,UIFont.Small)
  end
  self:drawText(self.status,20,395,0.8,0.8,0.8,1,UIFont.Small)

 end
 local function stopPreview()
  if panel.playback then
   for _,e in ipairs(V.client.active)do if e==panel.playback and e.preview then V.client.cancel(e,'preview_stopped',false);break end end
  end
 end
 panel.stopPreview=stopPreview
 local play=ISButton:new(20,460,340,30,t('Listen'),panel,function(self)
  stopPreview();self.playback=nil
  local entry=panel.entries[delivery.selected]
  local selectedVoice=require('CSV/Pack').voiceOrder[voice.selected]
  local bank=A.bank(V,entry.group,selectedVoice)
  local index=sentence.selected
  local line=bank[index];if not line then self.status=t('Missing');return end;self.sentence=line.text
  local ok,reason,chosen
  local mode=situation and situation.selected or 1
  if mode==1 then
   self.contextResult=false
   local profile=acting.profiles[acting.selected]
   if profile~='normal' then
    if profile=='whisper' then chosen=require('CSV/Whispers').pick(V,selectedVoice,line)
    else chosen=require('CSV/Expressions').pick(V,selectedVoice,line,{},profile)end
    if not chosen or chosen.id==line.id then self.status=t('Unavailable');return end
   end
   ok,reason=V.client.preview(player,chosen and chosen.id or line.id,selectedVoice)
  else
   local facts
   if mode==3 then facts={sneaking=false,near=0,visible=0,recentThreat=false,panic=0}
   elseif mode==4 then facts={sneaking=true,near=0,visible=0,recentThreat=false,panic=0}
   elseif mode==5 then facts={sneaking=true,near=1,visible=1,recentThreat=true,panic=2,targeted=1,reactiveNear=1}
   elseif mode==6 then facts={sneaking=false,near=1,visible=1,recentThreat=true,panic=4,targeted=1,reactiveNear=1}end
   local group=entry.group
   local psychological={AfterZombieShaken='zombieKill',AfterZombieSteady='zombieKill',AfterHumanShaken='humanKill',AfterHumanSteady='humanKill',MortalFear='humanAttack',HumanDanger='humanAttack',StillAlive='escape',KeepHidden='hiddenPursuer',LostPerson='lostTarget',FoundPerson='reacquired',PursuitUneasy='pursuit',PursuitSteady='pursuit',FriendMissing='friendSearch',HumanGroup='humanGroup',InjuryAftermath='injurySurvived',ShelterThreat='raid',ShelterAftermath='raidSurvived'}
   if facts and psychological[entry.group] then
    group='Psychology'
    facts.psychology={kind=psychological[entry.group],verified=true,experience=entry.group:match('Steady$') and 'practiced' or 'uncertain',knownPursuer=true,seenBefore=true,intent=true,visibleCount=2,homeKnown=true}
   elseif entry.group=='ThreatCalm' or entry.group=='ThreatTense' or entry.group=='ThreatWhisper' then
    group='Threat'
   elseif entry.group:match('^Startle') then
    group='Startle'
    if facts then facts.nativeAlert=true;facts.traits={};local trait=({StartleBrave='brave',StartleCowardly='cowardly',StartleDesensitized='desensitized'})[entry.group];if trait then facts.traits[trait]=true end end
   elseif entry.group=='NicotineNeed' or entry.group=='BloodAversion' then
    group='Stress'
    if facts then facts.traits={};if entry.group=='NicotineNeed' then facts.traits.smoker=true;facts.nicotineStress=1 else facts.traits.hemophobic=true;facts.bleeding=1;facts.panic=math.max(1,facts.panic or 0)end end
   elseif require('CSV/OutcomeRules').groups[entry.group] then
    if facts then facts.outcome=require('CSV/OutcomeScenarios').evidence(entry.group) end
   elseif require('CSV/LootRules').groups[entry.group] then
    if facts then facts.loot=require('CSV/LootScenarios').facts(entry.group) end
   elseif entry.group=='GunJammed' or entry.group=='ChamberEmpty' or entry.group=='AmmoCount' then
    if facts then
     if entry.group=='GunJammed' then facts.jammed=true
     elseif entry.group=='ChamberEmpty' then facts.jammed=false;facts.hasChamber=true;facts.chamber=false;facts.rounds=5
     else facts.rounds=tonumber(line.id:match("_(%d+)$"));facts.jammed=false;facts.hasChamber=true;facts.chamber=true end
    end
   end
   ok,reason,chosen=V.client.contextPreview(player,selectedVoice,group,index,facts)
   self.contextResult=true;self.sentence=chosen and chosen.text or t('NoMatch')
  end
  if ok then for _,e in ipairs(V.client.active)do if e.player==player and e.preview then self.playback=e end end end
  self.status=ok and (t('Queued')..': '..(chosen and chosen.id or line.id)) or t('NotStarted')
 end);play:initialise();panel:addChild(play)
 local close=ISButton:new(660,460,140,30,t('Close'),panel,function(self)stopPreview();self:removeFromUIManager();A.panel=nil end)
 close:initialise();panel:addChild(close)
 situation=ISComboBox:new(20,310,780,28,panel,nil);situation:initialise();panel:addChild(situation)
 for _,key in ipairs({'Raw','Current','Safe','Sneaking','HiddenThreat','CloseThreat'})do situation:addOption(t(key))end
 acting=ISComboBox:new(190,125,610,28,panel,nil);acting:initialise();panel:addChild(acting)
 refreshActing=function()
  panel.contextResult=false;panel.status=UI.text('Ready')
  if acting.clear then acting:clear()else acting.options={}end
  acting.profiles={'normal'};acting:addOption(t('Original'));acting.selected=1
  local selectedVoice=require('CSV/Pack').voiceOrder[voice.selected]
  local line=A.bank(V,panel.entries[delivery.selected].group,selectedVoice)[sentence.selected]
  if not line then return end
  for _,profile in ipairs({'frightened','angry','sad','breathless','slurred','congested','stammer','whisper'})do
   local chosen
   if profile=='whisper' then chosen=require('CSV/Whispers').pick(V,selectedVoice,line)
   else chosen=require('CSV/Expressions').pick(V,selectedVoice,line,{},profile)end
   if chosen and chosen.id~=line.id then acting.profiles[#acting.profiles+1]=profile;acting:addOption(t(profile))end
  end
 end
 sentence.onChange=function()if panel.stopPreview then panel.stopPreview();panel.playback=nil end;refreshActing()end;sentence.onChangeArgs={};refreshActing()
 local function button(x,w,label,callback)
  local b=ISButton:new(x,245,w,28,label,panel,callback);b:initialise();panel:addChild(b);return b
 end
 button(20,65,'<',function()sentence.selected=math.max(1,sentence.selected-1);refreshActing()end)
 button(95,65,'>',function()sentence.selected=math.min(#sentence.options,sentence.selected+1);refreshActing()end)
 local stop=ISButton:new(380,460,260,30,t('Stop'),panel,stopPreview);stop:initialise();panel:addChild(stop)
 situation.onChange=function()
  panel.contextResult=false;panel.status=UI.text('Ready')
  if acting.setEnabled then acting:setEnabled(situation.selected==1)end
 end
 panel.controls={event=delivery,voice=voice,sentence=sentence,acting=acting,situation=situation,listen=play,stop=stop,close=close}
 panel:addToUIManager()
end
return A
