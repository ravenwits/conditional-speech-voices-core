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
