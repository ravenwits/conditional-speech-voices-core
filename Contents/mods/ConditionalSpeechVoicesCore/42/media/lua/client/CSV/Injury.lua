-- Traumatic injury evidence is independent of need recovery and speech cooldowns.
local I={players=setmetatable({},{__mode='k'}),sequence=0,context=setmetatable({},{__mode='k'})}
local call=require('CSV/Actors').call
local V=require 'CSV/Core'
local fields={bite='getBiteTime',scratch='getScratchTime',cut='getCutTime',deep='getDeepWoundTime',burn='getBurnTime',fracture='getFractureTime'}
local function finite(n)return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
local function eligible(p)
 return p and call(p,'isLocalPlayer')==true and call(p,'isDead')==false and V.config.enabled and V.languageSupported() and V.extended(V.voice(p))
end
function I.snapshot(p)
 local body=call(p,'getBodyDamage');local parts=call(body,'getBodyParts');local count=call(parts,'size')
 if type(count)~='number' then return nil end
 local out={}
 for index=0,count-1 do
  local part=call(parts,'get',index);local row={health=call(part,'getHealth'),bleeding=call(part,'getBleedingTime'),stitched=call(part,'stitched')}
  for key,method in pairs(fields)do row[key]=call(part,method) end
  out[index]=row
 end
 return out
end
local function state(p)
 local s=I.players[p];if not s then s={budget=0};I.players[p]=s end;return s
end
local function loss(before,after)
 return finite(before) and finite(after) and after<before
end
function I.emit(p,kind,source,part)
 if not eligible(p) then return false end
 local s=state(p);local now=V.now()
 -- Several native notifications in one engine update describe one injury episode.
 if s.emittedAt==now then return false end
 s.emittedAt=now;I.sequence=I.sequence+1
 require('CSV/State').record(p,'physicalInjury');require('CSV/State').record(p,'acute')
 local trace=require('CSV/Trace')
 local t=trace.begin(p,'AcutePain',source,{acute=true})
 trace.step(t,'injury_confirmed',kind,{part=part,event=I.sequence})
 if require('CSV/NativeVoice').supported(V.voice(p)) then
  require('CSV/ProductionReport').observe(V.voice(p)..'_injury_detected_'..kind,{acute=true})
  trace.step(t,'delegated','await_native_'..V.voice(p)..'_pain');return true
 end
 local previous=I.context[p];I.context[p]=I.sequence
 local ok,err=pcall(trace.call,t,p,require('ConditionalSpeech_Core').generateSpeechFrom,p,'AcutePain',4,4,false,true)
 I.context[p]=previous
 if not ok then error(err)end
 return true
end
function I.observe(p,parts,now)
 if not eligible(p) then I.players[p]=nil;return end
 local s=state(p);now=now or V.now()
 if not parts then s.before=nil;s.pending=nil;s.lastAt=nil;return end
 local previous=s.before;local continuous=previous and s.lastAt and now-s.lastAt<=2000
 local kind,where
 if continuous then
  for index,row in pairs(parts)do
   local old=previous[index]
   if old then for name in pairs(fields)do
    local a,b=old[name],row[name]
    if finite(a) and finite(b) and b>0 and not (old.stitched==true and row.stitched==false and (name=='scratch' or name=='deep')) then
     if b>a+0.00001 and (name~='deep' or a==0) then kind=name;where=index;break end
     -- Native bite healing is at most 0.0001 * multiplier per update.
     -- Twice that accumulated allowance plus float tolerance is conservative.
     if (name=='bite' or name=='scratch' or name=='cut') and s.clockKnown and a-b>(s.budget-(s.lastBudget or s.budget))*(name=='bite' and 0.0002 or 0.001)+0.001 and loss(old.health,row.health) then kind='bite';where=index;break end
    end
   end end
   if kind then break end
  end
 end
 if s.pending then
  if now-s.pending.at<=1000 then
   for index,row in pairs(parts)do local old=s.pending.before[index]
    local chronic=not old or not finite(old.bleeding) or old.bleeding>0
    if old then for name in pairs(fields)do if not finite(old[name]) or old[name]>0 then chronic=true end end end
    if old and not chronic and loss(old.health,row.health) then kind=kind or 'weapon';where=where or index;break end
   end
  else require('CSV/ProductionReport').observe('injury_weapon_unconfirmed',{});s.pending=nil end
 end
 s.before=parts;s.lastAt=now;s.lastBudget=s.budget;s.clockKnown=nil
 if kind then
  s.pending=nil
  -- Direct post-damage callbacks already represented this snapshot's changes.
  if not s.directSinceSample then I.emit(p,kind,'body_injury_transition',where) end
 end
 s.directSinceSample=nil
end
function I.signal(p,kind,amount)
 if not eligible(p) or not finite(amount) or amount<=0 then return end
 local s=state(p)
 if kind=='WEAPONHIT' then
  -- Native callback is BEFORE hit validation/damage, including avoided hits.
  local before=I.snapshot(p)
  if before and not s.pending then s.pending={at=V.now(),before=before};require('CSV/ProductionReport').observe('injury_weapon_signal',{}) end
 elseif kind=='FALLDOWN' or kind=='CARHITDAMAGE' or kind=='CARCRASHDAMAGE' or kind=='FIRE' then
  if kind=='FIRE' and s.fireActive then return end
  if kind=='FIRE' then s.fireActive=true end
  s.directSinceSample=true
  I.emit(p,kind,'native_damage_applied')
 elseif s.pending then
  -- A simultaneous physiological/unknown damage source makes bare health loss ambiguous.
  s.pending=nil
 end
 -- Hunger, poison, infection, bleeding and unknown names are not trauma events.
end
function I.tick()
 local now=V.now();local multiplier=call(getGameTime and getGameTime(),'getMultiplier')
 for index=0,getNumActivePlayers()-1 do
  local p=getSpecificPlayer(index)
  if eligible(p) then
   local s=state(p)
   local known=finite(multiplier) and multiplier>=0
   s.clockKnown=s.clockKnown~=false and known
   if known then s.budget=s.budget+multiplier end
   if call(p,'isOnFire')==false then s.fireActive=false end
   if not s.nextRead or now>=s.nextRead then
    s.nextRead=now+250;I.observe(p,I.snapshot(p),now)
   end
  elseif p then I.players[p]=nil end
 end
end
return I
