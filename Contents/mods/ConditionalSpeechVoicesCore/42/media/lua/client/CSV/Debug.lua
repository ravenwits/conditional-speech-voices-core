local D={groups={},outcomes={},recent={},total=0,previews=0,remote=0}
function D.record(kind,group,outcome,info)
    info=info or {}
    local e={kind=kind,group=tostring(group or '-'),outcome=tostring(outcome),line=info.line or '-',
        whisperRisk=info.whisperRisk,directAttack=info.directAttack,activePursuit=info.activePursuit,noiseRadius=info.noiseRadius,hearingRiskRadius=info.hearingRiskRadius,exposed=info.exposed,concealmentRisk=info.concealmentRisk,upstreamVolume=info.upstreamVolume,policy=info.policy,targeted=info.targeted,approaching=info.approaching,blockedNear=info.blockedNear,panic=info.panic,near=info.near,sneaking=info.sneaking,delivery=info.delivery or '-',gain=info.gain,pitch=info.pitch,sourceVolume=info.sourceVolume,volumeBlock=info.volumeBlock,intensity=info.intensity,at=getTimestampMs()}
    D.last=e
    if kind=='gameplay' then
        require('CSV/ProductionReport').record(group,outcome,info)
        D.total=D.total+1
        if not D.groups[e.group] then
            local count=0;for _ in pairs(D.groups)do count=count+1 end
            if count>=128 then e.group='other' end
        end
        local g=D.groups[e.group] or {attempts=0,played=0};D.groups[e.group]=g
        g.attempts=g.attempts+1;if outcome=='played' then g.played=g.played+1 end
        D.outcomes[e.outcome]=(D.outcomes[e.outcome] or 0)+1
    elseif kind=='preview' then D.previews=D.previews+1
    else D.remote=D.remote+1 end
    if outcome=='played' then D.lastPlayed=e end
    D.recent[#D.recent+1]=e;if #D.recent>40 then table.remove(D.recent,1) end
end
function D.top()
    local list={};for name,g in pairs(D.groups)do list[#list+1]={name=name,attempts=g.attempts,played=g.played} end
    require('CSV/Sort').sort(list,function(a,b)if a.attempts==b.attempts then return a.name<b.name end;return a.attempts>b.attempts end)
    return list
end
local function writeReport(f)
    f:write('Session only; attempts are calls reaching the voice addon, not all game events. Preview/remote excluded from group totals.\n')
    local C=require('CSV/Core').client
    f:write('addon='..require('CSV/Core').version..'; played counts accepted requests, not confirmed audible sound.\n')
    if C and C.lastPlayback then local e=C.lastPlayback;f:write('lastPlayback='..e.line..' '..e.outcome..' elapsedMs='..e.elapsed..' started='..tostring(e.started)..'\n') end
    if C then
        local R=require 'CSV/Recovery'
        f:write('damageCallbackErrors='..(R.damageErrors or 0)..' ignoredNonPlayerDamage='..(R.ignoredNonPlayers or 0)..' lastDamageError='..tostring(R.lastDamageError)..'\n')
        if C.lastMix then local m=C.lastMix;f:write('lastMix='..m.line..' gain='..m.gain..' requested='..m.requested..' nearbyBoost='..m.presence..' peakLimited='..tostring(m.limited)..'\n') end
        local ok,active=pcall(function()return getActivatedMods():contains('errorMagnifier')end)
        f:write('errorMagnifierActive='..(ok and tostring(active) or 'unknown')..'\n')
        f:write('caughtErrorsScope=addon protected callbacks only; consult console for other errors\n')
        f:write('caughtErrors='..tostring(C.errors)..'\n')
        f:write('currentSettings='..C.settingsSnapshot()..'\n')
        for _,entry in ipairs(C.settingChanges or {})do f:write('settingsChange='..entry..'\n')end
    end
    if C then f:write('lastPreviewReason='..tostring(C.lastPreviewReason)..'\n') end
    f:write('gameplay='..D.total..' previews='..D.previews..' remote='..D.remote..'\n')
    for _,g in ipairs(D.top())do f:write(g.name..' attempts='..g.attempts..' played='..g.played..'\n') end
    for name,count in pairs(D.outcomes)do f:write('outcome '..name..'='..count..'\n') end
    for _,e in ipairs(D.recent)do f:write(e.kind..' '..e.group..' '..e.line..' '..e.delivery..' '..e.outcome..' gain='..tostring(e.gain)..' sourceVolume='..tostring(e.sourceVolume)..' volumeBlock='..tostring(e.volumeBlock)..' intensity='..tostring(e.intensity)..' upstreamVolume='..tostring(e.upstreamVolume)..' policy='..tostring(e.policy)..' panic='..tostring(e.panic)..' near='..tostring(e.near)..' sneaking='..tostring(e.sneaking)..' whisperRisk='..tostring(e.whisperRisk)..' directAttack='..tostring(e.directAttack)..' activePursuit='..tostring(e.activePursuit)..' noiseRadius='..tostring(e.noiseRadius)..' hearingRiskRadius='..tostring(e.hearingRiskRadius)..' exposed='..tostring(e.exposed)..' concealmentRisk='..tostring(e.concealmentRisk)..' targeted='..tostring(e.targeted)..' approaching='..tostring(e.approaching)..' blockedNear='..tostring(e.blockedNear)..'\n') end
    -- Session diagnostics need observed clips; the complete inventory belongs to
    -- the package audit, not a repeated scan of thousands of untouched assets.
    require('CSV/ProductionReport').export(f,true)
    local player=getSpecificPlayer(0);if player then require('CSV/Scenarios').export(f,player)end
end
function D.export()
    local started=getTimestampMs()
    local f=require('CSV/ReportWriter').open('CSV-report.txt')
    if not f then print('[CSV] stats export failed');return false end
    local ok,err=pcall(writeReport,f)
    D.maxPrepareMs=math.max(D.maxPrepareMs or 0,getTimestampMs()-started)
    if not ok then
        f:abort()
        print('[CSV] report preparation failed; previous report kept: '..tostring(err))
        return false
    end
    f:close()
    print('[CSV] queued combined CSV-report.txt')
    return true
end
return D
