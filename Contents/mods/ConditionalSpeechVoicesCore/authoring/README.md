# Voice framework 0.42.0

Core owns observation, priorities, interruption, repetition, stealth, playback and networking.
Packs own voice identities, localized lines, acting, audio, captions and measured calibration.
Every official voice implements contract 1 with 1,494 semantic slots and 46 native event mappings.

Bob, Kate, Alp and Mujde use the same native playback, pitch and Q caption code.
Saved built-in voices are resolved through provider-declared builtinPrefix bindings.
Old Turkish filenames remain stable through explicit aliases. Core has a compatibility
require shim for the previous callout module name; it contains no character-specific behavior.

## Create a voice pack

Install Python 3 and provide an FFmpeg executable. Neovim is used by the separate
audit tool when inspecting already-built Lua packages.

    python tools/prepare_voice_pack.py init MyVoice/pack.json --voice myvoice --language DE

Use --female for the female base. The command creates every required semantic slot.
Edit name, author, description and bank.lines in pack.json. Localize the wording for
the language and situation. Keep slot meanings and voice IDs stable. The initial
English text is a translation reference and must be reviewed for the intended language.

Record the specified audio paths using a voice actor or a generation service.
Speech should match its caption. Q uses a projecting call, whisper calls stay quiet,
effort clips are brief grunts, pain clips are involuntary reactions, and breathing
clips contain breaths. Do not read stage directions aloud. Provide mono MP3.

    python tools/prepare_voice_pack.py measure MyVoice/pack.json --ffmpeg C:/Tools/ffmpeg.exe
    python tools/build_voice_pack.py MyVoice/pack.json build/MyVoice

Measurement fills durations and per-file peak limits. The builder checks the complete
contract, voice ownership, captions, files and identity uniqueness before writing.
It emits Lua, sound scripts, audio, provider registration and mod.info. An existing
output is rejected. Failed builds clean up their temporary directory.

The generated CSV-Voice-myvoice provider is discovered by Core automatically.
Each additional voice follows the same contract. It requires a unique ID, native
prefix, preview recording and complete clips. Native pitch and volume are managed
by Core. The voice selection determines spoken language independently of UI language.

## Compatibility

Contract 1 is declared on the provider definition and all official banks.
A missing slot, native event, native recording or callout caption rejects that
provider before registration. Schema-1 third-party providers without a contract
declaration retain the earlier loading behavior. Such providers are not certified complete.

Core contains fixed discovery paths for the two published official ModIDs.
New independent packs use the CSV-Voice- prefix. Core contains no Bob/Kate/Alp/Mujde
selection branches. Calibration belongs to the provider. Existing Bob calibration
remains +1 semitone and its recorded PanicEscape gain remains 1.25.

The framework supports explicit reuse when two semantic slots fit the same recording.
Therefore all voices have equal semantic coverage, while physical file counts may differ.

## Verification

The strict source audit resolves each clip through its sound definition to a real file.
All four voices have zero missing slots, zero missing native mappings and zero file errors.
Native tests cover all four voices at -100, 0 and +100 pitch, saved Bob/Kate adoption,
Q and whisper caption matching, duplicate suppression and native pain ownership.
Existing speech, vehicle, injury, trait, stealth, routing and volume tests are retained.
The package builder has separate incomplete-input and overwrite-preservation tests.

These are automated checks with engine doubles. Live gameplay, listening quality and
two-client multiplayer verification remain necessary after installation.

## Offline recording checks

Run audit_recordings.py with the sound directory, --ffmpeg and --output.
It checks decoding, silence, decoded peak and abrupt edges. Listen to flagged takes
before deciding whether to replace them. For transcript review, pass --catalog,
--languages and --transcripts. The transcript file maps filename stems to objects
with text and language fields. Use local transcripts or manually verified text.
The tool flags suspected language mismatches and spoken stage directions when it
has those inputs. It reports the number of transcripts checked separately.

## Need tiers

New templates enable needTiers version 1. The extension provides four distinct
takes for each of the seven needs. Earlier contract-1 packs retain their
existing selection rules. Core validates every extension slot and caption.
