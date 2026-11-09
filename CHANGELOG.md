## 0.43

- Validate built voice packs with the Core registry and report loudness outliers.
- Include build identity, active voice and mod directories in diagnostics.
- Prefer shorter equally suitable reactions under pressure and group common Audition sounds together.
- Improve loot queue checks, repetition and distress continuity. Expand character creation previews and authoring checks.

## 0.42.7

- Skip full inventory classification while loot speech waits for a voice, safety or retry time. Check item ownership immediately and refresh inventory facts before selection. Remove duplicate selection in the loot observer.
- Give audited equivalent water, food and survival lines a short shared repeat window, preserving need severity and urgent injury reactions.
- Retain verified startle/injury/high-panic context for 12 seconds. Avoid an immediate return to joking or calm warnings without inventing a panic moodle. Add four aftermath scenarios and four-voice sequence tests.
- Include recent distress and explicit loot wait/cancellation reasons in diagnostic traces. Add a portable meaning/continuity test to public checks.

- Cycle through six character-creation previews for all four official voices, with five random samples followed by an injury sample. Include panic acting, preserve selected pitch, and avoid repeats within each round.
- Let each voice pack declare its preview list and optional final sample. Apply saved own-voice volume, recording balance and peak limits. Failed preview handles do not consume a sample.
- Validate preview lists in the runtime and builder. Run portable authoring-tool checks in the public test gate instead of leaving the old production-dependent builder test outside release verification.

- Reject loading-time dialogue before GameStart without allocating a sound handle, consuming cooldowns or replaying stale events after entry.
- Evaluate exported scenarios inside the report writer's per-tick budget. Session exports include observed recordings instead of rebuilding the complete voice inventory.
- Separate ungraded compatibility counts from passing scenarios in the UI. Keep selection evidence and playback status distinct in all 29 interface locales.

- Remove unused threat bookkeeping, a retired contextual random-preview function and the unused recording-level classifier. Audition keeps its current contextual preview path.
- Keep only the strict observer/installation regression test; remove the outdated duplicate that tolerated unrelated setup errors. Require every standalone development test to be listed.
- Remove the obsolete per-recording native gain hook and redundant speech checks. Keep final playback safety checks.
- Share ordinary speech timing between spoken and private reactions. Existing intervals stay unchanged.
- Retire two historical implementation tests and check localization against the current voice contract instead of archived generation plans.
- Repair malformed experience counters without dropping unrelated saved data. Preserve unknown save schemas and use session-only progress when downgrading.
- Keep provider metadata separate from Core's runtime voice registry without mutating provider-owned tables.
- Keep the previous combined report when preparation fails. Report experience from a normalized snapshot.
- Keep the current line when a replacement cannot obtain or configure a sound handle. Failed requests can retry without being mistaken for duplicates.
- Check death, sleep and concealment before committing playback history.
- Continue completion and timeout checks during crouched combat.
- Clean up failed sound setup/update handles and make cancellation idempotent.
- Tolerate missing character descriptors in native pain observation.

- Centralize Q, native injury and speech ownership. An urgent line checks all active owners before cancelling any voice.
- Native pain also stops audition playback for that character. Other actors and environmental sounds stay untouched.
- Separate speech scheduling from observer context and completion handling.
- Rename the psychology-only queue and remove the obsolete Alp callout alias and inactive native gain writer.
- Isolate development test setup. Tests no longer execute older test suites to initialize the game.
- Replace release copying with exact tree synchronization, backups and stale-file removal. Workshop descriptions and previews are preserved.

## 0.42.6

- Q calls interrupt the same character's spoken line. Ordinary dialogue waits until the call finishes. Whispered calls use the same rule; native injury reactions retain priority.
- Fix the stack overflow that left the debug menu incomplete and hid Save report. Core lists now use an iterative sort, and opening the menu no longer builds the full recording list.
- Keep Save report available before building diagnostic sections. Test menu creation after character replacement.
- Connect existing four-voice recordings to verified locked-window and vehicle-door attempts. Successful opening, cancellation, distance and repeated attempts are checked. Window reactions use wording that does not claim the object is a door.
- Add four-voice callout/respawn and access-attempt checks, plus a 12,000-entry sorting test. No new audio files.

## 0.42.5

- Added 32 recordings across Bob, Kate, Alp and Mujde: severe injury and fading strength, with two alternatives and whispered counterparts per situation.
- Critical speech uses dedicated acting and captions. Unknown causes of low health do not invent a wound.
- Unheard critical warnings can retry after their queue window. A warning that actually starts remains suppressed until worsening or sustained recovery.
- Added the optional criticalHealth voice-pack extension and included it in the pack authoring tools. Existing independent packs keep their previous fallback.
- Added four-voice selection, whisper, health-cause and deferred-warning regression checks.

## 0.42.4

- Added health warning episodes at 25 and 10 HP. Worsening health takes priority over ordinary comments and bypasses unrelated cooldowns. Stable low health does not repeatedly trigger warnings.
- Critical injury uses the existing frightened performance for every voice, even without a panic moodle. No new recordings.
- Defer routine relief and loot comments during critical health. Preserve sleep, consuming, stealth and native pain rules.
- Apply shared safety evidence to the final relief and aftermath delivery decision, including whispered relief.
- Add the observed 8 HP injury/relief sequence, escalation, recovery, stale event and four-voice regression checks. Include health in event traces.

## 0.42.3

- Commit encounter and repeat history when the engine reports playback started. Retain valid queued events for one retry after a failed start.
- Let a new native startle interrupt equal-priority speech, while preserving previews and acute pain.
- Use shared safety evidence for encounter endings and recovery. Distant unrelated zombies no longer hold recovery indefinitely; unknown evidence and active attacks remain blocked.
- Update public test fixtures and fail the observer isolation test on unexpected errors. Refresh pack authoring guidance.

# 0.42.2


Core
- Stops repeated calm warnings during the same encounter, including brief loss of sight.
- Allows a fresh response when an attack begins or panic rises substantially. Simultaneous escalation produces one response.
- Cancels stale queued warnings and preserves a failed sound's retry opportunity.
- Keeps native surprise reactions separate from earlier warnings without overlapping speech.
- Adds framework health, recording checks and diagnostic replay support prepared in 0.42.1.
- Keeps the debug menu label "Conditional Voices" in every language.

English and Turkish
- Adds the previously prepared need-severity recordings for Bob, Kate, Alp and Mujde.
- Four distinct base reactions for each of the seven needs, with contextual danger and trait rules retained.

31 offline test groups passed, including encounter sequences, package routing, native sounds, recovery, injuries and performance checks. Live verification of this release is pending.

# 0.41.2

- Route speech using the selected voice's pack, independently of interface language.
- Validate multiplayer messages against that speaker's pack and recording revision.
- Preserve the previous report while preparing a replacement; close the output in the same call that writes it.
- English and Turkish 0.41.2 use different sound script filenames so enabling both no longer removes Bob/Kate sound definitions.

Automated checks cover routing and package coexistence. Two-client multiplayer remains unverified in the game.

# 0.40.9

Initial public Core source snapshot.

- Shared speech rules, playback, settings and debug tools.
- Optional English and Turkish voice packs, distributed separately.
- Character pitch reads and edits the loaded character's value instead of adding a global offset.

Single-player beta. Multiplayer and the latest pitch save/reload flow still need live verification.
