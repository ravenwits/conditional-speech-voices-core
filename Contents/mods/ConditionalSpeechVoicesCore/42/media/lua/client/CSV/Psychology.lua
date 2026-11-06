local P={players=setmetatable({},{__mode='k'}),context=setmetatable({},{__mode='k'}),nextTick=0}
local A=require 'CSV/Actors'
local E=require 'CSV/Experience'
local R=require 'CSV/PsychologyRules'
local V=require 'CSV/Core'
local call=A.call
local Policy=require 'CSV/PsychologyPolicy'
local function state(p)
 local s=P.players[p];if not s then s={queue={},last={},seenIds={},people=setmetatable({},{__mode='k'})};P.players[p]=s end;return s
end
local function eligible(p)return V.config.enabled and require('CSV/Core').languageSupported() and call(p,'isLocalPlayer')==true and call(p,'isDead')==false and V.extended(V.voice(p)) end
function P.atShelter(p)
 local home=(call(p,'getModData') or {}).csvShelter
 if type(home)~='table' or not V.finite(home.x) or not V.finite(home.y) or not V.finite(home.z) then return false end
 return math.abs(p:getX()-home.x)<=12 and math.abs(p:getY()-home.y)<=12 and p:getZ()==home.z
end
P.eligible=eligible
P.state=state
function P.encounter(p,field)
 if not eligible(p) then return end
 local s=state(p);s.encounters=s.encounters or {};local now=V.now()
 if not s.encounters[field] or now-s.encounters[field]>=60000 then E.encounter(p,field)end
 s.encounters[field]=now
end
function P.queue(p,e)
 if not eligible(p) or not R.events[e.kind] then return end
 local s=state(p);local now=V.now()
 if e.eventId then
  if s.seenIds[e.eventId] then return end;s.seenIds[e.eventId]=now
 end
 for id,t in pairs(s.seenIds)do if now-t>600000 then s.seenIds[id]=nil end end
 e.verified=true;e.at=now
 local field=e.kind=='zombieKill' and 'zombie' or e.kind=='humanKill' and 'human' or e.kind=='injurySurvived' and 'injury' or e.kind=='raidSurvived' and 'raid'
 e.experience=E.level(p,field or e.kind=='raid' and 'raid' or 'human')
 if field then E.mark(p,field)end
 if e.observed==false then return end -- A verified off-screen death must not reveal itself through speech.
 if e.kind=='humanAttack' then
  P.encounter(p,'human')
  require('CSV/State').invalidate(p)
  s.humanUntil=now+Policy.knownHumanThreat;s.wasThreatened=true
  if P.atShelter(p) then s.shelterAttackAt=now end
 end
 if e.kind=='humanKill' then s.humanUntil=now+Policy.knownHumanThreat end
 -- Counters record every verified kill. Speech is deliberately much less frequent.
 if s.last[e.kind] and now-s.last[e.kind]<(e.kind=='zombieKill' and Policy.killInterval(V.client.preferences().frequency) or Policy.repeatInterval) then return end
 -- A new verified event replaces an obsolete pending event of the same kind.
 -- Keep one entry, but do not let the first kill's age discard a later kill.
 for i,old in ipairs(s.queue)do if old.kind==e.kind then
  e.nextTry=old.nextTry;s.queue[i]=e
  require('CSV/ProductionReport').observe('psychology_refreshed',{psychologyKind=e.kind,actorKind=e.actorKind,experience=e.experience})
  return
 end end
 if #s.queue>=Policy.queueLimit then
  local discard=1
  for i,old in ipairs(s.queue)do
   local candidate=s.queue[discard]
   if R.priority(old)<R.priority(candidate) or R.priority(old)==R.priority(candidate) and old.at<candidate.at then discard=i end
  end
  if R.priority(e)<R.priority(s.queue[discard]) then return end
  table.remove(s.queue,discard)
 end
 s.queue[#s.queue+1]=e
 require('CSV/ProductionReport').observe('psychology_queued',{psychologyKind=e.kind,actorKind=e.actorKind,experience=e.experience})
end
function P.facts(p)
 local s=P.players[p] or {}
 return s.humanUntil~=nil and V.now()<s.humanUntil,P.context[p]
end
function P.fact(p,e,attacker)
 if not eligible(p) then
  -- Keep upstream text for other voices/languages or when this addon is disabled,
  -- but use the verified killer instead of restoring the nearest-player guess.
  if e.kind=='zombieKill' and e.observed~=false and call(p,'isLocalPlayer')==true and call(p,'isDead')==false then
   local s=state(p);local now=V.now()
   if (not s.fallbackKill or now-s.fallbackKill>=90000) and ZombRand(100)<12 then
    s.fallbackKill=now;require('ConditionalSpeech_Core').generateSpeechFrom(p,'Kill',1,1,false,false)
   end
  end
  return
 end
 if e.kind=='humanAttack' and not attacker and e.attackerKey then
  for body,t in pairs(state(p).people)do if A.key(body)==e.attackerKey and call(p,'CanSee',body)==true then attacker=body;break end end
 end
 if e.kind=='humanAttack' then require('CSV/Concealment').record(p,attacker)end
 if e.kind=='humanAttack' and attacker then
  local s=state(p);s.pursuer=attacker;s.pursuerSeen=call(p,'CanSee',attacker)==true
 end
 P.queue(p,e)
end
function P.outgoing(p,target)
 require('CSV/State').invalidate(p)
 if not eligible(p) then return end
 local kind=A.kind(target)
 if kind=='npc' or kind=='player' then P.encounter(p,'human');state(p).humanUntil=V.now()+Policy.knownHumanThreat
 elseif kind=='zombie' then P.encounter(p,'zombie')end
end
function P.intent(p,target,mode)
 if not eligible(p) or (A.kind(target)~='npc' and A.kind(target)~='player') or call(p,'CanSee',target)~=true then return false end
 local s=state(p);s.track={body=target,mode=mode,seenAt=V.now(),visible=true,started=V.now()}
 if mode=='pursuit' then P.queue(p,{kind='pursuit',intent=true,subject=target})end
 return true
end
function P.observe(p)
 if not eligible(p) then return end
 local s=state(p);local now=V.now();local f=require('CSV/State').capture(p)
 if (f.attacking or 0)>0 then P.encounter(p,'zombie')end
 require('CSV/PeoplePerception').update(P,p,s,f,now)
 require('CSV/RecoveryEpisodes').update(P,p,s,f,now)
 require('CSV/Tracking').update(P,p,s,f,now)
 require('CSV/SpeechQueue').update(P,p,s,f,now)
end

local function safe(fn,...)
 local ok,err=require('CSV/Observers').run('psychology.player',fn,...);if not ok then P.error=true end
end
function P.tick()
 if V.now()<P.nextTick then return end;P.nextTick=V.now()+Policy.perceptionInterval
 if P.observer then P.observer:settle()end
 for i=0,getNumActivePlayers()-1 do safe(P.observe,getSpecificPlayer(i))end
end
function P.install()
 return require('CSV/CombatClientAdapter').install(P)
end
require('CSV/State').psychologyFacts=P.facts
return P
