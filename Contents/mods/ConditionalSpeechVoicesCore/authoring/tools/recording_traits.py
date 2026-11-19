"""Describe the trait checks that can select or replace a recording in Core."""

# These groups have a single trait-gated route. Trait names come from CSV/Traits.lua.
REQUIRED_GROUPS = {
    'Agoraphobic', 'Claustrophobic', 'BloodAversion', 'BloodOnSkin', 'NicotineNeed',
    'StartleBrave', 'StartleDesensitized', 'TraitDriver', 'TraitVigilant',
    'TraitHunger', 'TraitThirst', 'TraitLoad', 'TraitCold', 'TraitNausea',
    'TraitFull', 'TraitSight', 'TraitRest', 'TraitWound', 'TraitFumble',
    'TraitReading', 'TraitFall', 'TraitScratch', 'TraitIlliterate', 'TraitReluctant',
    'KillDark', 'DryCoping',
}

# A trait can select a reaction even when a second route also reaches it.
GROUP_RULES = {
    'ExhaustedCoping': ('conditional', 'These survivors can use this take at High Exertion (level 2). At levels 3 and 4, any survivor can use it.'),
    'StartleCowardly': ('conditional', 'Cowardly survivors use this reaction. Severe panic can also trigger it for survivors without a startle trait.'),
    'TraitStudy': ('conditional', 'Slow Learner unlocks this line during recipe research. Any survivor can also use it while reading a skill book when a reading take is unavailable.'),
    'AfterHumanShaken': ('conditional', 'Cowardly survivors use this reaction when panicked. Inexperience or recent distress can bring it out in others.'),
    'AfterZombieShaken': ('conditional', 'Cowardly survivors use this reaction when panicked. Inexperience or distress can bring it out in others.'),
    'KillUneasy': ('conditional', 'Cowardly survivors can use this when panicked, as can survivors with Fear of Blood when bleeding. Other survivors can also feel uneasy after a kill.'),
    'KillControlled': ('conditional', 'Desensitized survivors can use this reaction, as can Brave survivors near zombies. Experience can also lead to this take.'),
    'KillCount': ('conditional', 'Desensitized survivors can count a kill milestone before reaching practiced status. Practiced survivors can count it with any trait.'),
    'PursuitSteady': ('conditional', 'Brave or Desensitized survivors can stay steady during a pursuit even with little experience, provided panic is low and distress has passed.'),
    'PursuitUneasy': ('conditional', 'Cowardly survivors use this reaction when panicked. Inexperienced or recently distressed survivors can also use it.'),
    'ReloadSteady': ('preferred', 'At moderate panic, Brave or Desensitized survivors favor a steady reload. Any survivor can use it at lower panic.'),
}


def alternatives(names):
    if len(names) <= 2:
        return ' or '.join(names)
    return ', '.join(names[:-1]) + ', or ' + names[-1]


def rule(kind, traits, description):
    return dict(kind=kind, traits=sorted(set(traits)), description=description)


def recording_trait_rule(row, trait_links, controlled_traits, controlled_groups, fallback_slots):
    """Use Core's explicit group, delivery and alternate metadata for this take."""
    group, slot = row['group'], row['slot']
    names = sorted(trait_links.get(group, {}).values())
    if row.get('traitControlled'):
        return rule('required', controlled_traits, 'Only Brave or Desensitized survivors use this take. The game tries it before the ordinary reaction.')
    if group in controlled_groups:
        if group == 'MortalFear':
            description = 'Any survivor can use this line. Brave or Desensitized survivors try a controlled take first, then a short threat warning. They use this line if neither is available.'
        else:
            description = 'Any survivor can use this line. Brave or Desensitized survivors use it if no controlled recording is available.'
        return rule('conditional', controlled_traits, description)
    source = slot.removeprefix('Whisper_')
    if source in fallback_slots.values():
        if source == fallback_slots['safePanic']:
            description = 'Any survivor can use this line. Brave or Desensitized survivors also favor it to steady themselves during severe panic in safety.'
        else:
            description = 'Any survivor can use this line. Brave or Desensitized survivors also use it when facing danger if a dedicated controlled take is unavailable.'
        return rule('preferred', controlled_traits, description)
    if group in ('GunJammed', 'OutOfAmmo'):
        if row['profile'] == 'frightened':
            return rule('excluded', names, 'Only survivors without Brave or Desensitized use this frightened take.')
        return rule('conditional', names, 'Any survivor can use this take. Brave and Desensitized survivors skip the frightened delivery, even under attack.')
    if group in REQUIRED_GROUPS:
        return rule('required', names, 'Only survivors with ' + alternatives(names) + ' can use this take.')
    if group in GROUP_RULES:
        kind, description = GROUP_RULES[group]
        return rule(kind, names, description)
    if group == 'StartleNormal':
        traits = [*controlled_traits, *trait_links['StartleCowardly'].values()]
        return rule('excluded', traits, 'Only survivors without Brave, Cowardly or Desensitized use this startle reaction, and only below severe panic.')
    if group in ('AfterHumanSteady', 'AfterZombieSteady'):
        return rule('conditional', trait_links['AfterHumanShaken'].values(), 'Practiced survivors can use this reaction. Cowardly survivors switch to a shaken reaction when panicked.')
    if group == 'ReloadPanic':
        return rule('conditional', controlled_traits, 'At moderate panic, Brave or Desensitized survivors stay steady. Severe panic can still trigger this take for them.')
    if group in ('ContextPanicEscape', 'Panic'):
        return rule('conditional', controlled_traits, 'Any survivor can use this reaction. During severe panic, Brave or Desensitized survivors can switch to a steadier line when safe or facing a threat.')
    if names:
        raise ValueError('Missing Studio trait rule for ' + group)
    return None
