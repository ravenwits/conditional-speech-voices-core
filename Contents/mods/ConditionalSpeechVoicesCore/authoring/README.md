# Voice pack tools

These Python tools run Studio's local server, process audio, and build voice packs. The React interface source is in the repository's `studio` directory. Both workflows use the same project files and validation code.

For a browser workflow, read the [Studio creator guide](../../../../studio/CREATOR-GUIDE.md). These tools belong in the Git repository and are excluded from Workshop releases.

## Requirements

Use Python 3.11 or newer, FFmpeg, and Lua 5.1, LuaJIT, or Neovim. Pitch and speed edits need FFmpeg's `rubberband` filter. Artwork needs its `drawtext` filter. Put executables on PATH or pass their paths. `LUA` and `NVIM` can select the runtime used for pack validation.

The tools require no recording service or API key. Studio runs locally and does not upload audio. The launcher can fetch Core updates from the official Git repository when the checkout is clean.

## Command line

Run these commands from this `authoring` directory. Linux and macOS examples use `python3`. On Windows, use `python` or `py -3` instead.

To start Studio, run:

```sh
python3 -B tools/launch_studio.py
```

Add `--project /path/to/project.json` to open an existing project. Add `--ffmpeg /path/to/ffmpeg` if FFmpeg is outside PATH. Windows also has `Start Studio.cmd`; Linux and macOS use `sh "Start Studio.sh"`. Both launchers accept the same arguments.

### Create a project

```sh
python3 -B tools/prepare_voice_pack.py init MyVoice/pack.json --voice myvoice --language TR
python3 -B tools/prepare_voice_pack.py edit MyVoice/pack.json
```

Use a unique lowercase voice ID. Add `--female` for a female character base or `--trial` for an 18-recording listening sample. Full scope is the default. English and Turkish text is supplied; other languages start with English meaning references.

To copy captions from a project in the same language, add `--texts OtherVoice/pack.json` to `init`. This does not copy audio or voice identities.

### Import and measure audio

```sh
python3 -B tools/prepare_voice_pack.py import MyVoice/pack.json Explore_1 takes/explore.wav
python3 -B tools/prepare_voice_pack.py import-folder MyVoice/pack.json takes
python3 -B tools/prepare_voice_pack.py measure MyVoice/pack.json --ffmpeg ffmpeg
```

Batch filenames use the slot ID, optionally preceded by the voice ID. For example, `Explore_1.wav` and `myvoice_Explore_1.mp3` map to the same slot. Missing slots and rejected takes can be replaced. Other takes are preserved. Unknown filenames are reported. Duplicate inputs for one slot are rejected.

Imports are limited to 16 MiB and 20 seconds. Studio converts uploads to mono MP3 at 96 kbps. Captions are limited to 240 characters. Failed imports preserve the previous file.

Measurement writes a `.loudness.json` report and does not normalize audio. Short clips can have no integrated loudness measurement. Listen to flagged recordings before approving them in Studio.

### Export unfinished recording work

```sh
python3 -B tools/prepare_voice_pack.py jobs MyVoice/pack.json
```

This writes a `.jobs.json` file with missing and rejected takes. Each entry contains its slot, caption, language, and recording guidance. Existing recordings that need listening are not requested again. Studio's **Recording list** downloads every slot with its status instead.

### Expand or update requirements

```sh
python3 -B tools/prepare_voice_pack.py promote MyVoice/pack.json
python3 -B tools/prepare_voice_pack.py promote MyVoice/pack.json --apply
python3 -B tools/prepare_voice_pack.py update MyVoice/pack.json
python3 -B tools/prepare_voice_pack.py update MyVoice/pack.json --apply
```

Without `--apply`, these commands report differences without changing the project. Promotion expands a listening sample. Update reconciles an existing full project with the installed Core catalogue. Text and recordings are preserved, and the previous manifest is backed up. Changed meanings need another review. Removed slots leave the active manifest, but their audio files remain on disk.

Studio updates requirements automatically when opening a project. Update the repository before checking for new Core requirements. A separate Steam update does not update these files.

### Build a mod directory

```sh
python3 -B tools/prepare_voice_pack.py package MyVoice/pack.json build/MyVoice-1.0.0
```

The command requires a full project with one approved take for each required meaning and native sound event. Extra variations, whisper dialogue and acting alternatives are optional. Distinct needs levels and ammunition counts still need their own recordings. Only approved takes enter the package. It measures the audio, validates required slots and metadata, and checks registration against Core. It writes a mod directory and refuses to overwrite an existing output.

This CLI command writes only the mod directory. Studio's **Build package** wraps that mod in a Workshop project with `workshop.txt`, square and wide previews, and matching icons. Neither workflow publishes to Steam. Use the [creator guide](../../../../studio/CREATOR-GUIDE.md#build-and-test-the-pack) for upload and in-game checks.

## Pack rules

Core owns situations, priorities, interruptions, repetition, stealth, playback, and networking. Packs own voice identities, localized captions, audio, acting, and measured calibration. Studio cannot create new gameplay situations.

Voice IDs and native sound prefixes must be unique and remain stable after release. Duplicate identities are rejected. Display names do not replace vanilla voices. Providers can explicitly reuse a recording for compatible slots, so equal slot coverage does not require equal physical file counts.

See the [provider reference](../../../../docs/voice-packs.md) for the contract, registration, preview playlists, and permission for independent packs. The bundled `voice-contract-v1.json` and template define required recordings. Use those files rather than a count copied from a guide.

## Audit recordings

Run `tools/audit_recordings.py --help` for decoding, silence, peak, and abrupt-edge checks. Optional transcript inputs support language and spoken-direction checks. An audit flags suspected problems; it cannot establish natural acting or correct pronunciation without listening.

## Tests

From this directory, run:

```sh
python3 -B -m unittest discover -s tests -v
```

Set `VOICE_TEST_FFMPEG` to the FFmpeg executable to include real conversion, measurement, editing, and packaging tests:

```sh
VOICE_TEST_FFMPEG=ffmpeg python3 -B -m unittest discover -s tests -v
```

In PowerShell, set `$env:VOICE_TEST_FFMPEG = 'ffmpeg'` before running the Python command. These checks use test audio and engine substitutes. They do not establish live gameplay or multiplayer behavior.

### Situation, delivery and acting

Situation identifies why the survivor reacts. Delivery identifies normal speech, whispering, shouting or a nonverbal sound. Acting identifies a performance such as frightened or breathless; “Not specified” means the source does not specify one. Variation selects a take within that delivery and acting. These fields come from Core, not the filename or edited caption. Existing recording IDs remain unchanged.

A missing whisper is not replaced with a normal recording labelled as a whisper. Optional takes can be added later. A one-take pool also still obeys repetition limits, so it will be quieter than a varied pack. The build dialog reports coverage separately from how many optional takes remain unreviewed.

Packs built with `coverage = "situations-v1"` require a Core version that supports this coverage policy. Older Core versions require the complete recording set and reject these smaller packs. Existing complete packs remain supported.
