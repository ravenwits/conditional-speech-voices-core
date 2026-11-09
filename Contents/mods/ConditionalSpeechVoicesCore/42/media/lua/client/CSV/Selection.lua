local M={metrics={indexBuilds=0,indexed=0,candidates=0}}
-- Pack catalogs are immutable after registration. Cache membership only;
-- clip availability, preferences and repetition remain live on each selection.
local catalogs=setmetatable({},{__mode='k'})
local function groupLines(catalog,group)
 local groups=catalogs[catalog]
 if not groups then
  groups={};catalogs[catalog]=groups;M.metrics.indexBuilds=M.metrics.indexBuilds+1
  for _,line in pairs(catalog)do
   if line.group then groups[line.group]=groups[line.group] or {};table.insert(groups[line.group],line)end
   M.metrics.indexed=M.metrics.indexed+1
  end
 end
 return groups[group] or {}
end
local State=require 'CSV/State'
local Extras=require 'CSV/Extras'
local Evidence=require 'CSV/ThreatEvidence'
local Delivery=require 'CSV/Delivery'
local Semantic=require 'CSV/SemanticSpeech'
function M.install(C,V)
C.history=setmetatable({},{__mode='k'})
function C.extraLine(player,voice,group,allowed,rank)
    if not Extras.approved or not V.bank(voice).extras.approved or not V.extended(voice) then return nil end
    local best,stamp;local history=C.history[player] or {}
    for _,original in ipairs(groupLines(V.bank(voice).extras.catalog,group))do
        M.metrics.candidates=M.metrics.candidates+1
        local line=V.localize(voice,original) or original
        if line.group==group and require('CSV/Profanity').allowed(line.id,C.preferences(),voice) and V.clip(voice,line.id) and (not allowed or allowed(line.id)) then
            local used=Semantic.stamp(history,line)
            if not best or used<stamp or (used==stamp and (rank and rank(line.id)<rank(best.id) or not rank and line.id<best.id)) then best=line;stamp=used end
        end
    end
    return best
end
function C.chooseBaseLine(player,voice,group,intensity,maximum,facts)
    local f=facts or State.capture(player)
    if require('CSV/ReloadRules').groups[group] then
        if require('CSV/Reload').valid(f.reload) and require('CSV/ReloadRules').group(f)==group then
            return C.extraLine(player,voice,group,function(id)return require('CSV/ReloadRules').allowed(id,f.reload)end)
        end
        return nil
    end
    if group=='Kill' then return require('CSV/KillSpeech').choose(C,V,player,voice,f)end
    if not require('CSV/Traits').phobiaAllowed(group,f) then return nil end
    if group=='Startle' then
        if not f.nativeAlert then return nil end
        return C.extraLine(player,voice,require('CSV/Traits').startle(f),function(id)return require('CSV/Traits').startleAllowed(id,f)end,function(id)local n=tonumber(id:match('_(%d+)$'));return n>=3 and n-3 or n+6 end)
    end
    if group=='Injured' and require('CSV/CriticalHealth').stage(f.health)>0 then
        local wound=(f.bleeding or 0)>0 or f.acute==true
        local group=(f.health<=10 or not wound) and 'CriticalFading' or 'CriticalWound'
        local dedicated=C.extraLine(player,voice,group)
        if dedicated then dedicated.critical=true;dedicated.dedicatedCritical=true;return dedicated end
        local line=(V.bank(voice).data.groups.Injured or {})[3]
        if line then return {id=line.id,text=line.text,group='Injured',critical=true} end
    end
    local traitGroup=require('CSV/Traits').context(group,f)
    if traitGroup then
        local line=C.extraLine(player,voice,traitGroup)
        if line then return line end
    end
    if group=='Psychology' then
        local pool=require('CSV/PsychologyRules').pool(f.psychology,f)
        if pool=='Kill' then return require('CSV/KillSpeech').choose(C,V,player,voice,f,f.psychology.experience)end
        return pool and C.extraLine(player,voice,pool,function(id)return require('CSV/PsychologyRules').allowed(id,f)end) or nil
    end
    if require('CSV/OutcomeRules').groups[group] then
        if V.extended(voice) and require('CSV/OutcomeRules').classify(f.outcome)==group then return C.extraLine(player,voice,group,function(id)return require('CSV/OutcomeRules').allowedLine(id,f.outcome)end) end
        return nil
    end
    if require('CSV/LootRules').groups[group] then
        if V.extended(voice) and require('CSV/LootRules').classify(f.loot)==group then return C.extraLine(player,voice,group) end
        return nil
    end
    local tier=require('CSV/NeedTiers').choose(V,voice,group,intensity,maximum,f)
    if tier then return tier end
    local replacement,handled=require('CSV/Conditions').choose(V,C,player,voice,group,f)
    if handled then return replacement end
    local extraGroup
    if group=='Threat' then
        if type(f.panic)=='number' and f.panic<3 and ((f.accessibleNear or f.near or 0)>0 or require('CSV/Concealment').active(f)) then
            extraGroup=f.panic==0 and not require('CSV/Concealment').active(f) and 'ThreatCalm' or 'ThreatTense'
            return C.extraLine(player,voice,extraGroup) or (V.bank(voice).data.groups.Panic or {})[2]
        end
        return nil
    elseif group=='AcutePain' then
        if f.acute then return C.extraLine(player,voice,'InjuryAcute') or (V.bank(voice).data.groups.Pain or {})[3] end
        return nil
    elseif group:match('^Relief') then
        return C.extraLine(player,voice,group)
    elseif group=='Panic' and f.fire then extraGroup='Fire'
    elseif group=='Panic' and (f.near or 0)>0 and (f.panic or 0)>0 and f.panic<3 then extraGroup='ThreatTense'
    elseif group=='MultiHit' and (f.reactiveCrowd or 0)<3 then extraGroup='RepeatedHit'
    elseif group=='Uncomfortable' then extraGroup='Discomfort'
    elseif group=='FoodEaten' then extraGroup='Full'
    elseif group=='Hypothermia' and intensity==1 then extraGroup='ColdMild'
    elseif group=='Hyperthermia' and intensity==1 then extraGroup='HeatMild'
    elseif group=='Hungry' and (intensity or 0)>=3 then extraGroup='HungerSevere'
    elseif group=='Pain' and intensity==2 then extraGroup='PainGeneric' end
    if extraGroup then local line=C.extraLine(player,voice,extraGroup);if line then return line end end
    if group=='PanicCallback' and facts and (facts.near or 0)>0 and (facts.panic or 0)>=3 then
        return C.chooseLine(player,voice,'Panic',facts.panic,4,facts)
    end
    local audited=require('CSV/Rules').pool(V,player,group,intensity,maximum,facts,voice)
    local contextual=V.contextLine(player,voice,group,intensity,facts)
    if contextual then
        local contextGroup=({ThirstCritical_1='ContextThirstCritical',PanicGrounding_1='ContextPanicGrounding',PanicEscape_1='ContextPanicEscape'})[contextual.id]
        return contextGroup and C.extraLine(player,voice,contextGroup) or contextual
    end
    local preferred=V.choose(group,intensity,maximum,voice)
    if not preferred then return nil end
    local list=audited or V.bank(voice).data.groups[group]
    local recent=C.history[player] or {}
    local now=V.now()
    local preferredIndex=1
    for i,line in ipairs(list) do if line.id==preferred.id then preferredIndex=i end end
    local best,score
    for i,line in ipairs(list) do
        if require('CSV/Profanity').allowed(line.id,C.preferences(),voice) and V.clip(voice,line.id) then
            local stamp=recent[line.id]
            local used=stamp and now-stamp<120000
            local rank=used and (1000000+stamp) or math.abs(i-preferredIndex)
            if not score or rank<score then best=line;score=rank end
        end
    end
    return best
end
function C.chooseLine(player,voice,group,intensity,maximum,facts)
    local f=facts or State.capture(player)
    local line=C.chooseBaseLine(player,voice,group,intensity,maximum,facts)
    if line and line.needTier then return line end
    if line and line.dedicatedCritical then return V.localize(voice,line) end
    if line and line.critical then return V.localize(voice,require('CSV/Expressions').pick(V,voice,line,f,'frightened',player)) end
    line=Semantic.shared(C,V,player,voice,line,group,f)
    -- Base bank group entries do not carry a group field.
    if line and not line.group then line={id=line.id,text=line.text,group=group}end
    return V.localize(voice,require('CSV/Expressions').pick(V,voice,line,f,nil,player))
end
local function plan(player,voice,group,intensity,maximum,facts,prefs)
    local s={};for key,value in pairs(facts or State.capture(player))do s[key]=value end
    s.threatKind=Evidence.kind(s)
    local line=C.chooseLine(player,voice,group,intensity,maximum,s)
    local contextualWhisper,whisper
    if s.sneaking==true and prefs and prefs.whisper then
        contextualWhisper=require('CSV/Whispers').pick(V,voice,line)
        if (group=='Threat' or group=='Panic' or group=='PanicCallback') and not (line and line.group and line.group:match('^Trait')) then whisper=C.extraLine(player,voice,'ThreatWhisper')end
    end
    s.whisperAvailable=whisper~=nil;s.contextWhisperAvailable=contextualWhisper~=nil
    local decision=Delivery.decide(group,intensity,s,prefs)
    if decision.reason=='observed_calm_warning' and not require('CSV/Traits').context(group,s) then line=C.extraLine(player,voice,'ThreatCalm') or (V.bank(voice).data.groups.Panic or {})[2] end
    if decision.reason=='recorded_whisper' then line=whisper
    elseif decision.reason=='recorded_context_whisper' then line=contextualWhisper end
    line=V.localize(voice,line)
    if line and not require('CSV/Profanity').allowed(line.id,C.preferences(),voice) then return nil,{mode='silent',reason='profanity_disabled'}end
    if line and not Semantic.allowed(line,s) then return nil,{mode='silent',reason='unproven_final_content'}end
    if line and not (group=='Injured' and require('CSV/CriticalHealth').pending(player)) and not (group=='AcutePain' and s.acute==true and type(s.injuryEvent)=='number') and Semantic.recent(C.history[player] or {},line,V.now()) then return line,{mode='silent',reason='semantic_repeat'}end
    return line,decision
end
function C.plan(player,voice,group,intensity,maximum,facts,prefs)
    if not C.debugEnabled or not C.debugEnabled() then return plan(player,voice,group,intensity,maximum,facts,prefs) end
    return require('CSV/Replay').capture(V,C,plan,player,voice,group,intensity,maximum,facts or State.capture(player),prefs)
end
function C.remember(player,id,line)
    local h=C.history[player] or {};C.history[player]=h
    local now=V.now()
    for key,stamp in pairs(h) do if now-stamp>=1800000 then h[key]=nil end end
    h[id]=now
    if line then Semantic.remember(h,line,now)end
    local source=id:match('^Whisper_(.+)$') or require('CSV/Expressions').source(id);if source then h[source]=now end
end
end
return M

