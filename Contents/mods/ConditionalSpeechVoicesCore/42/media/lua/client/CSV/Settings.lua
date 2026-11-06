local Settings={}
function Settings.install(C,V)
local State=require 'CSV/State'
local lootModeOption,lootFrequencyOption,profanityOption
local volumeOption,otherVolumeOption,debugOption,frequencyOption,whisperOption,thoughtOption,safeOption
function C.preferences()
    return {profanity=not profanityOption or profanityOption:getValue(),lootMode=lootModeOption and lootModeOption:getValue()-1 or 2,lootFrequency=lootFrequencyOption and lootFrequencyOption:getValue()-1 or 1,frequency=frequencyOption and require('CSV/FrequencyOptions').normalize(frequencyOption) or 1,whisper=whisperOption and whisperOption:getValue() or false,thoughts=thoughtOption and thoughtOption:getValue() or false,safeSpeech=safeOption and safeOption:getValue() or false}
end
function C.volumeGain(ownVoice)
    local option=ownVoice==false and otherVolumeOption or volumeOption
    local value=option and option:getValue() or 100
    if not V.finite(value) then value=100 end
    return math.max(0,math.min(200,value))/100
end
function C.presenceGain()
    return 1.4 -- Fixed nearby-zombie lift; independent of saved Mod Options.
end
C.presenceCache=setmetatable({},{__mode='k'})
function C.entryGain(e)
    local factor=1
    if e.ownVoice and not e.private and (not e.preview or e.contextFacts) and V.delivery(e.packet.voice,e.line)~='whisper' then
        local facts=e.contextFacts
        if not facts then
            local cache=C.presenceCache[e.player];local now=V.now()
            if not cache or now-cache.at>=1000 then cache={at=now,facts=State.capture(e.player)};C.presenceCache[e.player]=cache end
            facts=cache.facts
        end
        if facts.sneaking==false and (facts.near or 0)>0 or require('CSV/Concealment').active(facts) then factor=C.presenceGain() end
    end
    local requested=e.baseVolume*C.volumeGain(e.ownVoice)*(e.balance or 1)*factor
    return V.outputGain(e.packet.voice,e.line,requested),factor,requested
end
local function createOptions()
    local options=PZAPI.ModOptions:getOptions('ConditionalSpeechVoices')
        or PZAPI.ModOptions:create('ConditionalSpeechVoices',getText('UI_CSV_Option_1'))
    volumeOption=options:getOption('volume') or options:addSlider('volume',
        getText('UI_CSV_Option_2'),0,200,5,100,
        getText('UI_CSV_Option_3'))
    otherVolumeOption=options:getOption('volumeOthers') or options:addSlider('volumeOthers',
        getText('UI_CSV_Option_4'),0,200,5,100,
        getText('UI_CSV_Option_5'))
    require('CSV/CharacterPitch').install(options)
    lootModeOption=options:getOption('lootMode')
    if not lootModeOption then
        lootModeOption=options:addComboBox('lootMode',getText('UI_CSV_Option_6'),getText('UI_CSV_Option_7'))
        lootModeOption:addItem(getText('UI_CSV_Option_8'));lootModeOption:addItem(getText('UI_CSV_Option_9'));lootModeOption:addItem(getText('UI_CSV_Option_10'),true)
    end
    lootFrequencyOption=options:getOption('lootFrequency')
    if not lootFrequencyOption then
        lootFrequencyOption=options:addComboBox('lootFrequency',getText('UI_CSV_Option_11'),getText('UI_CSV_Option_12'))
        lootFrequencyOption:addItem(getText('UI_CSV_Option_13'));lootFrequencyOption:addItem(getText('UI_CSV_Option_14'),true);lootFrequencyOption:addItem(getText('UI_CSV_Option_15'))
    end
    frequencyOption=require('CSV/FrequencyOptions').create(options)
    whisperOption=options:getOption('stealthWhisper') or options:addTickBox('stealthWhisper',getText('UI_CSV_Option_20'),false,getText('UI_CSV_Option_21'))
    thoughtOption=options:getOption('hearThoughts') or options:addTickBox('hearThoughts',getText('UI_CSV_Option_22'),false,getText('UI_CSV_Option_23'))
    safeOption=options:getOption('safeSpeech') or options:addTickBox('safeSpeech',getText('UI_CSV_Option_24'),true,getText('UI_CSV_Option_25'))
    profanityOption=options:getOption('profanity') or options:addTickBox('profanity',getText('UI_CSV_Profanity'),true,getText('UI_CSV_ProfanityHelp'))
    debugOption=options:getOption('speechDebug') or options:addTickBox('speechDebug',
        getText('UI_CSV_Option_16'),true,getText('UI_CSV_Option_17'))
    require('CSV/OptionHelp').apply(options)
    PZAPI.ModOptions:load()
    require('CSV/FrequencyOptions').normalize(frequencyOption)
end
function C.debugEnabled()return not debugOption or debugOption:getValue()end
Events.OnGameBoot.Add(createOptions)
end
return Settings
