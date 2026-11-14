-- Recording metadata. Existing gameplay profile IDs remain unchanged.
return {
 profiles={shaken={delivery='normal',acting='shaken'},exhausted={delivery='normal',acting='exhausted'},normal={delivery='normal'},contextual={delivery='normal'},native={delivery='nonverbal'},
 whisper={delivery='whisper'},shout={delivery='shout'},nonverbal={delivery='nonverbal'},
 angry={delivery='normal',acting='angry'},breathless={delivery='normal',acting='breathless'},
 frightened={delivery='normal',acting='frightened'},sad={delivery='normal',acting='sad'},
 congested={delivery='normal',acting='congested'},slurred={delivery='normal',acting='slurred'},
 stammer={delivery='normal',acting='stammer'}},
 -- Counts are separate meanings, not interchangeable alternatives.
 distinctGroups={AmmoCount=true,KillCount=true},
 -- A generic take must remain eligible when the more specific claim is unproven.
 genericExclusions={ReloadPanic_3=true,AfterZombieShaken_2=true,InjuryAftermath_3=true,
 KillControlled_1=true,KillDesperate_4=true,KillDesperate_5=true},
 coveragePools={
  blockedWindow={'DoorBlocked_3'},
  concealedKill={'Kill_1'},concealedDistressedKill={'Kill_2'},
  quietStartleBrave={'StartleBrave_1','StartleBrave_2'},
  quietStartleNormal={'StartleNormal_1','StartleNormal_2'},
  quietStartleCowardly={'StartleCowardly_1','StartleCowardly_2'},
  quietStartleDesensitized={'StartleDesensitized_1','StartleDesensitized_2'},
  treeFelled={'ChopTree_3'},coldWet={'Wet_3'},pickup={'FoundLoot_3'}
 }
}
