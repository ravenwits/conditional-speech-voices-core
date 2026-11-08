local pack=require 'CSV/Pack'
local V = {data=require 'CSV/Data',version=require('CSV/Release').version}
V.pack=pack
function V.bank(voice)return pack.voiceBanks[voice] or pack end
function V.localize(voice,line)
 if not line then return nil end
 local b=pack.voiceBanks[voice];if not b or not b.lines then return line end
 local text=b.lines[line.id];if not text then return nil end
 local out={};for key,value in pairs(line)do out[key]=value end;out.text=text;return out
end
function V.available()return pack.id~=false end
-- Voice selection chooses the audio language; the UI language never filters playback.
function V.languageSupported()return V.available() end
V.config={selfPlayback="character",enabled=true,maxDistance=25,maxConcurrent=2,followPitch=true}
function V.extended(voice)return V.available() and pack.voiceBanks[voice]~=nil and pack.voices[voice].extended~=false end
function V.finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function V.now() return getTimestampMs() end
function V.voice(player)
    if not V.available() or not player or not player.getDescriptor then return nil end
    local md=player.getModData and player:getModData()
    if md and md.csvVoice then return pack.voiceBanks[md.csvVoice] and md.csvVoice or nil end
    local d=player:getDescriptor()
    if not d or not d.getVoiceType or not d.getVoicePrefix then return nil end
    if d:getVoiceType()~=0 then return nil end
    local prefix=d:getVoicePrefix()
    for _,id in ipairs(pack.voiceOrder)do
        if pack.voices[id].builtinPrefix==prefix then return id end
    end
    -- Character descriptors can arrive before player modData on remote clients.
    for id,v in pairs(pack.voices)do
        if v.prefix and type(prefix)=='string' and prefix:sub(1,#v.prefix)==v.prefix then
            local pitch=prefix:sub(#v.prefix+1)
            if pitch:match('^%d+$') and tonumber(pitch)<=200 then return id end
        end
    end
end
function V.pitch(player)
    local d=player and player:getDescriptor()
    local p=d and d.getVoicePitch and d:getVoicePitch() or 0
    if not V.finite(p) then p=0 end
    return math.max(-100,math.min(100,p))
end
function V.clip(voice,id)
    local bank=voice and pack.voiceBanks[voice]
    if not bank then return nil end
    if type(id)~='string' or #id>60 then return nil end
    local data=bank.data
    return data.clips[voice..'_'..id]
end
function V.choose(group,intensity,maximum,voice)
    local list=V.bank(voice).data.groups[group]
    if not list or #list==0 then return nil end
    if not V.finite(maximum) or maximum<=1 then return list[(V.selectionRandom or ZombRand)(#list)+1] end
    local level=V.finite(intensity) and intensity or 1
    local index=1+math.floor(math.max(0,level-1)/math.max(1,maximum-1)*(#list-1)+0.5)
    return list[math.max(1,math.min(#list,index))]
end
function V.near(a,b,radius)
    if not a or not b then return false end
    if math.abs(a:getZ()-b:getZ())>1 then return false end
    local x,y=a:getX()-b:getX(),a:getY()-b:getY()
    return x*x+y*y<=radius*radius
end
-- A small recording-specific lift, independent of mood or incoming packet fields.
function V.recordedLevel(voice,id)
    if id=='ThirstCritical_1' or id=='PanicGrounding_1' or id=='PanicEscape_1' then return false end
    return V.extended(voice) and ((require('CSV/Extras').approved and require('CSV/Extras').catalog[id]~=nil) or require('CSV/Whispers').contains(id) or require('CSV/Expressions').source(id)~=nil)
end
function V.deliveryGain(voice,id)
    id=require('CSV/Expressions').source(id) or id
    local levels=(pack.voices[voice] or {}).deliveryGains or {}
    return levels[id:match('^(.-)_%d+$') or id] or 1
end
function V.delivery(voice,id)
    if id:match('^KillControlled_') then return 'controlled' end
    if id:match('^KillUneasy_') then return 'shaken' end
    if id:match('^KillDesperate_') then return 'frightened' end
    local reload=id:match('^(Reload%a+)_')
    if reload then return ({ReloadPanic='frightened',ReloadBreathless='breathless',ReloadSteady='controlled',ReloadShaken='sad'})[reload] or 'original' end
    local expression=require('CSV/Expressions').catalog[id];if expression then return expression.profile end
    if require('CSV/Whispers').contains(id) then return 'whisper' end
    for _,line in ipairs(V.bank(voice).data.contextLines or {})do
        if (line.voice==nil or line.voice==voice) and line.id==id then return line.delivery end
    end
    return 'original'
end
function V.closeThreat(player)
 return (require('CSV/State').capture(player).near or 0)>0
end
function V.pitchMultiplier(pitch,voice)
    -- MP3 approximation. The vanilla FMOD event's automation curve is not exposed here.
    return 2^((math.max(-100,math.min(100,pitch or 0))/50+((pack.voices[voice] or {}).pitchOffset or 0))/12)
end
-- Per-file measured peak headroom; this does not limit the final mixed game bus.
local peakLimits=require 'CSV/PeakLimits'
function V.outputGain(voice,id,requested)
    if not V.finite(requested) then return 0 end
    return math.max(0,math.min(peakLimits[voice..'_'..id] or 1,requested))
end
function V.maxPriority(id)
    if id:match('^KillControlled_') or id:match('^KillUneasy_') or id:match('^KillDesperate_') then return 2 end
    if id:match('^Reload') then return 3 end
    local canonical=pack.semanticAliases[id]
    if canonical and canonical~=id then return V.maxPriority(canonical) end
    local source=require('CSV/Expressions').source(id);if source then return V.maxPriority(source) end
    if require('CSV/Whispers').contains(id) then return math.min(2,V.maxPriority(id:sub(9))) end
    if id:match('^Startle') then return 3 end
    if id:match('^MortalFear_') or id:match('^HumanDanger_') or id:match('^ShelterThreat_') then return 3 end
    if id:match('^Fire_%d+$') or id:match('^InjuryAcute_%d+$') or id=='Pain_3' or id=='Panic_3' then return 4 end
    if id:match('^AmmoCount_') or id:match('^AmmoReserve_') or id:match('^ChamberEmpty_') or id:match('^RepeatedHit_') or id:match('^PanicEscape_%d+$')~=nil or id:match('^GunJammed_') or id:match('^OutOfAmmo_') or id:match('^MultiHit_') or id:match('^LowAmmo_') or id:match('^VehicleDamage_') or id:match('^Bleeding_') or id:match('^Injured_') or id:match('^Endurance_') or id:match('^CantSprint_') then return 3 end
    if id:match('^Panic') or id:match('^Threat') or id:match('^Kill_') then return 2 end
    return 1
end
function V.packetPriority(p)
 local ceiling=V.maxPriority(p.line)
 if p.engaged==true and p.radius<=12 and ceiling>=2 then ceiling=math.max(3,ceiling)end
 return math.min(ceiling,V.finite(p.priority) and math.max(1,math.floor(p.priority)) or 1)
end
function V.allowStealth(id)
    return require('CSV/Whispers').contains(id) or id:match('^Fire_%d+$')~=nil or id:match('^InjuryAcute_%d+$')~=nil or id=='Pain_3' or id=='Panic_3' or id:match('^ThreatWhisper_')~=nil
end
function V.contextLine(player,voice,group,intensity,facts)
    if not V.finite(intensity) then return nil end
    local s=facts or require('CSV/State').capture(player)
    if group=='Panic' and s.fire==true then return nil end
    local threat=(s.visible or 0)>0 or s.recentThreat==true or require('CSV/Concealment').active(s)
    for _,line in ipairs(V.bank(voice).data.contextLines or {})do
        if (line.voice==nil or line.voice==voice) and line.group==group and intensity>=line.min and intensity<=line.max
            and (line.threat==nil or (line.threat==threat and (line.threat or s.visible~=nil and s.recentThreat~=nil))) and (line.id~='PanicEscape_1' or require('CSV/Concealment').active(s) or (facts and (s.accessibleNear or s.near or 0)>0) or (not facts and V.closeThreat(player))) and V.clip(voice,line.id) then return line end
    end
end
function V.validPacket(p)
    if type(p)~='table' or type(p.voice)~='string' then return false end
    local bank=pack.voiceBanks[p.voice]
    return bank~=nil and p.version==1 and (p.pack==nil and p.packRevision==nil or p.pack==bank.id and p.packRevision==bank.revision) and V.clip(p.voice,p.line)~=nil
        and V.finite(p.actor) and p.actor>=0 and p.actor%1==0
        and V.finite(p.seq) and p.seq>=1 and p.seq<2147483647 and p.seq%1==0
        and V.finite(p.radius) and p.radius>0 and p.radius<=V.config.maxDistance
        and V.finite(p.pitch) and p.pitch>=-100 and p.pitch<=100
end
return V
