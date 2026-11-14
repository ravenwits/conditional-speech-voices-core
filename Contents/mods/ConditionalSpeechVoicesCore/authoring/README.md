# Conditional Speech Voices - Studio

Local tools for preparing, reviewing and building voice packs for Conditional Voices.

Core owns observation, priorities, interruption, repetition, stealth, playback and networking.
Packs own voice identities, localized lines, acting, audio, captions and measured calibration.
Every official voice implements contract 1. The bundled voice-contract-v1.json defines the current semantic slots and native event mappings.

Bob, Kate, Alp and Mujde use the same native playback, pitch and Q caption code.
Saved built-in voices are resolved through provider-declared builtinPrefix bindings.
Old Turkish filenames remain stable through explicit aliases. The obsolete callout module shim has been removed. Use the documented provider interface.

## Prepare a voice

You can record yourself, work with a voice actor, or use a service of your choice.
No service, account, or API key is required. The tools run locally and do not upload
recordings. Python 3.11 or newer and FFmpeg are required. Final validation also uses
Lua 5.1, LuaJIT, or Neovim. Run the commands below from this authoring directory.

## Command line

Run these commands from the `authoring` directory. To open Studio from a terminal, run
`python -B tools/launch_studio.py`. If FFmpeg is outside PATH, pass
`--ffmpeg "C:/Tools/ffmpeg.exe"`. Use `--project "path/to/project.json"` to open an existing project.

For a command-line workflow, initialize a project and import your audio with the commands below.

```text
python tools/prepare_voice_pack.py init MyVoice/pack.json --voice myvoice --language TR
python tools/prepare_voice_pack.py edit MyVoice/pack.json --ffmpeg C:/Tools/ffmpeg.exe
```

Add `--female` for the female base. Voice IDs must be unique and remain stable.
The full project uses the bundled voice template. To try a voice first, add
`--trial` to the init command. This optional subset contains four dialogue lines,
three whispers, three calls, two breaths, three effort sounds, and three pain
reactions. The editor supports either scope; 18 recordings is not a pack limit.
It binds only to 127.0.0.1. Keep the terminal open while editing; Ctrl+C closes it.

English and Turkish wording is supplied. For another language, the English text
is a meaning reference, not a finished translation. Localize it before recording.
To reuse wording from a project in the same language, add `--texts OtherVoice/pack.json`
to `init`. This copies captions, not voice identities or audio. A separate catalog
can also contain `{"language":"DE","lines":{"Explore_1":"..."}}`.

### Review recordings

The main page always shows recordings. Click the project name under the title to edit metadata or create another project. **Prepare pack** opens a separate dialog.

Select a situation in the compact list, then choose a variation to listen, approve it, or mark it for another take.
Text and read-only acting guidance are under **Text & recording guidance**. Use the filters to find
missing recordings or takes needing another listen. Categories, situations and character events come from the read-only Core catalogue. **Game conditions** shows Core source references, moodle levels and shared checks. These references are not proof of live playback. Studio rejects edits to Core slots and rule mappings.

The sidebar renders 50 situations per page; expand a situation to see its variations. Search covers all slots. Read-only guidance helps the performer and never changes gameplay behavior. Import a local audio file;
FFmpeg converts it to mono MP3 without applying
loudness normalization. The tool assigns the filename. Files must be at most 16 MiB
and 30 seconds long. A failed conversion leaves the previous recording intact.

Listen, then choose **Approve** or **Needs a retake**. Changes are saved in the
project JSON, not just browser storage. Changing a caption, acting note, level or
recording invalidates its previous approval. Only one audio player plays at a time.
Browser playback uses the file's original level and does not reproduce combat,
world distance, in-game gain or pitch. A listening approval is not a gameplay test.

Under **Prepare pack**, use **Check audio levels** to find loudness outliers in the recordings already imported. Missing slots remain missing; partial measurements do not allow an incomplete package to build. Measurements are reused when
file content and volume are unchanged. Suspicious takes require listening; the
measurements do not establish natural acting, correct language or pronunciation.
Captions must match what is spoken. Never read acting directions aloud.
The game hides this mod's automatic reaction text and custom call text by default.
Players can enable **Show reaction text** in Mod Options. This controls display,
not audio or zombie hearing. Manual chat and other mods' text are left alone.
Keep the words in the pack even if you play without captions.

The editor reconnects after its server restarts on the same port. Reload the page to load external changes. Unsaved edits require confirmation. If the editor is stopped, start it again first.

### Expand or update a project

**Compare with Core** lists added, removed and changed reference slots. **Apply current schema** fills the full template while retaining existing captions,
recordings, display name, calibration and reviews. A changed meaning reference
requires another review. The previous manifest is saved as `.before-update.json`.
Removed slots leave the active manifest; their files remain available for recovery.
Custom alias changes require manual migration instead of silent replacement.

The equivalent commands are:

```text
python tools/prepare_voice_pack.py promote MyVoice/pack.json
python tools/prepare_voice_pack.py promote MyVoice/pack.json --apply
python tools/prepare_voice_pack.py update MyVoice/pack.json
python tools/prepare_voice_pack.py update MyVoice/pack.json --apply
```

Install the updated authoring tools before comparing against a newer Core. Compare
is read-only. An update does not overwrite your wording with a new translation.

### Record yourself or hand off remaining work

**Export recording list** produces a JSON list containing only missing
recordings and takes marked Needs a retake. Each job includes its stable slot, caption,
language and acting direction. Existing recordings awaiting review are not requested
again. Give this list to a voice actor, use it while recording yourself, or process
it with your preferred tools. Import each result in the editor or from the CLI:

```text
python tools/prepare_voice_pack.py jobs MyVoice/pack.json
python tools/prepare_voice_pack.py import MyVoice/pack.json Explore_1 takes/explore.wav --ffmpeg C:/Tools/ffmpeg.exe
python tools/prepare_voice_pack.py import-folder MyVoice/pack.json takes --ffmpeg C:/Tools/ffmpeg.exe
```

For a batch, name each file after its slot, such as `Explore_1.wav` or
`myvoice_Explore_1.mp3`. Use **Import > Choose audio files** in the editor or
`import-folder`. Existing takes are preserved unless marked Needs a retake. An
interrupted batch can be resumed by selecting the same files again. Unknown files
are reported, and two inputs for the same slot are rejected before importing.

For optional automated production, supply your own executable. The editor cannot
start paid jobs. From the command line:

```text
python tools/prepare_voice_pack.py run MyVoice/pack.json --budget 2000 --rate 1 --max-jobs 18 --ffmpeg C:/Tools/ffmpeg.exe -- python my_recorder.py
```

The worker receives two extra arguments: an absolute job JSON path and an output
MP3 path. It must write a valid recording at that path and exit zero. No shell is
used. Authenticate outside the project, such as through an environment variable.
Never put credentials in captions, metadata, the manifest or the worker's arguments.
The project tool does not require or store a service-specific key.

`--rate` is the estimated units per caption and direction character. `--budget` is
the cumulative project limit, not a new allowance on each run. The tool reserves
the estimate before each job and stops before exceeding that limit. The worker
must honor the job's `maxUnits` limit or fail without spending. Actual billing is
controlled by the external tool; this is not a universal billing guarantee.
Nonverbal recordings may use a different billing method, so set the rate conservatively.

Completed jobs are imported once and wait for listening approval. If a job fails
or is interrupted, its reservation remains in `.work.json`; the tool does not retry
it automatically. Check the saved `work/` output first and import a usable take.
Only one worker may run per project. After a hard crash, remove `.worker.lock` only
after confirming that worker has stopped. Avoid editing the project during imports;
an import detects concurrent manifest changes and asks you to retry.
If a retry is necessary, explicitly acknowledge the job using its ID:

```text
python tools/prepare_voice_pack.py resolve MyVoice/pack.json JOB_ID
```

Acknowledging a failed job does not refund its reserved units. Run the worker again
to continue only remaining work. You can always stop using the worker and import
your own recordings instead.

### Build the distributable pack

**Build package** requires a full project with every recording approved. It measures
audio, checks required slots and metadata, invokes the actual Core registry, and
writes `dist/<mod-id>-<revision>`. An existing output is never overwritten; change
the pack revision before preparing a new release.

```text
python tools/prepare_voice_pack.py package MyVoice/pack.json build/MyVoice-1.0.0 --ffmpeg C:/Tools/ffmpeg.exe
```

Only game metadata, generated Lua, sound definitions, referenced MP3s and an optional
PNG poster enter the output. Project reviews, job history, working files and credentials
are not copied. Review public captions and metadata before publishing. Do not upload
the project directory. The output is a mod folder; place it under a Workshop upload
project's `Contents/mods/` directory and supply that project's cover and description.

A generated `CSV-Voice-` provider is discovered automatically. Spoken language follows
the selected voice, independently of interface language. Core handles priorities,
stealth, interruption, repetition, native calls, pain ownership, pitch and volume.
A successful build proves registration and file checks, not in-game or multiplayer audio.

Voices may declare a unique `previewLines` playlist and a `previewLast` entry. Character
creation shuffles the playlist without repetition within a round. Existing providers
with only `preview` retain a single sample. Invalid playlists reject the provider.

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

## Critical health recordings

New templates declare `criticalHealth=1`. This optional extension requires eight captioned slots: two CriticalWound lines, two CriticalFading lines and their whispered counterparts. Use restrained pain for wounds and weak, interrupted breathing for fading strength. Do not claim bleeding, bites or infection without matching evidence. Existing packs without the extension retain the older injury recordings.

Measurement also writes a .loudness.json report. It does not normalize acting or alter recordings. Before distributing a built pack, run tools/verify_runtime.py with the pack folder and installed Core folder. This invokes the actual Core registry, not a second semantic validator.


## Tests

```text
python -B -m unittest discover -s tests -v
```

The authoring tests cover review invalidation, trial promotion, template updates,
recording ownership, local editor access, stale writes, external worker recovery,
budget reservations and distribution boundaries. Set `VOICE_TEST_FFMPEG` to an
FFmpeg executable to also exercise real import, measurement and packaging. Those
tests use a generated test tone, not a spoken recording or a paid service.

## Interface source

The prebuilt interface uses React, Coss UI and local fonts. The source and build commands are in the repository’s `studio` directory. Users do not need Node or internet access to open the editor. After changing Core rules, maintainers must run `tools/export_studio_schema.py` with Neovim available before distributing Studio. The server checks that the exported catalogue matches its Core source files.

### Save volume and pitch changes

Open **Edit audio** on a recorded line. Adjust volume or pitch, then choose **Apply to recording**. This saves a take used by both Studio and the built pack. Changes start from a preserved original, never the previous edited take. **Restore original** recovers the original file. Every applied change needs listening approval again.

Pitch processing requires an FFmpeg build with the `rubberband` filter. It preserves speech duration. Excessive gain is rejected before saving. The volume setting is relative to this recording, separate from in-game volume controls. Very short clips may have no integrated loudness measurement; they are reported as unmeasurable rather than invalidating the project.

Recording guidance explains how to perform a line. It uses the supplied production direction when available, otherwise Core delivery and severity. It is read-only. Legacy notes remain in project files.

The project name opens a searchable project selector. Use the settings button beside a project to edit its details. Languages are searchable when creating a project. The player supports pause, stop, seeking and preview speed; preview speed never changes files. Check and build actions stay in the Prepare pack footer. A successful build includes instructions for installing the generated folder in Zomboid/mods.
