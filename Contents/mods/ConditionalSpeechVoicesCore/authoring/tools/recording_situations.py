"""Describe the gameplay event behind a Studio take. The game owns selection."""

# These are actor-facing descriptions of gameplay events. Trait selection and
# performance directions have their own fields on the recording.
EVENTS = {
    # Encounters with people and zombies.
    'AfterHumanShaken': 'Once safe after killing someone, the survivor struggles with what happened.',
    'AfterHumanSteady': 'Once safe after killing someone, an experienced survivor keeps their composure.',
    'AfterZombieShaken': 'The fight is over, but the survivor is still shaken by a zombie they killed.',
    'AfterZombieSteady': 'After a zombie kill, an experienced survivor has a quiet moment to collect themselves.',
    'FoundPerson': 'The person the survivor was tracking comes back into view.',
    'FriendMissing': 'The survivor loses sight of someone they marked as a friend.',
    'HumanDanger': 'A person attacks while panic is below level 3, or a survivor familiar with raids faces another attack at their shelter.',
    'HumanGroup': 'Two or more other people come into view nearby.',
    'InjuryAftermath': 'After a severe injury, the survivor regains health and reaches safety.',
    'KeepHidden': 'While sneaking, the survivor loses sight of someone who was pursuing them.',
    'LostPerson': 'The survivor loses sight of the person they were pursuing.',
    'MortalFear': 'At panic level 3 or 4, a person attacks or a nearby enemy attacks or gives chase.',
    'PursuitSteady': 'The survivor starts following a person they can see and keeps their composure.',
    'PursuitUneasy': 'The survivor starts following a person they can see and feels uneasy about the pursuit.',
    'ShelterAftermath': 'After an attack at their marked shelter, the survivor has had time to feel safe again.',
    'ShelterThump': 'Inside a building, the survivor hears the first nearby zombie strike on a door, window or its barricade. Repeated strikes on the same opening are one encounter.',
    'ShelterThreat': 'Someone attacks at the survivor’s marked shelter before they are accustomed to raids.',
    'StillAlive': 'The survivor reaches safety after escaping an attacker, or after surviving a familiar kind of injury or shelter raid.',
    'TraitReluctant': 'The survivor reflects on killing a person or a zombie after the immediate danger has passed.',
    'ThreatCalm': 'The survivor spots a nearby threat before panic takes hold, or sees a zombie that has not reacted to them.',
    'ThreatTense': 'The survivor senses a close threat, including a zombie approaching, targeting or attacking them.',
    'ThreatWhisper': 'The survivor is sneaking near a threat and can give a quiet warning without giving away their position.',
    'ReliefThreat': 'Nearby danger has cleared and the area has stayed quiet for at least ten seconds.',
    'ContextPanicGrounding': 'The survivor feels panic without a visible or recent threat.',
    'ContextPanicEscape': 'Panic is high and a threat is close enough to reach the survivor.',
    'MultiHit': 'The survivor hits the same zombie at least four times within two minutes, with at least three nearby zombies reacting to the fight.',
    'RepeatedHit': 'The survivor hits the same zombie at least four times within two minutes, with fewer than three nearby zombies reacting to the fight.',
    'Kill': 'The survivor kills a zombie.',
    'KillAngry': 'The survivor kills a zombie while angry and still has the fight under control.',
    'KillControlled': 'The survivor kills a zombie and can keep a level head.',
    'KillDark': 'After many zombie encounters, the survivor kills another while calm and in good condition.',
    'KillDesperate': 'The survivor kills a zombie while panicking, badly hurt or struggling under attack.',
    'KillUneasy': 'The survivor kills a zombie and reacts uneasily to it.',
    'DryCoping': 'After a zombie kill, an experienced survivor has a quiet moment with no other threat in sight.',

    # Weapon, vehicle, shelter and routine actions.
    'GunJammed': 'The gun jams.',
    'OutOfAmmo': 'The survivor tries to use an empty gun.',
    'ChamberEmpty': 'The gun still holds ammunition, but its chamber is empty.',
    'AmmoReserve': 'The survivor checks the rounds left in a gun. The count falls outside the numbers the game calls out individually.',
    'LowAmmo': 'The survivor notices the gun is running low on rounds.',
    'ReloadPanic': 'The survivor reloads during a threat while panicking.',
    'ReloadBreathless': 'The survivor reloads during a threat while severely exhausted.',
    'ReloadShaken': 'The survivor reloads during a threat while both very unhappy and stressed.',
    'ReloadSteady': 'The survivor reloads during a threat and can still keep their hands steady.',
    'JamCleared': 'The survivor clears a jam and the gun is no longer stuck.',
    'WeaponReady': 'The gun becomes ready to fire after the survivor works on it.',
    'WeaponBroken': 'A swing breaks the weapon in the survivor’s hand.',
    'BatteryDead': 'An engine start fails and the vehicle battery is empty.',
    'EngineFailed': 'The engine fails to start.',
    'EngineRecovered': 'The engine starts after an earlier attempt failed.',
    'EngineStalled': 'Damage or a fuel problem stops the running engine.',
    'FuelEmpty': 'The running engine stops as the fuel tank empties.',
    'FuelLow': 'Fuel runs low while the engine is running.',
    'HotwireDone': 'The survivor successfully hotwires a vehicle.',
    'HeadlightsFailed': 'In the dark, the survivor switches on the headlights but they give no light despite battery power.',
    'CarAlarm': 'The survivor sets off a vehicle alarm.',
    'VehicleDamage': 'The vehicle takes damage.',
    'CarWindowOpened': 'The survivor gets a vehicle window open.',
    'CarWindowBroken': 'The survivor smashes a vehicle window.',
    'DoorBlocked': 'The survivor tries a door and finds something blocking it.',
    'DoorLocked': 'The survivor tries a building or vehicle door and finds it locked.',
    'WindowBarricaded': 'The survivor tries a window and finds it barricaded.',
    'WindowLocked': 'The survivor tries a window and hears the lock hold.',
    'BandageDone': 'The survivor finishes bandaging their own wound or another person’s.',
    'DisinfectDone': 'The survivor finishes disinfecting their own wound or another person’s.',
    'BookReading': 'The survivor makes progress through a book.',
    'GeneratorStarted': 'The survivor gets a generator running.',
    'GeneratorRepaired': 'A repair improves the generator’s condition.',
    'CampfireLit': 'The survivor gets a campfire burning.',
    'ClothingPatched': 'The survivor finishes patching a garment.',
    'ClothingSewn': 'The survivor makes a garment by sewing.',
    'CropHarvested': 'The survivor harvests a planted crop and receives the produce in their inventory. In multiplayer, the server confirms the harvest.',
    'FishCaught': 'The survivor lands a fish and receives it in their inventory. In multiplayer, the server confirms the catch.',
    'TraitGlasswork': 'The survivor shapes hot glass into a new piece of glassware. In multiplayer, the server confirms the result.',
    'TraitForgeWork': 'The survivor finishes forging a tool or a piece of hardware. In multiplayer, the server confirms the result.',
    'TraitMasonry': 'The survivor finishes shaping a stone block, grindstone or stone anvil. In multiplayer, the server confirms the result.',
    'TraitWhittling': 'The survivor carves a wooden spoon, tongs or handle. In multiplayer, the server confirms the result.',
    'MealPrepared': 'The survivor prepares food or adds an ingredient to a dish.',
    'SawLogsDone': 'The survivor finishes sawing logs into planks.',
    'SmokeFinished': 'The survivor finishes smoking.',
    'Explore': 'The survivor searches a place for something useful.',
    'ExploreMore': 'The survivor looks around for something useful.',
    'AnimalTracks': 'The survivor finds animal tracks.',
    'TracksMore': 'The survivor finds animal tracks.',
    'FoundLoot': 'The survivor picks up an item while looting.',
    'Foraged': 'The survivor finds something while foraging.',
    'LevelUp': 'The survivor gains a skill level.',
    'Holes': 'The survivor notices damage to their clothing.',
    'OnDawn': 'Day breaks.',
    'OnDusk': 'Night starts to fall.',
    'Darkness': 'The survivor is awake somewhere too dark to see well.',

    # Needs, mood, injury and reactions to food.
    'Agoraphobic': 'Being outside makes the survivor anxious.',
    'Claustrophobic': 'Being indoors makes the survivor anxious.',
    'Angry': 'The survivor feels angry.',
    'Bleeding': 'One or more of the survivor’s own wounds are bleeding.',
    'Bored': 'The survivor feels bored.',
    'BoredMore': 'The survivor feels bored.',
    'CantSprint': 'The game reports that the survivor cannot sprint.',
    'ColdMild': 'The survivor starts to feel cold.',
    'ContextThirstCritical': 'The survivor is desperately thirsty.',
    'CriticalFading': 'Health falls to 10% or less, or to 25% or less without bleeding or a fresh injury.',
    'CriticalWound': 'The survivor is bleeding or has a fresh injury, with health above 10% and at most 25%.',
    'Discomfort': 'The survivor feels physically uncomfortable.',
    'Drunk': 'The survivor feels the effects of alcohol.',
    'Endurance': 'Physical exertion leaves the survivor short of breath.',
    'Fire': 'The survivor is on fire and health has fallen to 25% or less.',
    'FoodEaten': 'The survivor eats.',
    'FoodRaw': 'The survivor eats raw food.',
    'FoodRotten': 'The survivor eats rotten food.',
    'FoodSuspect': 'The survivor feels sick after eating.',
    'Full': 'The survivor reacts after eating.',
    'HasACold': 'The survivor has cold symptoms.',
    'HeatMild': 'The survivor starts to feel too warm.',
    'HeavyLoad': 'The survivor is carrying a heavy load.',
    'HungerSevere': 'Hunger has reached a severe level.',
    'Hungry': 'The survivor feels hungry.',
    'Hyperthermia': 'The survivor overheats.',
    'Hypothermia': 'The survivor’s body temperature drops.',
    'Injured': 'The survivor’s health has fallen and they have a physical injury.',
    'InjuryAcute': 'The survivor feels a fresh physical injury.',
    'NoxiousSmell': 'The survivor notices a noxious smell.',
    'Pain': 'The survivor feels pain.',
    'PainGeneric': 'The survivor feels moderate pain.',
    'Panic': 'The survivor feels panic.',
    'RottenMore': 'The survivor eats rotten food.',
    'Sick': 'The survivor feels ill.',
    'Stress': 'The survivor feels stressed.',
    'Thirst': 'The survivor feels thirsty.',
    'Tired': 'The survivor feels tired.',
    'Unhappy': 'The survivor feels unhappy.',
    'Wet': 'The survivor is wet.',
    'Windchill': 'The wind makes the survivor feel cold.',

    # Personal reactions. Eligibility belongs in the separate trait rule.
    'BloodOnSkin': 'Away from immediate danger, the survivor is standing and panicked, with visible blood on their skin and no actively bleeding wound. The source of the stain is unknown.',
    'BloodAversion': 'Away from immediate danger, the survivor panics while one of their own wounds is bleeding.',
    'ExhaustedCoping': 'The survivor is winded, out of immediate danger and free to catch their breath. Pain, bleeding, cold symptoms, drunkenness and sneaking rule out this take.',
    'NicotineNeed': 'Nicotine withdrawal stresses the survivor while the area is quiet.',
    'TraitCold': 'The survivor notices their cold symptoms away from nearby danger.',
    'TraitDriver': 'The driver sees a nearby threat while the vehicle is moving and remains calm.',
    'TraitFall': 'A few seconds after a fall, the survivor is back on their feet.',
    'TraitFull': 'The survivor eats enough to satisfy their hunger.',
    'TraitFumble': 'The survivor moves items between containers while zombies are visible.',
    'TraitHunger': 'The survivor starts feeling hungry away from nearby danger.',
    'TraitIlliterate': 'The survivor inspects written material in their inventory.',
    'TraitLoad': 'A heavy load is tiring the survivor out away from nearby danger.',
    'TraitNausea': 'The survivor feels sick away from nearby danger.',
    'TraitReading': 'The survivor has been reading the same book for a while and feels stressed.',
    'TraitRest': 'The survivor wakes up and still feels tired.',
    'TraitScratch': 'A fresh scratch or cut still hurts a few seconds later.',
    'TraitSight': 'The survivor is awake and the light drops too low to see well.',
    'TraitStudy': 'The survivor studies a recipe or makes progress in a skill book.',
    'TraitThirst': 'The survivor starts feeling thirsty away from nearby danger.',
    'TraitVigilant': 'The survivor spots a nearby zombie while calm.',
    'TraitWound': 'A wound has lingered for at least two in-game days.',

    # Game voice events. These replace the matching sound at its usual time.
    'NativeApplyBandage': 'The game plays the survivor’s bandaging sound.',
    'NativeBreath': 'The game plays an exercise breath.',
    'NativeCall': 'The survivor calls out, with or without a megaphone.',
    'NativeCough': 'The survivor coughs.',
    'NativeDeathAlone': 'The survivor dies alone.',
    'NativeDeathEaten': 'Zombies overwhelm and kill the survivor.',
    'NativeDeathFall': 'The survivor dies from a fall.',
    'NativeDrunkHic': 'The survivor hiccups while drunk.',
    'NativeEffort': 'The survivor strains during a climb, jump, melee attack or while moving a body.',
    'NativeFreezeShiver': 'The survivor shivers from the cold.',
    'NativeLureCmon': 'The survivor uses the “come on” lure call.',
    'NativeLureTsk': 'The survivor uses a tongue click to lure attention.',
    'NativeMuffledCough': 'The survivor muffles a cough.',
    'NativePain': 'A blow, bite, cut, fall or collision hurts the survivor.',
    'NativePainMoodle': 'Ongoing pain triggers a groan.',
    'NativeSighBored': 'The survivor sighs with boredom.',
    'NativeSighReliefed': 'The survivor sighs with relief.',
    'NativeSighSad': 'The survivor sighs with sadness.',
    'NativeSleep': 'The game plays the survivor’s sleeping sound.',
    'NativeSmoke': 'The game plays the survivor’s smoking sound.',
    'NativeSneezeHeavy': 'The survivor sneezes hard.',
    'NativeSneezeLight': 'The survivor gives a light sneeze.',
    'NativeVomit': 'The survivor vomits.',
    'NativeWhisperCall': 'The survivor uses a whispered call, with or without a megaphone.',
}

# Every recovery below waits until the area is safe and the moodle clears.
RECOVERIES = {
    'ReliefAnger': 'anger passes', 'ReliefBleeding': 'the survivor’s last actively bleeding wound stops bleeding',
    'ReliefBoredom': 'boredom passes', 'ReliefCold': 'the survivor warms up',
    'ReliefColdSymptoms': 'the cold symptoms clear', 'ReliefDiscomfort': 'the discomfort passes',
    'ReliefEndurance': 'the survivor catches their breath', 'ReliefHeat': 'the survivor cools down',
    'ReliefHunger': 'the hunger passes', 'ReliefLoad': 'the load is light enough to carry',
    'ReliefMood': 'the survivor’s mood lifts', 'ReliefPain': 'the pain subsides',
    'ReliefRest': 'the survivor feels rested', 'ReliefSickness': 'the sickness passes',
    'ReliefSobriety': 'the survivor sobers up', 'ReliefStress': 'the stress passes',
    'ReliefThirst': 'the survivor quenches their thirst', 'ReliefWet': 'the survivor dries off',
}

PICKUPS = {
    'LootAmmo': 'compatible ammunition while their supply is low',
    'LootBandage': 'a bandage while they have an uncovered wound',
    'LootCanOpener': 'a can opener for sealed food they could not open',
    'LootClothing': 'a better dry layer while cold',
    'LootFood': 'edible food while hungry',
    'LootLight': 'their first working light while in the dark',
    'LootMagazine': 'a magazine for a gun that needs one',
    'LootPainMedicine': 'pain medicine while in pain',
    'LootStomach': 'a stomach remedy while suffering from food sickness',
    'LootWater': 'clean water while thirsty',
    'LootWeapon': 'a working weapon they can use',
}

VEHICLE_EVENTS = {
    'VehicleCrowd': 'At least four zombies surround the vehicle',
    'VehicleSiege': 'Zombies surround and attack the vehicle while panic is high',
    'VehicleImpact': 'The vehicle hits a live zombie',
    'VehicleKill': 'The survivor sees the vehicle kill a zombie',
}

STARTLE = {'StartleBrave', 'StartleCowardly', 'StartleDesensitized', 'StartleNormal'}

# A different take of a line can have a different gameplay condition.
SOURCE_EVENTS = {
    'DisinfectDone_1': 'The survivor feels the sting after disinfecting their own wound.',
    'Bleeding_1': 'The survivor has a cut on a body part that is actively bleeding.',
    'BleedingUnspecified_1': 'While the survivor is not sneaking, health is above 25% and bleeding is below level 4. No cut was confirmed on a bleeding body part.',
    'DoorLocked_2': 'A door is locked. A locked window can also use this line if the pack lacks a window take.',
    'DoorBlocked_3': 'A door is blocked. A barricaded window can also use this line if the pack lacks a window take.',
    'AfterZombieShaken_2': 'After a zombie kill, the survivor is safe but still feels at least moderate panic.',
    'InjuryAftermath_3': 'The survivor is safe and recovering from a severe injury but still feels pain.',
    'MortalFear_3': 'During an attack or close pursuit, panic reaches level 4, or level 3 with at least moderate exhaustion.',
    'KillControlled_1': 'After a zombie kill, the survivor stays composed with at least two enemies nearby or in view.',
    'KillDesperate_4': 'The survivor struggles after a zombie kill with at least two enemies nearby or in view.',
    'KillDesperate_5': 'The survivor struggles after a zombie kill with at least two enemies nearby or in view.',
    'Kill_2': 'The survivor kills a zombie while panicking, badly hurt or struggling under attack.',
    'StartleCowardly_8': 'A zombie startles the survivor during an attack or pursuit while panic is high.',
}
SOURCE_FAMILIES = {
    'PanicEscape': EVENTS['ContextPanicEscape'],
    'PanicGrounding': EVENTS['ContextPanicGrounding'],
    'ThirstCritical': EVENTS['ContextThirstCritical'],
}

EXPRESSION_CONDITIONS = {
    'angry': 'This take can play when the survivor is angry.',
    'breathless': 'This take can play when the survivor is winded.',
    'ill': 'This take can play when the survivor has a cold.',
    'sad': 'This take can play when the survivor is very unhappy.',
    'drunk': 'This take can play from intoxication level 2 when a higher-priority delivery does not apply.',
    'stammer': 'High panic or overheating can bring out this take.',
    'frightened': 'This take can play during acute fear or an immediate threat.',
}
ALTERNATE_CONDITIONS = {
    'exertion': 'This take requires at least moderate exertion.',
    'cold': 'This take requires severe cold.',
    'heat': 'This take requires severe heat.',
    'danger': 'This take requires a direct attack or active pursuit.',
}
KILL_COUNTS = (31, 50, 100, 200)
NEED_NAMES = {
    'Bored': 'Boredom', 'Hungry': 'Hunger', 'Panic': 'Panic', 'Stress': 'Stress',
    'Thirst': 'Thirst', 'Tired': 'Fatigue', 'Unhappy': 'Unhappiness',
}


def _event(definition):
    group = definition['group']
    source = definition['source'].removeprefix('Whisper_')
    stem, _, index = source.rpartition('_')
    if definition.get('nativeEvents') == ['PainFromBite']:
        return 'The game triggers its immediate pain sound for a bite. Record a brief involuntary reaction.'
    if group == 'BiteWound':
        region = definition.get('bodyRegion')
        trigger = ('During an injury reaction, or a bleeding reaction if a bitten body part is bleeding. '
                   'The survivor is not sneaking and health is above 25%.')
        if region:
            location = {'Chest': 'upper torso', 'Belly': 'lower torso'}.get(region, region.lower())
            return f'{trigger} The {location} is the only body part with a bite that matches this reaction.'
        return f'{trigger} A bite is confirmed. This general take also works when the location is uncertain.'
    if region := definition.get('bodyRegion'):
        location = {'Chest': 'upper torso', 'Belly': 'lower torso'}.get(region, region.lower())
        if group == 'BleedingSite':
            return f'While the survivor is not sneaking, health is above 25%. Only their {location} is bleeding.'
        return f'While the survivor is not sneaking, health is above 25%. Only their {location} is injured.'
    if source in SOURCE_EVENTS:
        return SOURCE_EVENTS[source]
    if stem in SOURCE_FAMILIES:
        return SOURCE_FAMILIES[stem]
    if (definition['slot'] == source and definition.get('needLevels')
            and group in NEED_NAMES):
        levels = ' or '.join(str(level) for level in definition['needLevels'])
        return f'{NEED_NAMES[group]} reaches level {levels} of 4.'
    if group in STARTLE:
        if index.isdecimal() and int(index) >= 7:
            return 'A nearby zombie startles the survivor in the middle of an attack or pursuit.'
        return 'A nearby zombie startles the survivor. The line plays as the game’s surprise sound starts.'
    if group in RECOVERIES:
        return f'The area is safe and {RECOVERIES[group]}.'
    if group in PICKUPS:
        return f'The survivor picks up {PICKUPS[group]} and has a safe moment to speak.'
    if group == 'AmmoCount':
        rounds = 'round' if index == '1' else 'rounds'
        return f'The survivor checks their gun and has {index} {rounds} left.'
    if group == 'KillCount':
        return f'The survivor reaches {KILL_COUNTS[int(index) - 1]} confirmed zombie kills while calm.'
    for event, action in VEHICLE_EVENTS.items():
        if group == event + 'Driver':
            return f'{action} while the survivor is driving.'
        if group == event + 'Passenger':
            return f'{action} while the survivor is a passenger.'
    return EVENTS[group]


def playback_when(definition):
    """Return the event and the conditions specific to this recorded take."""
    event = _event(definition)
    if definition['family'] == 'native':
        return event
    if definition.get('gate'):
        return f"{event} {ALTERNATE_CONDITIONS[definition['gate']]}"
    if definition['slot'].startswith('Expr_'):
        return f"{event} {EXPRESSION_CONDITIONS[definition['profile']]}"
    if definition['delivery'] == 'whisper' and definition['group'] != 'ThreatWhisper':
        if definition['group'] == 'MortalFear':
            event = ('After a human attack, panic is at level 4 or at level 3 with exhaustion.'
                     if definition['source'].endswith('_3') else 'Panic is at level 3 or 4 after a human attack.')
        return f'{event} The survivor can whisper safely while sneaking.'
    return event
