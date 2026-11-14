# Conditional Speech Voices - Studio

Local recording editor for Conditional Speech Voices. Create a full voice pack or start with an optional 18-recording listening trial. Record with any tool, then import the audio. No recording service is built in.

The shipped application runs from Python. Node and an internet connection are not needed to use it. Fonts and compiled interface assets are included.

See [Creator guide](CREATOR-GUIDE.md) for recording, reviewing and installing a pack.

## Maintain the interface

The interface uses React, TypeScript, Vite, Tailwind CSS 4.3.5 and Coss UI components built on Base UI. Cal Sans and Geist Mono are bundled locally. Third-party licenses are in `public/THIRD-PARTY-NOTICES.txt`.

```text
npm ci
npm test
npm run build
```

In the public repository, the build writes to `../Contents/mods/ConditionalSpeechVoicesCore/authoring/tools/studio`. In the development tree it writes to the corresponding `../mods` folder. Run the Python editor from the Core authoring directory:

```text
python tools/prepare_voice_pack.py edit MyVoice/pack.json --ffmpeg C:/Tools/ffmpeg.exe
```

## Core owns the schema

`export_studio_schema.py` reads the actual Core Lua modules, slot contract and template. It exports category data, source references, moodle levels and character events into `voice-schema-v1.json`. Run it with Neovim available as `nvim`, or set `NVIM` to its executable. The `--check` option detects stale exports.

Studio does not evaluate or edit gameplay rules. Source excerpts show where a group is referenced, not every prerequisite or proof that it played. Shared safety, channel and selection code is available in the read-only details. A contextual delivery means Core chooses the context; Studio must not invent a fixed acting label.

The server checks the catalogue's source hashes on startup. It rejects extra slots and changed Core-owned mappings. Text and audio remain editable. Recording guidance is read-only and describes performance, never gameplay conditions.

## Interface behavior

- Recordings stay on the main page. The project name opens a searchable switcher. Each project has a separate details action. Import opens from the recording library; Prepare pack contains checks and build actions.
- The sidebar groups recordings by Core situation. Groups expand to show individual takes, and a variation selector also chooses the actual line and delivery. Fifty situations are rendered per page. Search and filters cover the whole catalogue, not just that page.
- Missing, needs listening, approved and needs a retake are separate states. A changed take, caption or recording note invalidates approval.
- New projects default to full scope. Expanding a trial preserves existing work and saves a manifest backup.
- The 800-pixel breakpoint narrows the sidebar; below 600 pixels the list sits above the recording. Dialog content scrolls while its actions remain accessible.
- Failed saves leave edits intact. Revision conflicts require a reload; an expired local session is renewed once. Cross-origin and non-loopback requests are rejected.

All interactive controls use the copied Coss UI components, including selects, tooltips, sliders, confirmations and collapsible panels. Semantic page structure remains ordinary HTML. The file chooser is a hidden native file input.

Audio edits are saved, not preview-only. Volume uses -12 to +12 dB; pitch uses -4 to +4 semitones with the duration preserved. Speed uses 0.25 to 2 times the original tempo. FFmpeg must include the `rubberband` filter for pitch and speed changes. Every render starts from a preserved original; Restore original recovers its exact bytes. The editor rejects settings that exceed -1 dBFS decoded sample-peak headroom before changing the active take. Audio quality still requires listening. Applying an edit resets approval and cached measurements.

Read-only recording guidance uses an existing production direction when a project supplies one, otherwise Core delivery and need severity. Legacy custom notes remain in project files. They cannot change game rules. The player plays the saved take at its actual speed. Tempo changes in Edit audio are written into the exported recording, independently of pitch.

Tests cover filtering across the full catalogue, bounded rendering, dialogs, unsaved edits and session renewal. Python authoring tests cover the schema boundary, project creation, imports, approvals and building a complete pack. Playback in Studio is a listening check, not an in-game test.

The interface bundles Cal Sans from https://github.com/calcom/sans under the included OFL license. The 18-take trial covers basic voice suitability, not every emotional delivery. Full-pack imports do not automatically mark recordings as listened to. After a successful build the dialog explains how to install and test the generated mod.
