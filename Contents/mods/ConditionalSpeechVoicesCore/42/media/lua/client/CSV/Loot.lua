local L={players=setmetatable({},{__mode='k'}),nextTick=0}
local V=require 'CSV/Core'
local State=require 'CSV/State'
local Rules=require 'CSV/LootRules'
local function read(fn)return require('CSV/ApiDiagnostics').read('Loot.read',fn)end
local call=require('CSV/Actors').call
local function is(item,class)return read(function()return instanceof(item,class)end)==true end
local function full(item)return call(item,'getFullType')end
local function ammoKey(item)
 local a=call(item,'getAmmoType');if not a then return nil end
 if type(a)=='string' then return a end
 local key=call(a,'getItemKey');local id=key and (call(key,'id') or call(key,'getFullType'))
 if type(id)~='string' then return nil end
 return id:find('.',1,true) and id or ('Base.'..id)
end
-- Explicit vanilla package mappings; unknown modded boxes do not invent compatibility.
local boxes={['Base.Bullets9mmBox']={'Base.Bullets9mm',50},['Base.Bullets38Box']={'Base.Bullets38',50},['Base.Bullets357Box']={'Base.Bullets357',50},['Base.Bullets44Box']={'Base.Bullets44',20},['Base.Bullets45Box']={'Base.Bullets45',50},['Base.ShotgunShellsBox']={'Base.ShotgunShells',25},['Base.308Box']={'Base.308Bullets',20},['Base.556Box']={'Base.556Bullets',20},['Base.3030Box']={'Base.3030Bullets',20}}
local cartons={};for box,data in pairs(boxes)do cartons[box:gsub('Box$','Carton')]={data[1],data[2]*12}end
for key,data in pairs(cartons)do boxes[key]=data end
function L.ammoUnits(item,key)
 if not key then return 0 end
 local t=full(item);if t==key then return math.max(1,call(item,'getCount') or 1) end
 local box=boxes[t];if box and box[1]==key then return box[2] end
 if ammoKey(item)==key then
  local n=call(item,'getCurrentAmmoCount');if type(n)=='number' then return n+(call(item,'isRoundChambered')==true and 1 or 0)end
 end
 return 0
end
-- Iterative traversal visits each container once. Large bags do not suppress loot speech.
function L.inventory(player)
 local result,seen={},{};local complete=true
 local first=call(player,'getInventory');local pending=first and {first} or {}
 if not first then return result,false end
 while #pending>0 do
  local container=table.remove(pending)
  if not seen[container] then
   seen[container]=true
   local items=call(container,'getItems')
   if not items then complete=false else
    for i=0,items:size()-1 do
     local item=items:get(i)
     if item then
      result[#result+1]=item
      if is(item,'InventoryContainer') then
       local child=call(item,'getInventory');if child then pending[#pending+1]=child else complete=false end
      end
     else complete=false end
    end
   end
  end
 end
 L.metrics=L.metrics or {scans=0,items=0,maxItems=0}
 L.metrics.scans=L.metrics.scans+1;L.metrics.items=L.metrics.items+#result;L.metrics.maxItems=math.max(L.metrics.maxItems,#result)
 return result,complete
end
local function weaponUsable(item)
 local condition,maximum=call(item,'getCondition'),call(item,'getConditionMax')
 return is(item,'HandWeapon') and type(condition)=='number' and type(maximum)=='number' and maximum>0 and condition/maximum>=.25 and call(item,'isBroken')~=true
end
function L.workingLight(item)
 return call(item,'canBeActivated')==true and call(item,'canEmitLight')==true and (call(item,'getLightStrength') or 0)>0 and (call(item,'getCurrentUsesFloat') or 0)>0 and (call(item,'getCondition') or 0)>0 and call(item,'isBroken')==false
end
function L.survivalFacts(player,item,state,f)
 f.thirst=state.thirst;f.cold=state.cold;f.heat=state.heat
 local fluid=call(item,'getFluidContainer')
 if fluid and Fluid and Fluid.Water then
  f.cleanWater=call(fluid,'contains',Fluid.Water)==true and call(fluid,'isMixture')==false and (call(fluid,'getAmount') or 0)>.01 and call(fluid,'canPlayerEmpty')==true and type(call(fluid,'getCapacity'))=='number' and call(fluid,'getCapacity')<=3
 end
 local square=call(player,'getSquare');local number=call(player,'getPlayerNum')
 local light=number~=nil and call(square,'getLightLevel',number) or nil
 if type(light)=='number' then f.dark=light<.35;f.lightLevel=light end
 f.workingLight=L.workingLight(item)
 if is(item,'Clothing') then
  local slot=call(item,'getBodyLocation');local insulation=call(item,'getInsulation');local wet=call(item,'getWetness');local holes=call(item,'getHolesNumber')
  local condition,maximum=call(item,'getCondition'),call(item,'getConditionMax')
  if slot and type(insulation)=='number' and type(wet)=='number' and wet<=5 and holes==0 and type(condition)=='number' and type(maximum)=='number' and maximum>0 and condition/maximum>=.5 then
   local ok,worn=pcall(function()return player:getWornItem(slot)end)
   if ok and worn~=item then
    local oldInsulation,oldWet=0,0;if worn then oldInsulation=call(worn,'getInsulation');oldWet=call(worn,'getWetness') end
    if type(oldInsulation)=='number' and type(oldWet)=='number' then
     f.betterDryClothing=insulation>=oldInsulation+.15 or (oldWet>=30 and insulation>=oldInsulation and insulation>0)
    end
   end
  end
 end
end
local function inventoryIndex(items,item)
 local index={types={},ammo={}}
 local function add(key,n)if key then index.ammo[key]=(index.ammo[key] or 0)+n end end
 for _,held in ipairs(items)do
  if held~=item then
   local t=full(held)
   if t then
    add(t,math.max(1,call(held,'getCount') or 1))
    if (call(held,'getCondition') or 0)>0 then index.types[t]=(index.types[t] or 0)+1 end
   end
   local box=boxes[t]
   if box then add(box[1],box[2]) end
   local key=ammoKey(held)
   if key and key~=t and not (box and box[1]==key) then
    local n=call(held,'getCurrentAmmoCount')
    if type(n)=='number' then add(key,n+(call(held,'isRoundChambered')==true and 1 or 0))end
   end
  end
 end
 return index
end
function L.complements(item,items,f,index)
 index=index or inventoryIndex(items,item)
 local function match(t,key)return type(key)=='string' and (t==key or t=='Base.'..key) end
 local opener=full(item)=='Base.TinOpener' and (call(item,'getCondition') or 0)>0
 local sealed,otherOpener=false,false
 for _,held in ipairs(items)do if held~=item then
  if full(held)=='Base.TinOpener' and (call(held,'getCondition') or 0)>0 then otherOpener=true end
  local recipe=call(held,'getOpeningRecipe')
  if (recipe=='OpenCannedFood' or recipe=='Base.OpenCannedFood') and call(held,'isRotten')==false and call(held,'isBurnt')==false then sealed=true end
  if weaponUsable(held) and call(held,'isRanged')==true and call(held,'isContainsClip')==false and (call(item,'getCondition') or 0)>0 and match(full(item),call(held,'getMagazineType')) then
   local key=call(held,'getMagazineType')
   local count=(index.types[key] or 0)+(index.types['Base.'..key] or 0)
   if match(full(held),key) and (call(held,'getCondition') or 0)>0 then count=count-1 end
   if count==0 then f.neededMagazine=true end
  end
 end end
 f.neededOpener=opener and sealed and not otherOpener
end
function L.snapshot(player,item)
 local f={};local state=State.capture(player)
 f.hunger=state.hunger;f.pain=state.pain
 if (state.sick or 0)>0 then f.foodSickness=read(function()return player:getStats():get(CharacterStat.FOOD_SICKNESS)end) end
 local container=call(item,'getContainer');f.owned=container and call(container,'isInCharacterInventory',player)==true or false
 f.itemType=full(item)
 L.survivalFacts(player,item,state,f)
 f.openWounds=read(function()
  local n=0;local parts=call(call(player,'getBodyDamage'),'getBodyParts');if not parts then return nil end
  for i=0,parts:size()-1 do local b=parts:get(i)
   if b:bandaged()==false and (b:bleeding() or b:scratched() or b:isCut() or b:bitten() or b:deepWounded() or b:getBurnTime()>0) then n=n+1 end
  end
  return n
 end)
 local bandagePower=call(item,'getBandagePower')
 f.bandage=call(item,'isCanBandage')==true and type(bandagePower)=='number' and bandagePower>0 and f.itemType~=nil and not f.itemType:find('Dirty') and call(item,'isDirty')~=true
 f.painMedicine=f.itemType=='Base.Pills' and (call(item,'getCurrentUsesFloat') or 0)>0
 if is(item,'Food') then
  local raw=call(item,'isbDangerousUncooked');local cooked=call(item,'isCooked')
  local safe=call(item,'isRotten')==false and call(item,'isBurnt')==false and (raw==false or cooked==true) and call(player,'isKnownPoison',item)==false
  local script=call(item,'getScriptItem')
  safe=safe and call(script,'isCantEat')==false
  f.stomachAid=safe and f.itemType=='Base.LemonGrass'
  f.edible=safe and call(item,'isSpice')==false and (call(item,'getHungerChange') or 0)<0
 end
 local items,complete=L.inventory(player);f.inventoryComplete=complete
 if not complete then return f end
 local index=inventoryIndex(items,item)
 L.complements(item,items,f,index)
 f.otherWorkingLight=false;for _,held in ipairs(items)do if held~=item and L.workingLight(held) then f.otherWorkingLight=true;break end end
 local ownKey=ammoKey(item);local otherMelee,otherGun=false,false
 local ownReserve=ownKey and index.ammo[ownKey] or 0
 for _,other in ipairs(items)do if other~=item then
  if weaponUsable(other) then
   local ranged=call(other,'isRanged');local key=ammoKey(other)
   if ranged==false then otherMelee=true end
   if ranged==true and key and key==ownKey then otherGun=true end
   if ranged==true and key and L.ammoUnits(item,key)>0 then
    local reserve=index.ammo[key] or 0
    local cap=call(other,'getMaxAmmo') or 0
    if reserve<=math.max(20,cap*2) then f.compatibleAmmo=true;f.reserve=reserve;f.capacity=cap end
   end
  end
 end end
 if weaponUsable(item) then
  if call(item,'isRanged')==false then f.usefulWeapon=not otherMelee
  elseif call(item,'isRanged')==true and ownKey and call(item,'isJammed')==false then f.usefulWeapon=not otherGun and ownReserve+L.ammoUnits(item,ownKey)>0 end
 end
 return f
end
local function observe(reason,f)
 local report=require 'CSV/ProductionReport'
 report.observe('loot_'..reason,{lootKind=f and Rules.classify(f),lootItem=f and f.itemType,lootReserve=f and f.reserve,lootHunger=f and f.hunger,lootPain=f and f.pain,lootThirst=f and f.thirst,lootDark=f and f.dark,lootWater=f and f.cleanWater,lootLight=f and f.workingLight,lootOtherLight=f and f.otherWorkingLight,lootClothing=f and f.betterDryClothing,lootCold=f and f.cold})
end
function L.received(player,item)
 if not player or not player:isLocalPlayer() or player:isDead() or not V.extended(V.voice(player)) or not V.config.enabled or not require('CSV/Core').languageSupported() then return false end
 local prefs=V.client.preferences();local mode,gaps=Rules.settings(prefs)
 if mode==0 then observe('disabled_by_option');return true end
 local now=V.now();local s=L.players[player] or {pending={},last={},seen={}};L.players[player]=s
 -- Persist a bounded list of item IDs so dropping/reloading the save cannot farm comments.
 local md=player:getModData();md.csvLootSeen=md.csvLootSeen or {};local seen=md.csvLootSeen
 local id=call(item,'getID');if id==nil then observe('unknown_item_id');return false end
 id=tostring(id)
 for _,old in ipairs(seen)do if old==id then observe('repeat_item');return true end end
 local f=L.snapshot(player,item);local group,reason=Rules.classify(f)
 if not group then observe(reason,f);return false end
 if not Rules.allowed(group,prefs) then observe('needs_only',f);return true end
 seen[#seen+1]=id;if #seen>128 then table.remove(seen,1)end
 if s.last[group] and now-s.last[group]<gaps.category then observe('category_cooldown',f);return true end
 if not s.pending[group] then s.pending[group]={item=item,at=now,group=group}end
 observe('queued',f);return true
end
function L.update(player)
 local s=L.players[player];if not s then return end
 local now=V.now();local voice=V.voice(player)
 local prefs=V.client.preferences();local mode,gaps=Rules.settings(prefs)
 if mode==0 then s.pending={};return end
 if player:isDead() or not V.extended(voice) or not V.config.enabled or not require('CSV/Core').languageSupported() then s.pending={};return end
 local candidates={};for _,e in pairs(s.pending)do candidates[#candidates+1]=e end
 table.sort(candidates,function(a,b)if a.at==b.at then return a.group<b.group end;return a.at<b.at end)
 for _,e in ipairs(candidates)do
  local f=L.snapshot(player,e.item);local group=Rules.classify(f)
  local pendingStatus=require('CSV/Pending').status(now,group==e.group and Rules.allowed(e.group,prefs),e.at+90000,s.nextAttempt)
  if pendingStatus=='expired' or pendingStatus=='cancelled' then s.pending[e.group]=nil;observe('expired_or_resolved',f)
  elseif not require('ConditionalSpeech_Core').enabledPhraseSet('FoundLoot') then s.pending[e.group]=nil;observe('disabled',f)
  elseif pendingStatus=='ready' and (not s.last[e.group] or now-s.last[e.group]>=gaps.category) then
   local state=State.capture(player)
   -- Loot comments wait for verified safety, including while crouched.
   if state.near==0 and state.visible==0 and state.recentThreat==false then
    state.loot=f
    local line,decision=V.client.plan(player,voice,e.group,1,1,state,V.client.preferences())
    if line and decision.mode=='spoken' then
     s.nextAttempt=now+5000;State.loot=State.loot or setmetatable({},{__mode='k'});State.loot[player]=f
     local ok,err=pcall(require('ConditionalSpeech_Core').generateSpeechFrom,player,e.group,1,1,false,false)
     State.loot[player]=nil
     if not ok then error(err)end
     local attempt=V.client.lastAttempt[player]
     if require('CSV/Pending').accepted(attempt,e.group) then s.pending[e.group]=nil;s.last[e.group]=now;observe('played',f)end
     break
    end
   end
  end
 end
end
function L.tick()
 local now=V.now();if now<L.nextTick then return end;L.nextTick=now+1000
 for player in pairs(L.players)do L.update(player)end
end
return L
