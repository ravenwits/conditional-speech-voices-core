-- Versioned semantic coverage. Physical filenames may differ between languages.
local requirements = require 'CSV/VoiceRequirements'
local Contract = {version = requirements.version}

function Contract.check(definition)
    local errors = {}
    if definition.contract ~= Contract.version then
        return {'Unsupported voice contract'}
    end
    local bank = definition.bank
    local aliases = bank.aliases or {}
    local suffixes = {}
    for _, suffix in ipairs(bank.native and bank.native.suffixes or {}) do
        if suffixes[suffix] then errors[#errors + 1] = 'Duplicate native suffix ' .. suffix end
        suffixes[suffix] = true
    end
    if not suffixes[''] then errors[#errors + 1] = 'Missing ambient voice controller' end
    for _, event in ipairs(requirements.nativeEvents) do
        if not suffixes[event] then errors[#errors + 1] = 'Missing native registration ' .. event end
    end
    for _, voice in ipairs(definition.voices) do
        if bank.needTiers~=nil then
            if bank.needTiers~=1 then errors[#errors + 1]='Unsupported need tier extension' end
            for _, pool in pairs(require('CSV/NeedTiers').slots)do
                for _, id in ipairs(pool)do
                    if not bank.data.clips[voice.id .. '_' .. id] or type((bank.lines or {})[id])~='string' then
                        errors[#errors + 1]=voice.id .. ': missing need tier ' .. id
                    end
                end
            end
        end
        if bank.criticalHealth~=nil then
            if bank.criticalHealth~=1 then errors[#errors+1]='Unsupported critical health extension' end
            for _,id in ipairs({'CriticalWound_1','CriticalWound_2','CriticalFading_1','CriticalFading_2','Whisper_CriticalWound_1','Whisper_CriticalWound_2','Whisper_CriticalFading_1','Whisper_CriticalFading_2'})do
                local clip=bank.data.clips[voice.id..'_'..id]
                if not clip or type(clip.duration)~='number' or clip.duration<=0 or type((bank.lines or {})[id])~='string' then errors[#errors+1]=voice.id..': missing critical health slot '..id end
            end
        end
        for _, slot in ipairs(requirements.slots) do
            local id = aliases[slot] or slot
            local clip = bank.data.clips[voice.id .. '_' .. id]
            if not clip then
                errors[#errors + 1] = voice.id .. ': missing slot ' .. slot
            elseif type(clip.sound) ~= 'string' or type(clip.duration) ~= 'number'
                or clip.duration ~= clip.duration or clip.duration <= 0 or clip.duration == math.huge then
                errors[#errors + 1] = voice.id .. ': invalid clip ' .. id
            end
        end
        local native = bank.native or {}
        for _, event in ipairs(requirements.nativeEvents) do
            local pool = (native.replacements or {})[event]
            if type(pool) ~= 'table' or #pool == 0 then
                errors[#errors + 1] = voice.id .. ': missing native event ' .. event
            else
                for _, id in ipairs(pool) do
                    if not bank.data.clips[voice.id .. '_' .. id] then
                        errors[#errors + 1] = voice.id .. ': missing native recording ' .. tostring(id)
                    end
                    if event:find('Shout') or event:find('Whisper') then
                        if type((bank.lines or {})[id]) ~= 'string' or bank.lines[id] == '' then
                            errors[#errors + 1] = voice.id .. ': missing callout caption ' .. tostring(id)
                        end
                    end
                end
            end
        end
    end
    return errors
end

return Contract
