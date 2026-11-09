# Adding a voice pack

Start with the [current authoring guide](../Contents/mods/ConditionalSpeechVoicesCore/authoring/README.md) and its `prepare_voice_pack.py` and `build_voice_pack.py` tools. Run commands from that authoring directory. The complete contract is the authority for required slots, rather than counts copied into documentation. The small example below explains registration only; it is not a complete pack.

Core 0.42.3 supports independently authored voice packs. No Core patch is required. Existing English and Turkish packs retain their IDs and save compatibility.

Create a B42 mod requiring `Conditional-Speech-Voices-Core`. Give it a unique ModID starting with `CSV-Voice-`, followed by letters, digits, underscores or hyphens. This opt-in prefix avoids probing every unrelated installed mod. Put a provider at `42/media/lua/shared/CSV_Packs/<ModID>.lua`. Core requires this module explicitly for each activated mod using that prefix, once during loading. Return a schema-1 definition with a bank and a voices array. Do not require CSV/Core or CSV/Pack from your provider. Registration after Core loads is rejected; restart after changing packs.

See `examples/ExampleVoice/42/media/lua/shared/CSV_Packs/CSV-Voice-Example.lua`. The example has no audio and is not a finished voice pack. Replace its sample bank module with your own recordings and metadata.

Each voice has a globally unique lowercase `id`, display `name`, unique `prefix` such as `VoiceCSVMyVoiceP`, `base` of VoiceMale or VoiceFemale, and a `preview` line ID. Optional `styleName` preserves old character-creation identifiers. Never reuse another pack's voice ID or prefix. Native prefixes and saved `csvVoice` IDs must remain stable across updates. Invalid or duplicate definitions are rejected as a whole and logged.

Optional `previewLines` declares a nonempty list of unique recordings owned by that voice. Core shuffles them without repetition within a round. Optional `previewLast` reserves one member for the final draw. Without a list, the existing `preview` field supplies a single sample. The builder and runtime reject missing or duplicate playlist entries. Previews use the own-voice volume setting, recording balance and peak limit. They do not simulate world distance or nearby danger.

The bank follows the existing schema-1 recording contract:

- `id`, `language`, `revision`; `data.groups` maps existing condition names to ordered `{id,text}` lines. `data.clips` maps `<voice>_<line>` to playback metadata including `sound` and `duration`.
- `extras.catalog`, `whispers.catalog`, `expressions.catalog`, `expressions.bySource`, `profanity.ids`, and `peaklimits` describe semantic alternatives, delivery relationships, profanity and measured per-file headroom. Catalogs are immutable after loading.
- `lines` maps line IDs to the spoken captions. `native` contains `suffixes`, `replacements` and `pain`. `replacements.ShoutHey` and `WhisperHey` are caption-matched callout pools.
- `data.contextLines` may omit `voice` to apply to every voice in that bank. Set it only for an intentional voice-specific rule.

Use the established semantic line IDs for existing gameplay situations, and use unique sound event names `CSV_<voice>_<line>` and the matching self-playback definitions. Supply scripts and audio in your own package. Every media file path must be unique across packs, including the sound script filename. Use a pack-specific name such as `media/scripts/CSV_MyPack_Sounds.txt`. The game overlays matching paths; different sound event names inside the same script filename do not prevent one pack replacing another. Core does not synthesize recordings. An absent recording must remain absent rather than point at another speaker. Shared line IDs mean shared semantics, not shared audio. The registry adds voices to existing situations; it does not register arbitrary new gameplay observers.

Do not edit provider tables after load. Core discovers providers in sorted ModID order and rejects duplicate voice identities. Core owns shared slot semantics. Conflicting meanings are rejected at registration; never rely on load order to replace a slot. Clip lookup and captions use the selected voice's bank.

Test alone, with English, with Turkish, and without any voice pack. Check character creation, pitch, save/reload, ordinary speech, stealth, injury and both Q and radial shout. The current automated tests do not establish multiplayer compatibility.

## Multiplayer bank selection

The speaker's selected voice owns the recording bank. Speech packets carry that bank's ID and revision, even when several packs are enabled. The listener's game language does not translate or replace the speaker's voice. Local prediction and the server echo share an actor and sequence ID to prevent duplicate playback.

The server and each listener need the speaker's voice pack. A missing pack, mismatched recording revision or unavailable line is rejected. Core does not substitute another language or speaker. A pack update that changes recording identities or timing must update its bank revision; a packaging-only rename can retain the revision. Keep all server-required packs installed and enabled for multiplayer tests.

The routing tests cover bank selection, malformed requests, missing packs and duplicate suppression with simulated engine services. A dedicated server and two real clients are still required to verify synchronization and audibility.

## Permission for independent packs

ravenwits permits anyone to create and distribute independently authored voice packs that depend on the unmodified Core and use this interface. The sample provider in `examples/` may be copied and adapted for that purpose. This does not grant redistribution or modification rights to Core, existing recordings, game assets or other mods. Their existing licenses and permissions still apply.
