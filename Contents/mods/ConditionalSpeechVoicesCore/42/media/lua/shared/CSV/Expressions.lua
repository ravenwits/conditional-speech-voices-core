local M=require('CSV/Pack').expressions
local indexes=setmetatable({},{__mode='k'})
local function index(bank)
 if indexes[bank] then return indexes[bank] end
 local result={sources={},groups={}}
 for _,entry in pairs(bank.catalog)do
  local source=result.sources[entry.source] or {};result.sources[entry.source]=source;source[entry.profile]=entry
  if entry.groupFallback then
   local group=result.groups[entry.group] or {};result.groups[entry.group]=group
   local pool=group[entry.profile] or {};group[entry.profile]=pool;pool[#pool+1]=entry
  end
 end
 indexes[bank]=result
 return result
end
function M.pick(V,voice,line,facts,forced,player)
 if not M.approved or not V.extended(voice) or not line then return line end
 local bank=V.bank and V.bank(voice).expressions or M
 if not bank.approved then return line end
 local routes=index(bank)
 local options=routes.sources[line.id] or {};local fallback=routes.groups[line.group] or {}
 local f=facts or {};if f.sneaking==true and not require('CSV/Concealment').open(f) and not require('CSV/Concealment').active(f) and not forced then return line end
 local levels=f.levels or {};local choices={}
 if forced then choices[1]=forced
 else
  if require('CSV/Concealment').active(f) and line.group=='ThreatTense' then choices[#choices+1]='frightened' end
  if (f.panic or 0)>=3 and (f.near or 0)==0 and not require('CSV/Concealment').active(f) and (line.group=='Panic' or line.group=='Agoraphobic' or line.group=='Claustrophobic') then choices[#choices+1]='stammer' end
  if (f.panic or 0)>=3 and (require('CSV/Concealment').active(f) or ((f.near or 0)>0 and f.reactiveNear~=0) or line.group=='Agoraphobic' or line.group=='Claustrophobic') then choices[#choices+1]='frightened' end
  if (f.endurance or 0)>=2 then choices[#choices+1]='breathless' end
  if (f.anger or levels.Angry or 0)>=2 then choices[#choices+1]='angry' end
  if (f.unhappy or levels.Unhappy or 0)>=3 then choices[#choices+1]='sad' end
  if (f.heat or levels.Hyperthermia or 0)>=2 then choices[#choices+1]='stammer' end
  if (f.drunk or levels.Drunk or 0)>=2 then choices[#choices+1]='slurred' end
  if (f.coldSymptoms or levels.HasACold or 0)>=1 then choices[#choices+1]='congested' end
 end
 local history=player and V.client and V.client.history[player] or {}
 local hurried=(f.directAttack or 0)>0 or (f.activePursuit or 0)>0 or (f.endurance or 0)>=3
 local function earlier(a,b)
  if hurried then
   local ac,bc=V.clip(voice,a.id),V.clip(voice,b.id)
   if ac.duration~=bc.duration then return ac.duration<bc.duration end
  end
  return a.id<b.id
 end
 for _,profile in ipairs(choices)do
  local entry=options[profile]
  if entry and V.clip(voice,entry.id) and (forced or require('CSV/SemanticSpeech').allowed(entry,f)) then return entry end
  -- Raw previews never silently substitute a different sentence.
  if not forced then
   local best,stamp
   for _,candidate in ipairs(fallback[profile] or {})do
    local used=history[candidate.id] or 0
    if V.clip(voice,candidate.id) and require('CSV/SemanticSpeech').allowed(candidate,f) and not require('CSV/SemanticSpeech').recent(history,candidate,getTimestampMs()) and (not best or used<stamp or (used==stamp and earlier(candidate,best))) then best=candidate;stamp=used end
   end
   if best then return best end
  end
 end
 return line
end
function M.source(id)if not M.approved then return nil end;local e=M.catalog[id];return e and e.source end
return M
