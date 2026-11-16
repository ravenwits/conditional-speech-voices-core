# Core boundaries

Voice packs provide recordings, captions, voice identities and native sound mappings. Core owns event meaning, eligibility, channel choice, repetition and playback. A new voice must use the provider contract rather than add a character-name branch to Core.

## Runtime responsibilities

The game loads `42/media/lua/client`, `server` and `shared` by execution side. Keep these roots. `CSV_Client.lua` and `CSV_Server.lua` are the entry points; modules under `CSV/` own the work described below. Pure definitions and rules may live in shared code without running gameplay actions there. Client UI and audio stay in client code.

| Module | Owns | Does not own |
| --- | --- | --- |
| Observers and event modules | Evidence from game callbacks and current state | Starting dialogue directly |
| SpeechRequest | Captured event context, validity and completion in the originating observer | Queue order or audio handles |
| SpeechManager | The gameplay queue, priority, expiry and retry scheduling | Observer tables and native sound definitions |
| Selection and Channel | Recording selection, eligibility and spoken/private/silent decisions | Cancelling active sound |
| VoiceOwnership | Whether an actor may speak and which owned dialogue must stop | Recording selection or environmental audio |
| Playback | Dialogue handles, observed start, failure and completion | Treating an accepted handle as audible playback |
| Callout | Q captions, native call handles and the shout input hook | Cancelling arbitrary emitter sounds |
| NativeVoice | Provider-defined native voice installation and native pain observation | Rebuilding vanilla door/glass sound definitions |

Queue inspection and actual playback use the same ownership check. A priority change first checks every active owner, then cancels eligible dialogue. A later blocking owner cannot leave earlier dialogue partially cancelled.

NeedTiming owns ordinary speech intervals as well as need-specific timing. Channel decides whether an allowed reaction is public, private or silent; the upstream adapter does not reinterpret a silent decision afterward. Queue checks and final playback checks remain separate because an actor can die, sleep or change concealment while a request waits.

Native pain prevents Q and dialogue, including audition. An accepted Q call cancels that actor's dialogue. Normal speech waits until Q finishes. Injury fallback interrupts a tracked Q call before requesting an acute-pain line. All of these rules apply equally to official and third-party voices.

Playback sends public dialogue to the server only after observing the local emitter start. Interrupting a relayed line sends a stop for the same sequence. The server validates the speaker and routes playback to nearby listeners.

Event modules keep pending observations. SpeechManager dispatches gameplay speech. Client functions are exposed through `CSV/Core.client`.

Studio reads the exported Core recording catalogue for situation, recording type, delivery, acting and trait links. The project service compares approved takes with Core coverage groups and returns the candidate slots for each uncovered group.

## Provider and saved data

Provider tables remain provider-owned. Core builds fresh runtime voice maps after reading pack content; provider metadata cannot replace these maps. Only voices accepted by the registry enter the runtime voice list.

Experience data with the current or an absent schema version is normalized in place, preserving unrelated fields. An unknown schema version is left untouched; Core uses session-only progress instead of overwriting data from a newer build. Deferred reports use a snapshot of the normalized counters.

Combined reports are queued only after every section has been prepared. A preparation error aborts the new report and retains the previous file. The engine's writer does not expose atomic replacement or a disk-error status, so final-write failure remains a separate limitation.

## File ownership and release source

| Location | Purpose |
| --- | --- |
| Maintainer workspace `mods/` | Authoritative Core and voice-pack source |
| Public `Contents/mods/ConditionalSpeechVoicesCore/` | Core-only distributable copy |
| Core `authoring/` | Documented pack templates, contract and build tools |
| Public `tests/` and `tools/check.py` | Standalone Core verification without private audio |
| Maintainer `tests/` and `tests/support/` | Full integration suites and their reusable setup/assertions |
| Maintainer `tools/` | Current test and release commands |
| Maintainer `publishing/` | Derived release copies, backups and verification output |

The maintainer's `mods` directory is authoritative. The public Core directory and Workshop upload directories are derived copies. Exact tree synchronization removes files absent from the source and retains a backup before replacement. It never synchronizes the private workspace root into this repository.

Workshop descriptions and previews live outside the synchronized mod trees and must remain unchanged. Deployment to Steam and a Git push are separate actions from preparing these copies.
