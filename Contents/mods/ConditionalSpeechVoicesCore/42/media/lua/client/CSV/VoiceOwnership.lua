-- One actor, one voice. Observe native handles; never stop environmental sounds.
local M = {}
local V = require 'CSV/Core'
local Priority = require 'CSV/Priority'

function M.stopSpeech(player, reason, includePreview)
    local client = V.client
    if not client or not client.active or not client.cancel then return end
    for i = #client.active, 1, -1 do
        local entry = client.active[i]
        if entry.player == player and (includePreview or not entry.preview) then
            client.cancel(entry, reason, true)
        end
    end
end

function M.calloutAllowed(player)
    return not require('CSV/NativeVoice').painActive(player)
end

function M.claimCallout(player)
    M.stopSpeech(player, 'manual_callout', true)
end

function M.injury(player)
    require('CSV/Callout').interrupt(player)
end

function M.nativeUpdate(player, pain)
    if pain == nil then pain = require('CSV/NativeVoice').painActive(player) end
    if pain then
        M.injury(player)
        M.stopSpeech(player, 'native_' .. tostring(V.voice(player)) .. '_pain', true)
    elseif require('CSV/Callout').busy(player) then
        M.claimCallout(player)
    end
end

local function canInterrupt(request, active)
    return not request.preview and not active.preview and
        (Priority.interrupt(request.priority or 1, active.priority or 1) or
         Priority.startle(request.group, request.nativeAlert, active.priority or 1, active.preview, active.group))
end

-- Pure with respect to speech entries. Check every owner before cancelling any.
function M.check(player, request)
    if require('CSV/NativeVoice').painActive(player) then
        return false, 'native_' .. tostring(V.voice(player)) .. '_pain'
    end
    if require('CSV/Callout').busy(player) then return false, 'native_callout' end
    local client = V.client
    for _, active in ipairs(client and client.active or {}) do
        if active.player == player and not canInterrupt(request, active) then
            return false, 'already_speaking'
        end
    end
    return true
end

function M.claimSpeech(player, request)
    local allowed, reason = M.check(player, request)
    if not allowed then return false, reason end
    local client = V.client
    for i = #(client and client.active or {}), 1, -1 do
        local active = client.active[i]
        if active.player == player then
            client.cancel(active, 'urgent_interrupt', player:isLocalPlayer())
        end
    end
    return true
end

return M
