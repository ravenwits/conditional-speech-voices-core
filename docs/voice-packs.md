# Adding a voice pack

Core 0.41.0 supports independently authored voice packs. No Core patch is required. Existing English and Turkish packs retain their IDs and save compatibility.

Create a B42 mod requiring `Conditional-Speech-Voices-Core`. Give it a unique ModID starting with `CSV-Voice-`, followed by letters, digits, underscores or hyphens. This opt-in prefix avoids probing every unrelated installed mod. Put a provider at `42/media/lua/shared/CSV_Packs/<ModID>.lua`. Core requires this module explicitly for each activated mod using that prefix, once during loading. Return a schema-1 definition with a bank and a voices array. Do not require CSV/Core or CSV/Pack from your provider. Registration after Core loads is rejected; restart after changing packs.

See `examples/ExampleVoice/42/media/lua/shared/CSV_Packs/CSV-Voice-Example.lua`. The example has no audio and is not a finished voice pack. Replace its sample bank module with your own recordings and metadata.

Each voice has a globally unique lowercase `id`, display `name`, unique `prefix` such as `VoiceCSVMyVoiceP`, `base` of VoiceMale or VoiceFemale, and a `preview` line ID. Optional `styleName` preserves old character-creation identifiers. Never reuse another pack's voice ID or prefix. Native prefixes and saved `csvVoice` IDs must remain stable across updates. Invalid or duplicate definitions are rejected as a whole and logged.

The bank follows the existing schema-1 recording contract:

- `id`, `language`, `revision`; `data.groups` maps existing condition names to ordered `{id,text}` lines. `data.clips` maps `<voice>_<line>` to playback metadata including `sound` and `duration`.
- `extras.catalog`, `whispers.catalog`, `expressions.catalog`, `expressions.bySource`, `profanity.ids`, and `peaklimits` describe semantic alternatives, delivery relationships, profanity and measured per-file headroom. Catalogs are immutable after loading.
- `lines` maps line IDs to the spoken captions. `native` contains `suffixes`, `replacements` and `pain`. `replacements.ShoutHey` and `WhisperHey` are caption-matched callout pools.
- `data.contextLines` may omit `voice` to apply to every voice in that bank. Set it only for an intentional voice-specific rule.

Use the established semantic line IDs for existing gameplay situations, and use unique sound event names `CSV_<voice>_<line>` and the matching self-playback definitions. Supply scripts and audio in your own package. Core does not synthesize recordings. An absent recording must remain absent rather than point at another speaker. Shared line IDs mean shared semantics, not shared audio. The registry adds voices to existing situations; it does not register arbitrary new gameplay observers.

Do not edit provider tables after load. Core discovers providers in sorted ModID order and rejects duplicate voice identities. Shared semantic catalogs use the first definition for an existing ID; avoid changing the meaning of an existing ID. Clip lookup and captions use the selected voice's bank.

Test alone, with English, with Turkish, and without any voice pack. Check character creation, pitch, save/reload, ordinary speech, stealth, injury and both Q and radial shout. The current automated tests do not establish multiplayer compatibility.

## Permission for independent packs

ravenwits permits anyone to create and distribute independently authored voice packs that depend on the unmodified Core and use this interface. The sample provider in `examples/` may be copied and adapted for that purpose. This does not grant redistribution or modification rights to Core, existing recordings, game assets or other mods. Their existing licenses and permissions still apply.
