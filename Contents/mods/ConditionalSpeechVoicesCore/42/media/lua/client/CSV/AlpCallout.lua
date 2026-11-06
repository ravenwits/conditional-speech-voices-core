local V = require 'CSV/Core'
local M = {}
M.metrics={requested=0,queued=0,active=0,blocked=0,failed=0}
M.history={}
local playing=setmetatable({}, {__mode='k'})
local recent = setmetatable({}, {__mode='k'})

local function hasShoutItem(player)
    local function special(item) return item and item:getShoutType() ~= nil end
    if special(player:getPrimaryHandItem()) or special(player:getSecondaryHandItem()) then return true end
    local worn = player:getWornItems()
    if worn then
        for i=0,worn:size()-1 do if special(worn:get(i):getItem()) then return true end end
    end
    return false
end

function M.call(player)
    M.metrics.requested=M.metrics.requested+1
    local sneaking = player:isSneaking()
    if not sneaking and hasShoutItem(player) then return false end
    if not player:isCanShout() then return true end
    local bank = V.bank(V.voice(player))
    local pool = bank.native.replacements[sneaking and 'WhisperHey' or 'ShoutHey']
    local previous = recent[player]
    if previous and player:getEmitter():isPlaying(player:getDescriptor():getVoicePrefix()..'CSV'..previous) then M.metrics.blocked=M.metrics.blocked+1;return true end
    local candidates = {}
    for _,id in ipairs(pool) do if id ~= previous then candidates[#candidates+1]=id end end
    local id = candidates[ZombRand(#candidates)+1]
    local item = player:getPrimaryHandItem()
    local mega = item and item:hasTag(ItemTag.MEGAPHONE)
    local radius = sneaking and (mega and 18 or 6) or (mega and 90 or 30)
    local handle=player:transmitPlayerVoiceSound('CSV'..id)
    if not handle or handle==0 then M.metrics.failed=M.metrics.failed+1;return true end
    recent[player] = id
    local entry={id=id,text=bank.lines[id],radius=radius,sneaking=sneaking,megaphone=mega==true,at=getTimestampMs(),handle=handle,state='queued'}
    M.history[#M.history+1]=entry
    if #M.history>32 then table.remove(M.history,1)end
    playing[player]=entry;M.metrics.queued=M.metrics.queued+1
    player:SayShout(bank.lines[id])
    addSound(player,player:getX(),player:getY(),player:getZ(),radius,radius)
    player:playEmote('shout')
    return true
end

function M.observe(player)
    local entry=playing[player]
    if not entry then return end
    local emitter=player:getEmitter()
    if not emitter then entry.state='emitter_unavailable';playing[player]=nil;return end
    local active=emitter:isPlaying(entry.handle)
    local pending=emitter.hasSoundsToStart and emitter:hasSoundsToStart()
    if active and not pending and not entry.started then
        entry.started=getTimestampMs();entry.state='engine_active';M.metrics.active=M.metrics.active+1
    elseif not active and getTimestampMs()-entry.at>=250 then
        entry.state=entry.started and 'engine_finished' or 'ended_before_start';playing[player]=nil
    end
end

function M.export(writer)
    local m=M.metrics
    writer:write('ALP_CALLOUT requested='..m.requested..' queued='..m.queued..' engineActive='..m.active..' blocked='..m.blocked..' failed='..m.failed..'\n')
    for _,entry in ipairs(M.history)do
        -- Kahlua's %q truncates non-ASCII characters, e.g. Turkish dotless i.
        local caption='"'..entry.text:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\r','\\r'):gsub('\n','\\n')..'"'
        writer:write('ALP_CALL line='..entry.id..' caption='..caption..' sneaking='..tostring(entry.sneaking)..' megaphone='..tostring(entry.megaphone)..' radius='..entry.radius..' at='..entry.at..' state='..entry.state..'\n')
    end
end

function M.install(menu)
    if menu.csvAlpKeyInstalled then return end
    menu.csvAlpKeyInstalled = true
    local pressed, released = menu.onKeyPressed, menu.onKeyReleased
    local pending
    menu.onKeyPressed = function(key)
        if getCore():isKey(KeybindId.SHOUT,key) then
            pending=nil
            if menu.checkKey(key) and getCore():getGameMode()~='Tutorial' then
                local p=getSpecificPlayer(0)
                if require('CSV/NativeVoice').supported(V.voice(p)) and not p:getVehicle() then
                    pending={player=p,at=getTimestampMs(),closedRadial=getCore():getOptionRadialMenuKeyToggle() and getPlayerRadialMenu(0):isReallyVisible()}
                end
            end
        end
        return pressed(key)
    end
    menu.onKeyReleased = function(key)
        if not getCore():isKey(KeybindId.SHOUT,key) then return released(key) end
        local press=pending
        pending=nil
        local p=getSpecificPlayer(0)
        if press and p==press.player and require('CSV/NativeVoice').supported(V.voice(p)) and not p:getVehicle() then
            if menu.checkKey(key) and not press.closedRadial and not getPlayerRadialMenu(0):isReallyVisible() and getTimestampMs()-press.at<450 then
                if M.call(p) then return end
            end
        elseif not press and p and require('CSV/NativeVoice').supported(V.voice(p)) and not p:getVehicle() and getCore():getGameMode()~='Tutorial' and not getPlayerRadialMenu(0):isReallyVisible() then
            return
        end
        return released(key)
    end
end
return M
