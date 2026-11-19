# Core boundaries

Voice packs provide recordings, captions, voice identities and native sound mappings. Optional dialogue takes in Core are tied to a source recording. Selection can substitute an available alternate after the source's event and delivery rules pass. Native alternatives enter the existing event pools through the pack manifest. Core owns event meaning, eligibility, channel choice, repetition and playback. A new voice must use the provider contract rather than add a character-name branch to Core.

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

The local survivor's body-damage snapshot drives optional wound-location recordings. Core selects a location when it finds a single matching body part. Active bleeding, an identified cut and blood on the skin are separate observations. A skin stain carries no donor identity. Recorded takes and captions use the existing pack and multiplayer playback paths.

Native pain prevents Q and dialogue, including audition. An accepted Q call cancels that actor's dialogue. Normal speech waits until Q finishes. Injury fallback interrupts a tracked Q call before requesting an acute-pain line. All of these rules apply equally to official and third-party voices.

The optional Shelter Thump takes react to nearby door and window impacts while the survivor is inside the same building. The observer matches the zombie's impact world sound to the opening. In multiplayer, the server forwards confirmed impacts near eligible listeners, and the client can also observe impacts simulated locally. Both routes use the same opening coordinates and orientation to suppress repeated hits. Twelve seconds without a hit starts a new episode. The reaction enters the existing outcome queue and uses the normal speech relay.

PlaybackPacket builds the pack identity and manages the local sequence for public speech, private thoughts and audition. For relay, the server constructs the outgoing packet using the authenticated speaker after validating the incoming request.

Playback sends public dialogue to the server only after observing the local emitter start. Interrupting a relayed line sends a stop for the same sequence. The server validates the speaker and routes playback to nearby listeners.

Event modules keep pending observations. SpeechManager dispatches gameplay speech. Client functions are exposed through `CSV/Core.client`.

Studio reads the exported Core recording catalogue for situation, recording type, delivery, acting and trait links. Core’s recording guidance provides one performance direction and its matching audio tag, where needed, for each catalogue slot. Studio displays that direction and shares it with the CLI recording jobs and ElevenLabs prompt builder. Captions and reviews still belong to each voice project. Studio and the situations-v1 pack builder evaluate required situation pools and native events with the same catalogue coverage rules. Packaging uses the same set of approved takes to check readiness and choose audio. After a review, Studio computes coverage and selects the next matching take from the same confirmed project state. It reloads the project when an older workbench returns an incomplete review response. The voice project updates the active take and clears its previous approval, duration and measurements for both imports and edits. Alcohol, cold symptoms and whispered takes are optional for pack coverage. Native sounds use their stock events when the pack omits the optional recording. Core lists retired slots separately so Studio omits them from the catalogue and package coverage. The registry still recognizes their IDs in older packs. Studio keeps the recording files and backs up the manifest when opening a project with retired slots.

Core selects trait reactions after the event has been verified. For optional specialist takes, selection checks the survivor’s trait and the pack’s recorded audio. A harvest, landed fish or supported craft can trigger a trait-only line after the action yields the expected item. In multiplayer the server observes the completed action and sends the result to its actor. The receiving client matches the character by online ID and uses the normal trait, audio and speech checks. The controlled takes for Brave and Desensitized use the same situation and delivery rules as the original takes. The catalogue exports acting independently from each recording’s trait rule. Studio project rows pair that rule with a description of the in-game trigger and a performance direction for the selected recording. The trait filter includes requirements, priorities, exclusions and other conditional routes. The controlled takes are optional for pack coverage, and Core can use existing recordings when a pack has no trait-specific audio.

The optional ElevenLabs connection belongs to the loopback workbench. For transcription, it snapshots the selected dialogue take and project language, then sends the audio to Scribe outside the project lock. The returned text stays in the caption editor until the user saves it. A project stores its selected provider voice ID under authoring, while the local process reads the key from the Git-ignored .env.local file or its environment. Account credit and voice lookups run independently of local project edits. The workbench builds single-slot Eleven v4 dialogue requests using the saved caption and Core tags. Native vocal reactions send an editable script with a short vocal sound to Eleven v4 using the project voice and share the same preview, history and explicit take acceptance. Studio stores inline audio tags in the recording script under authoring and strips them from the game caption. An explicit script controls tag placement. A recording without a custom script uses its Core tag. A preview lives in memory until a new attempt or server restart. The workbench checks the project, slot, prompt and recording before accepting a preview through the audio import path. Replaced audio is archived locally until review approval. The workbench saves each paid preview attempt in the project’s local request history before sending it to ElevenLabs.

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

Studio's recording view and Gemini both read the same recording brief for the selected slot. Every Generate and Retry request identifies Project Zomboid as a zombie-apocalypse survival game. The writer can mention a threat when the scene establishes it. The server sends this setting and the writing instructions alongside the scene, with the voice base, profanity flag, five-second limit and requested draft count (1–3). Imports and edits allow up to 20 seconds. The pack builder enforces the five-second clip limit. Core caps its speech and callout playback at five seconds. Studio stores draft options per project in the browser. The server checks model access before saving the Gemini key in the local provider settings file. Draft requests use the locally saved model. Gemini 3.5 Flash-Lite is the default. The server tracks Studio requests and the input tokens Google reports in its responses until the server restarts or the key changes. Google AI Studio reports project-level quota. Studio keeps the last 50 Gemini generation outcomes in a local history file next to each project manifest. Selecting a draft fills the caption editor, and the ordinary save action writes the caption.
