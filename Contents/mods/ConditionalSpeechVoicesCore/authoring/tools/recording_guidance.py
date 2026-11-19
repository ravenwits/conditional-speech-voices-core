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
    'controlled': ('Keep the voice low and the words clear. Finish the thought without raising your pitch.', 'low, precise, level pitch'),
    'pain': ('Let the pain hit before the sentence. Recover enough to make the words clear.', 'in sudden pain'),
    'strained': ('Speak through the strain. Let one breath break the phrasing.', 'voice strained'),
    'catchingBreath': ('Begin a little out of breath, then let the words settle.', 'breath settling'),
    'waryRelief': ('Ease the tension a little at the end. Stay alert.', 'quiet, wary relief'),
    'relieved': ('Let the tension release on the last few words.', 'softening with relief'),
    'uneasy': ('Keep a trace of tension in a low, even voice.', 'quietly uneasy'),
    'shaken': ('Let the voice waver. Leave one short break where the thought catches.', 'voice unsteady with shock'),
    'breathless': ('Start with an audible breath. Say the words in short bursts, with a quick breath between phrases. Keep consonants crisp.', 'audibly panting, words in short bursts'),
    'frightened': ('Let fear tighten the voice. Keep the pitch and volume under control.', 'voice tight with fear'),
    'sad': ('Let the voice soften and the ending fall away. Keep it intimate.', 'subdued with sadness'),
    'ill': ('Breathe through your mouth. Use a pinched, stuffy voice, as if speaking with your nose held shut. Keep the words clear.',
            'speaks as if their nose is pinched shut, with an audible mouth breath'),
    'drunk': ('Keep your jaw loose. Draw out one vowel and let the next two words run together. Keep the breath even.', 'drunk, loose jaw, drawn-out vowels and blurred words'),
    'stammer': ('Let stress catch one word, then get the rest out clearly.', 'voice catching under stress'),
    'fading': ('Speak on very little air. Let the voice fall away before forcing another breath.', 'very weak and fading'),
}

# These situations have a more specific performance than their general acting label.
SITUATIONS = {
    'AfterHumanShaken': ('The shock has just landed. Let the voice shake once and catch on the thought.', 'voice trembling with shock'),
    'AfterHumanSteady': ('Stay composed as the weight of what happened sinks in. Let the last words sit.', 'quiet and troubled'),
    'ShelterThump': ('The impact just caught your ear. Start low, pause briefly as you listen, and finish without raising your voice.', 'low and alert, a brief listening pause'),
    'AfterZombieShaken': ('The immediate danger has passed, but the voice has not settled. Break once, then finish the thought.', 'voice still unsteady'),
    'AfterZombieSteady': ('Keep the words measured, with a trace of strain from the encounter.', 'steady with lingering strain'),
    'ContextPanicEscape': ('Start urgent on a short breath. Clip the ends of phrases as you look for space.', 'urgent, short breaths, clipped phrases'),
    'ContextPanicGrounding': ('Start on an uneven breath. Slow the second phrase as you talk yourself down.', 'breath shaky, words gradually slow'),
    'ContextThirstCritical': ('Start with a dry, faint rasp. Leave a little breath for the end of the thought.', 'dry, weak rasp with shallow breath'),
    'CriticalWound': ('The wound makes speaking difficult. Keep the voice low and let one breath interrupt the thought.', 'low and strained with pain'),
    'InjuryAftermath': ('The first shock has passed. Let the remaining soreness affect the breath without a fresh cry.', 'strained with lingering pain'),
    'HumanDanger': ('Take a quick breath as you recognize the danger. Let the next words tumble out.', 'startled breath, words rush out'),
    'DryCoping': ('Say the joke to yourself in an even voice. Leave a beat for it to land.', 'dry and matter-of-fact'),
    'KillDark': ('Give the remark a dry little lift, then cut it short. Keep any amusement small.', 'faintly amused, understated'),
    'KillControlled': ('Keep your voice low. Give each thought the weight of a reminder to yourself.', 'level and focused'),
    'ReloadSteady': ('Set a steady beat with the first words. Keep it while your hands are busy.', 'measured and focused'),
    'MortalFear': ('Let the voice narrow with fear and sound close to breaking. Keep the words intelligible.', 'voice wavering with fear'),
    'ThreatWhisper': ('Keep the voice close and the air low. Let fear tighten the words while trying to stay unheard.', 'tense with fear'),
    'KeepHidden': ('Keep your voice low and your words small. Let the fear show in how carefully you speak.', 'hushed and frightened'),
    'StartleBrave': ('Let the surprise break through on the first word. Catch your breath without slowing down.', 'sharp onset, then firm and steady'),
    'StartleCowardly': ('Catch the words on a short, uneven breath. The threat is right there.', 'breath catches, frightened and unsteady'),
    'StartleDesensitized': ('React in one short burst. Let recognition flatten the surprise.', 'small start, then flat and unfazed'),
    'StartleNormal': ('Let your pitch jump with the surprise. Keep the reaction to one short breath.', 'startled pitch jump, then settling'),
    'JamCleared': ('Let the first words loosen after the setback. Keep the end quiet and attentive.', 'softens with relief, ends focused'),
    'GunJammed': ('Give the recognition a sharp, clipped start. Keep the words controlled as you take stock.', 'clipped frustration, voice held low'),
    'OutOfAmmo': ('Hit the first stressed word quickly. Cut the breath short as you grasp how exposed you are.', 'clipped, urgent, breath held tight'),
    'ReloadPanic': ('Start breathless and hurry the words together. Keep the key words intelligible.', 'breathless and hurried, words tight'),
    'HungerSevere': ('Start low with very little energy. Let the last phrase cost you a little more breath.', 'low and hollow, breath runs short'),
    'Claustrophobic': ('Take a shallow breath before speaking. Let the voice narrow as the room feels smaller.', 'shallow breath, voice tightening'),
    'Bleeding': ('Notice the bleeding with a short break in the voice, then focus on what to do.', 'briefly unsettled, then focused'),
    'Pain': ('Let a little strain catch a stressed word, then finish on a smaller breath.', 'restrained pain, breath catches once'),
    'LostPerson': ('Leave a small hesitation before the realization. Let the voice weaken at the end.', 'hesitant, voice softens with worry'),
    'ShelterAftermath': ('Keep it low enough for yourself. Let the pitch fall on the thought that this place feels different.', 'low, unsettled, pitch falls'),
    'ShelterThreat': ('Let disbelief hold up the opening. Get the remaining words out in a quiet, tight voice.', 'hesitant with disbelief, ends tense'),
    'ReliefThreat': ('Start as if still listening. Let the breath and the last words soften once it seems safe.', 'quiet and watchful, softens into relief'),
    'ReliefAnger': ('Leave a slight edge on the first words. Let your pitch and jaw relax by the end.', 'starts tight, anger eases'),
    'ReliefBleeding': ('Let a little tension out with the first phrase. Keep some weakness in the voice.', 'small relieved exhale, voice still weak'),
    'ReliefDiscomfort': ('Let the first words lead into a longer, easier breath as the discomfort passes.', 'breath eases, voice softens'),
    'ReliefPain': ('Let lingering soreness catch the start. Ease the last words out with less effort.', 'starts strained, eases into relief'),
    'ReliefSickness': ('Stay tired. Let relief show briefly in the final phrase as speaking becomes easier.', 'low and tired, softens into relief'),
    'ReliefSobriety': ('Let the words come one at a time, with the last phrase clearer and more settled.', 'measured, articulation clears'),
    'Endurance': ('Speak on what breath is left. Let it break at a natural phrase boundary.', 'breathless, short phrases'),
    'RepeatedHit': ('Put the frustration on one stressed word. Let the surrounding words run short on breath.', 'breathless, one clipped stress'),
    'VehicleKillDriver': ('Let the realization catch in your throat for half a beat. Keep the rest low and clipped as you watch the road.', 'breath catches on the first word, then a low clipped voice'),
    'VehicleKillPassenger': ('Let the first word come out thin with shock. Let your pitch drop as you register what happened.', 'thin startled voice, pitch drops at the end'),
    'VehicleCrowdDriver': ('Take a shallow breath. Keep your voice low, with a tight little rush as you look for room to move.', 'shallow breath, low voice, words tighten and quicken'),
    'AmmoReserve': ('Speak quietly as if counting to yourself. Give the quantity one clear stress.', 'quiet counting cadence, one clear stress'),
    'ChamberEmpty': ('Let the realization stop you for a beat. Say the rest low and quick.', 'brief held breath, then low and clipped'),
    'PursuitSteady': ('Keep your voice low while you keep pace. Give the words just enough air to come out clearly.', 'low tracking voice, short measured phrases'),
    'WeaponReady': ('Release a little breath as the weapon is ready. Keep the confirmation short.', 'small released breath, clipped and certain'),
    'NativeWhisperCall': ('Let the whisper carry on a thin breath. Give the first word a clear edge, then keep it low.', 'airy projected whisper, crisp first word'),
    'WindowLocked': ('Let one clipped stress mark the lock holding. Keep the rest quiet and matter-of-fact.', 'short clipped stress, then quietly matter-of-fact'),
    'EngineFailed': ('Let a tiny pause mark the failed start. Drop your pitch on the last word.', 'brief hesitation, final pitch drops'),
    'ThreatCalm': ('Keep your breath small and your voice low as you register the threat.', 'low watchful voice, shallow even breath'),
    'VehicleImpactDriver': ('Let the jolt catch the opening. Get the rest out quickly as your attention returns to the road.', 'brief startled catch, then clipped'),
    'VehicleImpactPassenger': ('Let the jolt break the first word. Ask or react on a quick, shallow breath.', 'sharp start, shallow breath'),
    'EngineRecovered': ('The engine has finally started after a failed attempt. Let relief ease into the last few words.', 'softening with relief'),
    'Fire': ('Catch the first word on a sharp breath. Push the rest out quickly as the heat hits.', 'sharp intake, frightened and hurried'),
}

# A change in acting can change what the speaker is trying to do in the same scene.
ACTED_SITUATIONS = {
    ('Angry', 'angry'): ('Let one word burst out. Cut the line off while the anger is still there.', 'sharp burst of anger'),
    ('Drunk', 'drunk'): ('Keep your jaw loose and run the first words together. Over-enunciate the next word as you try to sound sober.', 'drunk, loose jaw, then over-enunciating'),
    ('ReliefBoredom', 'drunk'): ('Give a brief, goofy chuckle as you find something to do. Draw out a vowel and let the words run together.', 'drunk, brief goofy chuckle, vowels drawl'),
    ('HasACold', 'ill'): ('Give one short sniff before speaking. Keep the voice pinched and stuffy, as if your nose is held shut.',
                          'speaks as if their nose is pinched shut'),
    ('ContextPanicEscape', 'frightened'): ('Let fear pinch the first word. Get the rest out in a rush as you look for a way out.', 'tight with fear, words rushing'),
    ('ContextPanicGrounding', 'frightened'): ('Begin with a tremor in your voice. Try to steady yourself on the last few words.', 'frightened tremor, slowly settling'),
    ('MortalFear', 'controlled'): ('Let the fear register, then settle into a firm voice as you decide your next move. Speak on one steady breath.', 'urgent, steady and decisive'),
    ('HumanDanger', 'controlled'): ('Register the attack in a clipped first phrase. Keep your voice level as you decide your next move.', 'clipped and alert, steady pitch'),
    ('KeepHidden', 'controlled'): ('Keep the words low and deliberate. Leave a beat to listen before you finish.', 'hushed and deliberate'),
    ('ShelterThreat', 'controlled'): ('Pause as you realize someone is here. Pick up the pace as you think through a way out.', 'brief pause, then focused urgency'),
    ('AfterHumanSteady', 'tired'): ('Speak low, as if the encounter took the last of your energy. Let the final word come slowly.', 'low and weary'),
    ('AfterZombieSteady', 'tired'): ('Give yourself a breath before you speak. Let fatigue draw out the last few words.', 'weary, slowing at the end'),
    ('GunJammed', 'angry'): ('Bite down on the first stressed word. Keep the rest short as you deal with the jam.', 'sharp, clipped anger'),
    ('GunJammed', 'frightened'): ('Let the jam catch you mid-breath. Rush the last words as you grasp the danger.', 'breath catches, voice tight with fear'),
    ('OutOfAmmo', 'angry'): ('Hit the word that names the problem. End the outburst abruptly.', 'sharp stress, clipped with anger'),
    ('OutOfAmmo', 'frightened'): ('Pause for a beat when you realize you are empty. Get the next words out on a thin breath.', 'brief hesitation, voice tight with fear'),
    ('InjuryAftermath', 'strained'): ('Speak through the soreness. Ease off on the last few words as your breath runs short.', 'low and strained with pain'),
    ('ReliefThreat', 'catchingBreath'): ('Start on the breath you have left. Take an easier breath when you realize you are safe.', 'out of breath, then easing'),
}

# The scene can change the intention of a physical delivery without giving the
# slurred take the source recording's breathing instructions.
PHYSICAL_CONTEXT = {
    'ContextPanicEscape': ('Keep the urgency of looking for an exit.', 'urgent'),
    'ContextPanicGrounding': ('Slow down as you talk yourself through the panic.', 'slows while regaining control'),
    'CriticalWound': ('Keep the voice low from the pain.', 'low with pain'),
    'InjuryAftermath': ('Let the lingering soreness show on one stressed word.', 'sore and restrained'),
    'ExhaustedCoping': ('Let the last few words lose energy as you try to recover.', 'runs out of steam'),
    'GunJammed': ('Let the jam register sharply on the first stressed word.', 'sharp first stress'),
    'OutOfAmmo': ('Stress the word that makes the problem clear.', 'urgent'),
    'ReloadBreathless': ('Keep your attention on finishing the reload.', ''),
    'RepeatedHit': ('Put the frustration into one stressed word.', 'one sharp stress'),
    'Pain': ('Let one word carry the pain.', 'restrained pain'),
    'PainGeneric': ('Let one word carry the pain.', 'restrained pain'),
    'HungerSevere': ('Keep the voice low and spent.', 'low with fatigue'),
    'Thirst': ('Give the vowel a little dryness.', 'dry and strained'),
}

# A shared take must work for ordinary survivors and for the controlled route.
# The actual frightened and controlled slots keep different performances.
SHARED_FALLBACK = {
    'MortalFear': ('Let fear tighten your voice. Get the words out quickly and keep each one clear.', 'tight with fear, urgent and clear'),
    'HumanDanger': ('Give the first words a sharp start as you recognize the attack. Make the rest quick and clear.', 'sharp onset, alert and quick'),
    'KeepHidden': ('Keep your voice low and tight. Leave a beat to listen between thoughts.', 'hushed and tense, listening'),
    'ShelterThreat': ('Let the recognition interrupt the first thought. Finish in a low, urgent voice.', 'brief hesitation, then low and urgent'),
}

STEADY_TRAITS = {'Brave', 'Desensitized'}


# Situation cues for readings that have no specific acting label.
UNSPECIFIED = {
    'AmmoCount': ('Count clearly at a low, even volume, as if checking for yourself.', 'counting quietly'),
    'Angry': ACTING['angry'],
    'AnimalTracks': ('Pause as you spot the tracks. Say the rest as a quiet observation.', ''),
    'BookReading': ('Murmur to yourself at an unhurried pace, as if keeping your place on the page.', ''),
    'Bored': ('Let the first few words drag while you search for something to do.', ''),
    'BloodOnSkin': ('Catch sight of the blood on your skin. Swallow before the last few words.', 'voice tight with disgust'),
    'BiteWound': ('Say it like the realization just hit. Let the first word catch, then get the rest out clearly.', 'voice catches in disbelief'),
    'WoundSite': ('Feel the sore spot as you speak. Put the stress on where it hurts.', 'low, pained voice'),
    'BleedingSite': ('Notice the blood. Keep the words short and clear.', 'startled, then focused'),
    'BloodAversion': ('Let the first thought catch in your throat, then turn away from it.', 'voice catching with unease'),
    'BoredMore': ('Let the thought drift and the pitch stay almost level.', 'low and listless'),
    'CampfireLit': ('Ease out a breath when the flame catches. Let the words follow it.', ''),
    'ClothingPatched': ('Say it to yourself as you check whether the patch will hold.', ''),
    'ClothingSewn': ('Finish the thought on a small downward note as you put the needle away.', ''),
    'Darkness': ('Keep your voice low as you work out what you can see.', 'quietly uneasy'),
    'Discomfort': ('Let a brief note of physical irritation through the words.', 'slightly uncomfortable'),
    'Drunk': ACTING['drunk'],
    'Explore': ('Sound curious. Leave a beat as you look into the space ahead.', ''),
    'ExploreMore': ('Keep your voice low and attentive as your eyes move around the room.', ''),
    'FoodEaten': ('Let the first words come easily after you swallow. Ease up on the final phrase.', ''),
    'FoodRaw': ('Hesitate briefly as you realize the food is undercooked.', 'hesitant'),
    'FoodRotten': ('Let the realization turn your voice away from the food.', 'with quiet disgust'),
    'FoodSuspect': ('Hold on the uncertain word for a beat while you decide whether to trust the food.', 'with quiet suspicion'),
    'Foraged': ('Let a little pleasure enter your voice as you recognize something worth keeping.', ''),
    'FoundLoot': ('Say it briskly, as if you have already decided to keep the item.', ''),
    'Full': ('Speak slowly and comfortably, as if putting the rest of the food aside.', ''),
    'GeneratorRepaired': ('Let a little satisfaction through as you check your work.', ''),
    'GeneratorStarted': ('Listen for a beat. Say the line once you hear the engine running.', ''),
    'HasACold': ACTING['ill'],
    'HeatMild': ('Let the warmth sap a little energy from the words.', 'slightly drained by heat'),
    'HeavyLoad': ('Get the words out around the effort of carrying the weight.', 'slightly short of breath'),
    'Holes': ('Give the tear a small, irritated acknowledgment while you inspect it.', ''),
    'Hungry': ('Speak on an empty stomach. Let the lack of energy carry into your voice.', ''),
    'Hyperthermia': ('Speak low and drained, with just enough air to finish the thought.', 'weak and overheated'),
    'Hypothermia': ('Use a little tension in the jaw and voice. Keep the shiver subtle.', 'voice tight with cold'),
    'Kill': ('Acknowledge what just happened on a short, level breath. Let the line end quickly.', 'short and matter-of-fact'),
    'KillCount': ('State the exact count as a quiet observation. Keep the number clear and the delivery dry.', 'dry, underplayed'),
    'LevelUp': ('Let a little pride come through as you notice the work getting easier.', ''),
    'MealPrepared': ('Speak to yourself as you check the food. Finish with quiet satisfaction.', ''),
    'NativeCall': ('Aim the voice at someone at a distance. Keep the call brief and clear.', 'calls out clearly'),
    'NativeLureCmon': ('Draw their attention with a small, deliberate call.', 'low, deliberate call'),
    'NativeLureTsk': ('Give one short signal with your mouth, as if trying to draw attention discreetly.', 'quietly'),
    'NicotineNeed': ('Let the restlessness put a slight edge on the words.', 'restless and subdued'),
    'NoxiousSmell': ('Let the smell cut the thought short. Keep any gag out of the spoken line.', 'with quiet disgust'),
    'OnDawn': ('Take a breath as you look up. Let the words come slowly in the morning quiet.', ''),
    'OnDusk': ('Notice the fading light, then give the last words a little urgency.', ''),
    'ReliefBoredom': ('Let a little more energy return to your voice.', 'with mild renewed interest'),
    'ReliefColdSymptoms': ('Let your voice come a little easier as the symptoms ease.', 'softening with relief'),
    'ReliefLoad': ('Let the words come more easily once the weight is off.', 'breath settling'),
    'ReliefMood': ('Let a touch of warmth back into the voice.', 'with quiet relief'),
    'ReliefWet': ('Ease the irritation out of the voice as you dry off.', 'softening with relief'),
    'RottenMore': ('Let the disgust register briefly, then move on.', 'with quiet disgust'),
    'SawLogsDone': ('Take a short working breath, then acknowledge what you have finished.', ''),
    'Sick': ('Keep the energy low and let the phrase take a little effort.', 'low and unwell'),
    'SickFromFood': ('Keep the voice low and let the nausea interrupt one thought.', 'low and uneasy'),
    'SmokeFinished': ('Let the tension go on the exhale before you speak.', ''),
    'TracksMore': ('Quiet your voice as you stop to study the tracks.', ''),
    'ThreatCalm': ('You have noticed a threat at a distance. Keep the observation low and measured.', 'calm and watchful'),
    'TraitCold': ACTING['ill'],
    'TraitDriver': ('Speak low with your attention on the road. Make the warning clear in one measured breath.', 'low, precise warning on one breath'),
    'TraitFall': ('Let residual soreness catch the first words as you recover from the fall.', 'with restrained pain'),
    'TraitFumble': ACTING['frustrated'],
    'TraitFull': ('Ease out the first words. Finish as if setting the food aside for later.', 'satisfied, unhurried'),
    'TraitHunger': ACTING['uncomfortable'],
    'TraitIlliterate': ('Hesitate over the first thought. Let the admission come out plainly in your own voice.', 'hesitant, then candid'),
    'TraitLoad': ('Speak around the effort of carrying the weight, with short, clear phrases.', 'slightly short of breath'),
    'TraitNausea': ('Pause briefly where the nausea interrupts the thought.', 'low and uneasy'),
    'TraitReading': ('Stop briefly as your attention wanders. Bring the last words back into focus.', 'distracted, then focused'),
    'TraitSight': ('Speak slowly as you try to make something out. Keep the uncertainty small.', 'quietly uncertain'),
    'TraitStudy': ('Take a beat to think, then give yourself an even, patient answer.', 'patient and thoughtful'),
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

NATIVE_PREVIEW_SCRIPTS = {
    'NativeApplyBandage': '[lets out a short, restrained breath] Ah…',
    'NativeDeathAlone': '[breathes out weakly, fading fast] Hah…',
    'NativeDeathEaten': '[cries out sharply, then cuts off] Aaah!',
    'NativeDeathFall': '[lets out a sudden, short cry] Aaah!',
    'NativeDrunkHic': '[hiccups once] Hik!',
    'NativeEffort': '[grunts once with effort] Hng!',
    'NativeFreezeShiver': '[shivers with a short, uneven breath] Hh…',
    'NativePain': '[lets out a brief groan of pain] Ah!',
    'NativePainMoodle': '[stifles a quiet groan of pain] Ngh…',
    'NativeSleep': '[breathes softly and evenly] Hh…',
    'NativeSmoke': '[exhales softly] Hah…',
    'NativeSneezeHeavy': '[sneezes forcefully once] Hapşu!',
    'NativeSneezeLight': '[sneezes softly once] Hapşu…',
    'NativeVomit': '[retches briefly] Ugh!',
    'NativeBreath': '[takes two short recovery breaths] Hah… hah…',
    'NativeCough': '[coughs once, dry and short] Kh, kh!',
    'NativeMuffledCough': '[coughs once into a closed hand] Kh…',
    'NativeSighBored': '[lets out a flat, bored sigh] Hah…',
    'NativeSighReliefed': '[sighs softly with relief] Oh…',
    'NativeSighSad': '[lets out a soft, heavy sigh] Ah…',
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

    scene = group
    if source.startswith('PanicEscape_'):
        scene = 'ContextPanicEscape'
    elif source.startswith('PanicGrounding_') or source == 'Panic_1':
        scene = 'ContextPanicGrounding'
    situation = SITUATIONS.get(scene)
    if source == 'Panic_3':
        situation = ('Get the first words out on a shallow breath. Let fear rush the next phrase.', 'frightened, breath short and speech rushed')
    elif source == 'NeedPanic_4':
        situation = ('The fear is making it hard to get the words out. Break once to find air.', 'voice shaking and short of breath')

    trait_rule = definition.get('traitRule', {})
    steady_route = STEADY_TRAITS.intersection(trait_rule.get('traits', []))
    shared = steady_route and trait_rule.get('kind') == 'conditional' and scene in SHARED_FALLBACK
    if shared:
        situation = SHARED_FALLBACK[scene]
    elif steady_route and trait_rule.get('kind') == 'preferred':
        if source == 'PanicGrounding_2':
            situation = ('Take a beat to gather yourself. Bring the pitch back to steady before the last words.', 'measured self-talk, pitch settles')
        elif source == 'ThreatTense_2':
            situation = ('Give yourself a short warning in a low, steady voice. Keep the urgency in the pacing.', 'low and steady, restrained urgency')
    elif trait_rule.get('kind') == 'required' and 'Hunter' in trait_rule.get('traits', ()) and scene == 'AnimalTracks':
        situation = ('Recognize the tracks right away. Say the line quietly as you decide which way to go.', 'quiet recognition, focused')

    base_acting = acting if slot == source else studio_schema.entry(source)['acting']
    base = situation or ACTING.get(base_acting) or UNSPECIFIED.get(group)
    direction = ACTED_SITUATIONS.get((scene, acting))
    physical_acting = 'drunk' if scene == 'Drunk' and acting == 'unspecified' else acting
    if source == 'Drunk_3' and physical_acting == 'drunk' and delivery == 'normal':
        direction = ('Let one small hiccup escape before you speak. Keep your jaw loose and draw out one vowel.',
                     'drunk, a brief hiccup before speaking, loose drawl')
    if direction is None and physical_acting in ('drunk', 'breathless'):
        physical_note, physical_cue = ACTING[physical_acting]
        scene_note, scene_cue = PHYSICAL_CONTEXT.get(scene, ('', ''))
        direction = ' '.join(filter(None, (scene_note, physical_note))), ', '.join(filter(None, (physical_cue, scene_cue)))
    if direction is None and base_acting != acting:
        direction = ACTING.get(acting)
        if acting in ('ill', 'stammer') and base and base != direction:
            # Physical articulation can coexist with the emotion of the source line.
            base_note, base_cue = base
            trait_note, trait_cue = direction
            cue = f'{trait_cue}, {base_cue}' if base_cue else trait_cue
            direction = f'{base_note} {trait_note}', cue
    note, cue = direction or base or ('Speak naturally as if thinking aloud in the moment.', '')

    if shared:
        note += ' Brave or Desensitized survivors use this as a fallback when their steadier options are unavailable.'

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
    elif delivery == 'shout' and group == 'Fire':
        note = 'Cry out on the first word as the heat hits. Project the remaining words on the same breath, then cut off.'
        cue = 'cries out sharply in pain'
    elif delivery == 'shout' and group != 'NativeCall':
        note = f'Project just enough to carry. {note}'
        cue = f'calls out, {cue}' if cue else 'calls out'

    tags = [f'[{cue}]'] if cue else []
    if scene == 'HasACold' and delivery == 'normal' and acting == 'ill':
        tags.insert(0, '[sniffs]')
    return note, tags
