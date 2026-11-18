"""Core performance direction shared by every project and by Eleven v4."""

import studio_schema

# Human direction and one short, audible cue. Context and delivery get combined below.
ACTING = {
    'startled': ('Let a brief startle break the attack of the first word, then settle.', 'briefly startled'),
    'tense': ('Keep the phrasing tight and the voice level.', 'voice tight with tension'),
    'frustrated': ('Let irritation catch on the first stressed word, then move on.', 'clipped with frustration'),
    'disappointed': ('Let your pitch drop slightly as you realize it has failed.', 'quietly disappointed'),
    'calm': ('Speak at an even, natural pace.', 'calm and even'),
    'downcast': ('Speak low and let the end of the line lose energy.', 'low and downcast'),
    'tired': ('Let fatigue slow the words slightly. Keep the ends of words clear.', 'slow and tired'),
    'exhausted': ('Use what little air you have. Break once at a natural place if needed.', 'low and exhausted'),
    'uncomfortable': ('Let the discomfort make you hesitate, then finish the thought.', 'slightly uncomfortable'),
    'dry': ('Underplay the line. Keep the pitch almost level.', 'dry, underplayed'),
    'angry': ('Put the anger into a sharper attack on the words. Keep the line brief.', 'clipped with anger'),
    'controlled': ('Keep your pitch and pacing steady under pressure.', 'steady under pressure'),
    'pain': ('Let the pain hit before the sentence. Recover enough to make the words clear.', 'in sudden pain'),
    'strained': ('Speak through the strain. Let one breath break the phrasing.', 'voice strained'),
    'catchingBreath': ('Begin a little out of breath, then let the words settle.', 'breath settling'),
    'waryRelief': ('Ease the tension a little at the end. Stay alert.', 'quiet, wary relief'),
    'relieved': ('Let the tension release on the last few words.', 'softening with relief'),
    'uneasy': ('Keep a trace of tension in a low, even voice.', 'quietly uneasy'),
    'shaken': ('Let the voice waver. Leave one short break where the thought catches.', 'voice unsteady with shock'),
    'breathless': ('Speak on short breaths. Keep the words clear and leave space between phrases.', 'short of breath'),
    'frightened': ('Let fear tighten the voice. Keep the pitch and volume under control.', 'voice tight with fear'),
    'sad': ('Let the voice soften and the ending fall away. Keep it intimate.', 'subdued with sadness'),
    'congested': ('Use mild nasal congestion and keep the words intelligible.', 'slightly congested'),
    'slurred': ('Soften the articulation a little. Keep each word understandable.', 'slightly slurred'),
    'stammer': ('Let stress catch one word, then get the rest out clearly.', 'voice catching under stress'),
    'fading': ('Speak on very little air. Let the voice fall away before forcing another breath.', 'very weak and fading'),
}

# These situations have a more specific performance than their general acting label.
SITUATIONS = {
    'AfterHumanShaken': ('The shock has just landed. Let the voice shake once and catch on the thought.', 'voice trembling with shock'),
    'AfterHumanSteady': ('Stay composed as the weight of what happened sinks in. Let the last words sit.', 'quiet and troubled'),
    'AfterZombieShaken': ('The immediate danger has passed, but the voice has not settled. Break once, then finish the thought.', 'voice still unsteady'),
    'AfterZombieSteady': ('Keep the words measured, with a trace of strain from the encounter.', 'steady with lingering strain'),
    'ContextPanicEscape': ('Get the thought out on short breaths while looking for space. Keep the words intelligible.', 'urgent and short of breath'),
    'ContextPanicGrounding': ('Speak to yourself in small phrases. Let the pace settle as you regain your breath.', 'slowly regaining composure'),
    'ContextThirstCritical': ('Speak with a dry mouth and very little energy. Keep enough air for the last words.', 'dry and exhausted'),
    'CriticalWound': ('The wound makes speaking difficult. Keep the voice low and let one breath interrupt the thought.', 'low and strained with pain'),
    'InjuryAftermath': ('The first shock has passed. Let the remaining soreness affect the breath without a fresh cry.', 'strained with lingering pain'),
    'MortalFear': ('Let the voice narrow with fear and sound close to breaking. Keep the words intelligible.', 'voice wavering with fear'),
    'ThreatWhisper': ('Keep the voice close and the air low. Let fear tighten the words while trying to stay unheard.', 'tense with fear'),
    'KeepHidden': ('Keep your voice low and your words small. Let the fear show in how carefully you speak.', 'hushed and frightened'),
    'EngineRecovered': ('The engine has finally started after a failed attempt. Let relief ease into the last few words.', 'softening with relief'),
    'Fire': ('The heat hits immediately. Get the words out as a brief, intelligible cry and cut it off quickly.', 'cries out briefly in pain'),
}

# Situation cues for readings that have no specific acting label.
UNSPECIFIED = {
    'AmmoCount': ('Count clearly at a low, even volume, as if checking for yourself.', 'counting quietly'),
    'Angry': ACTING['angry'],
    'Bleeding': ('Notice the bleeding with brief concern. Think ahead to dealing with it.', 'low and concerned'),
    'BloodAversion': ('Let the first thought catch in your throat, then turn away from it.', 'voice catching with unease'),
    'BoredMore': ('Let the thought drift and the pitch stay almost level.', 'low and listless'),
    'Darkness': ('Keep your voice low as you work out what you can see.', 'quietly uneasy'),
    'Discomfort': ('Let a brief note of physical irritation through the words.', 'slightly uncomfortable'),
    'Drunk': ACTING['slurred'],
    'FoodRaw': ('Hesitate briefly as you realize the food is undercooked.', 'hesitant'),
    'FoodRotten': ('Let the realization turn your voice away from the food.', 'with quiet disgust'),
    'FoodSuspect': ('Hold on the uncertain word for a beat while you decide whether to trust the food.', 'with quiet suspicion'),
    'HasACold': ACTING['congested'],
    'HeatMild': ('Let the warmth sap a little energy from the words.', 'slightly drained by heat'),
    'HeavyLoad': ('Get the words out around the effort of carrying the weight.', 'slightly short of breath'),
    'Hyperthermia': ('Speak low and drained, with just enough air to finish the thought.', 'weak and overheated'),
    'Hypothermia': ('Use a little tension in the jaw and voice. Keep the shiver subtle.', 'voice tight with cold'),
    'Kill': ('Acknowledge what just happened on a short, level breath. Let the line end quickly.', 'short and matter-of-fact'),
    'KillCount': ('State the exact count as a quiet observation. Keep the number clear and the delivery dry.', 'dry, underplayed'),
    'NativeCall': ('Aim the voice at someone at a distance. Keep the call brief and clear.', 'calls out clearly'),
    'NativeLureCmon': ('Draw their attention with a small, deliberate call.', 'low, deliberate call'),
    'NativeLureTsk': ('Give one short signal with your mouth, as if trying to draw attention discreetly.', 'quietly'),
    'NicotineNeed': ('Let the restlessness put a slight edge on the words.', 'restless and subdued'),
    'NoxiousSmell': ('Let the smell cut the thought short. Keep any gag out of the spoken line.', 'with quiet disgust'),
    'Pain': ('Let pain briefly interrupt the line. Keep the reaction proportionate and the words clear.', 'restrained pain'),
    'ReliefAnger': ('Start a little tight and let the edge leave the voice.', 'tension easing'),
    'ReliefBoredom': ('Let a little more energy return to your voice.', 'with mild renewed interest'),
    'ReliefColdSymptoms': ('Let your voice come a little easier as the symptoms ease.', 'softening with relief'),
    'ReliefDiscomfort': ('Let the strain lift off the words as you get comfortable.', 'softening with relief'),
    'ReliefLoad': ('Let the words come more easily once the weight is off.', 'breath settling'),
    'ReliefMood': ('Let a touch of warmth back into the voice.', 'with quiet relief'),
    'ReliefSobriety': ('Use clear, steady articulation as your head clears.', 'steady and relieved'),
    'ReliefSickness': ('Allow a little relief to show through the lingering fatigue.', 'quiet, tired relief'),
    'ReliefWet': ('Ease the irritation out of the voice as you dry off.', 'softening with relief'),
    'RottenMore': ('Let the disgust register briefly, then move on.', 'with quiet disgust'),
    'Sick': ('Keep the energy low and let the phrase take a little effort.', 'low and unwell'),
    'SickFromFood': ('Keep the voice low and let the nausea interrupt one thought.', 'low and uneasy'),
    'ThreatCalm': ('You have noticed a threat at a distance. Keep the observation low and measured.', 'calm and watchful'),
    'TraitCold': ACTING['congested'],
    'TraitDriver': ('Stay measured as you talk yourself through the problem.', 'steady under pressure'),
    'TraitFall': ('Let residual soreness catch the first words as you recover from the fall.', 'with restrained pain'),
    'TraitFumble': ACTING['frustrated'],
    'TraitHunger': ACTING['uncomfortable'],
    'TraitLoad': ('Speak around the effort of carrying the weight, with short, clear phrases.', 'slightly short of breath'),
    'TraitNausea': ('Pause briefly where the nausea interrupts the thought.', 'low and uneasy'),
    'TraitReluctant': ('Let the words come slowly as the decision weighs on you.', 'quiet and troubled'),
    'TraitRest': ACTING['tired'],
    'TraitScratch': ('Let the sting catch the voice for a moment.', 'with restrained pain'),
    'TraitThirst': ('Sound a little dry and keep the words short.', 'dry and tired'),
    'TraitVigilant': ('Use a low, watchful voice.', 'quietly alert'),
    'TraitWound': ('Let the wound shorten the breath and weigh on the voice.', 'restrained pain'),
    'Uncomfortable': ACTING['uncomfortable'],
    'Wet': ('Let the wet clothes annoy you a little. Keep the line casual.', 'mildly uncomfortable'),
    'Windchill': ('Let the wind and cold tighten your jaw a little while you speak.', 'voice tight with cold'),
}

NONVERBAL = {
    'NativeApplyBandage': 'A small, contained breath or wince as the bandage goes on.',
    'NativeBreath': 'Short recovery breaths after exertion. Let the rate settle slightly.',
    'NativeCough': 'A short, dry cough. Let it break naturally rather than sustaining it.',
    'NativeDeathAlone': 'A weakening final exhale. Let it lose strength quickly.',
    'NativeDeathEaten': 'A brief involuntary cry that breaks off rather than ringing out.',
    'NativeDeathFall': 'A sudden involuntary cry that cuts off abruptly.',
    'NativeDrunkHic': 'A single short, involuntary hiccup.',
    'NativeEffort': 'A short grunt supported by one breath. Match the effort of the movement.',
    'NativeFreezeShiver': 'A small, uneven shiver through the breath or jaw.',
    'NativeMuffledCough': 'Keep the cough contained, as if covering your mouth.',
    'NativePain': 'A brief involuntary pain sound. Make the onset clear and let it settle quickly.',
    'NativePainMoodle': 'Keep the pain sound suppressed, with most of the effort held back.',
    'NativeSighBored': 'A flat, unhurried sigh with little change in pitch.',
    'NativeSighReliefed': 'A small release of tension on the exhale.',
    'NativeSighSad': 'A soft, weighted sigh that fades without a sob.',
    'NativeSleep': 'A gentle resting breath with an even rhythm.',
    'NativeSmoke': 'A short, easy exhale.',
    'NativeSneezeHeavy': 'A sudden full sneeze with a short release.',
    'NativeSneezeLight': 'A short, light sneeze. Keep the release small.',
    'NativeVomit': 'A short involuntary retch with a clean end.',
}

NEED_DIRECTION = {
    1: 'Keep the reaction small.',
    2: 'Let the feeling get your attention for a moment.',
    3: 'Sound strained, but able to finish the thought.',
    4: 'Leave enough breath to get the thought out.',
}


def performance(slot, language):
    """Return the recording direction and the exact bracketed tags sent to Eleven v4."""
    definition = studio_schema.entry(slot)
    group = definition['group']
    source = definition['source']
    acting = definition.get('acting')
    delivery = definition['delivery']
    if definition['category'] != 'Dialogue':
        note = NONVERBAL.get(group, 'Perform the named physical reaction.')
        return f'{note} No spoken words.', []

    if slot == 'KillCount_1' and language.upper() == 'TR':
        return ('Say “otuz bir” clearly, then leave a tiny beat. Let a dry half-smile slip into the line. '
                'Keep it under your breath. No chuckle or extra words.'), ['[dry with a faint smile]']

    situation = SITUATIONS.get(group)
    if source.startswith('PanicEscape_'):
        situation = SITUATIONS['ContextPanicEscape']
    elif source.startswith('PanicGrounding_') or source == 'Panic_1':
        situation = SITUATIONS['ContextPanicGrounding']
    elif source == 'NeedPanic_4':
        situation = ('The fear is making it hard to get the words out. Break once to find air.', 'voice shaking and short of breath')

    # Speech traits can coexist with the event, so use the event as direction without
    # masking the trait with a second, competing tag.
    speech_trait = acting in ('congested', 'slurred', 'stammer')
    profile = ACTING.get(acting) or UNSPECIFIED.get(group)
    note, cue = situation or profile or ('Speak naturally as if thinking aloud in the moment.', '')
    if situation and speech_trait:
        trait_note, cue = ACTING[acting]
        note = f'{note} {trait_note}'

    if source == 'DoorLocked_2':
        note += ' React to a locked opening. The line may also play for a window or vehicle door.'
    elif source == 'DoorBlocked_3':
        note += ' Keep it general enough to play for a blocked window or passage.'
    elif source == 'EngineStalled_2':
        note += ' The engine just cut out. Keep enough urgency for a line that may play under pressure.'

    levels = definition.get('needLevels')
    if levels:
        level = max(levels)
        note = f'{NEED_DIRECTION[level]} {note}'
        if acting == 'unspecified' and level >= 3:
            cue = 'strained by discomfort' if level == 3 else 'weak and uncomfortable'

    if delivery == 'whisper':
        note = f'Use a close, quiet whisper. {note}'
        cue = f'whispers, {cue}' if cue else 'whispers'
    elif delivery == 'shout' and group not in ('NativeCall', 'Fire'):
        note = f'Project just enough to carry. {note}'
        cue = f'calls out, {cue}' if cue else 'calls out'

    return note, [f'[{cue}]'] if cue else []
