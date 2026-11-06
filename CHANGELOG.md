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
