# Tests

`python tools/check.py` parses every shipped Lua file and translation JSON, then runs isolated tests for missing voice packs, observer failure recovery, hook ownership, character-specific pitch and bounded API error reporting.

Use Lua 5.1. Set `LUA` to its executable if it is not on PATH. The local runner also accepts Neovim's LuaJIT through `NVIM` for development; CI runs Lua 5.1.

The missing-pack test has no game or upstream dependency. It checks that Core offers no audio candidates without a voice pack. The observer and pitch tests use small API substitutes. They do not prove that the engine called those APIs or saved a character successfully.

The private development workspace also has broader game integration scenarios and audio checks. Those are not included here because they depend on separately distributed voice banks and game/mod files. This repository does not claim to reproduce the entire private suite.

Before a release, verify pitch after save/reload and across two characters, Q captions while shouting/sneaking/using a megaphone, and native pain reactions in game. Multiplayer needs an actual two-client session.


## 0.42.6 checks

The isolated suite checks Q/speech ownership in both directions and iterative sorting of 12,000 entries. The full development suite also uses all four official voice banks, new-character menu creation and confirmed/cancelled/opened access attempts. These are not live audio or multiplayer validation.

In game: start a spoken line, press Q, then trigger a reaction while Q is playing. Repeat while sneaking. After death, create a new character and check Audition, Scenario tests and Save report. Try a locked building door, a struggling window and a locked vehicle door, then repeat with the matching key or a successful opening. Verify surrounding door/glass sounds remain audible.

## 0.42.7 checks

The development integration suite reproduces a FoundLoot request during loading, checks that it creates no handle or cooldown, then enters through the registered GameStart callback. Report tests verify that scheduling performs zero scenario evaluations, evaluation is bounded per writer tick, and final graded/ungraded counts match the synchronous reference. UI tests check the new evidence labels in all 29 locales and separate summary rows. These checks do not measure game-frame timing.

Live evidence from the November 9 Alp session showed eight Q calls entering and finishing in the engine, including one whispered call. Four Q calls interrupted ongoing dialogue. No Q hook change was needed for that report. Startup suppression and the reduced report preparation cost still need a restarted game session.

The public tests also check atomic interruption, native pain during audition, isolation between actors, a third-party voice identity, context restoration after a failed dispatch and rejection of orphaned observer requests. See [Core boundaries](architecture.md).

The development runner now declares all 79 suites explicitly and executes each in a fresh process. Setup helpers contain game doubles and provider loading, not older test assertions. Historical assumptions about male-only ammunition voices and old preview identities were replaced with checks against the current supported behavior.

Package tests cover removed files, unchanged trees, protected sibling files, path escape, linked input rejection, copy failure and install rollback. These checks do not establish live audio quality or multiplayer correctness.

The 0.42.7 playback tests also cover death/sleep between queueing and startup, unavailable emitters, setup failure after handle allocation, same-packet retry, repeated cancellation, completion while crouched under attack, startup-query errors and active-handle update failure. These tests use explicit failure injection; passing them is not evidence that the latest build ran in the game.

The public suite now has 17 isolated test groups. Additional checks cover malformed and unknown experience schemas, provider-owned table isolation, report preparation failure followed by a successful retry, and malformed or spoofed server messages. The development suite also builds a report with incomplete saved counters. These checks do not simulate an operating-system failure during the final file write or prove an actual save/reload in the engine.

Two historical development suites were retired: a test of a constant-return native gain helper, and checks tied to an old Alp recording batch. The native framework tests still verify the volumes in generated sound definitions for all four voices. Localization coverage now reads the current voice contract, not archived production plans or an old fixed clip count. Queue retry boundaries and silent-channel outcomes remain tested. Test count is not a coverage measure.

A third, outdated copy of the observer/installation test was removed from the development suite. The public `tests/foundation.lua` retains all of its assertions, supplies every current observer and rejects unexpected observer errors. The release gate always runs this public suite. Audition context tests now call the same context-preview entry point as the UI, rather than an unused random-preview function. Shared development assertions belong in `tests/support`; the runner rejects unlisted standalone test files.
