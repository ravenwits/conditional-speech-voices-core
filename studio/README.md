# Conditional Speech Voices Studio

Studio is a local editor for voice packs. It uses the recording slots supplied by Core. You can import audio, record through a microphone, edit takes, review them, and build a Workshop upload folder.

To use the compiled app, read the [creator guide](CREATOR-GUIDE.md). Python and FFmpeg are prerequisites. Node is needed only to develop the interface.

## Source layout

`studio/src` contains the React interface and its Coss UI components. `studio/public` contains Cal Sans and third-party notices. Code labels use the operating system's monospace font.

`Contents/mods/ConditionalSpeechVoicesCore/authoring` contains the Python server, audio processing, pack builder, tests, and Core recording catalogue. Studio calls these tools. The command-line tools use the same code, so the two workflows share validation and file handling.

The interface build goes to `authoring/tools/studio`. This directory contains compiled files, not a second source tree. Workshop releases exclude `authoring`; creators get it from GitHub.

## Build the interface

Use Node 24 LTS and npm. From `studio`, run:

```sh
npm ci
npm test
npm run build
```

The build locates Core under `Contents/mods` in the public repository or `mods` in the development tree. It writes the compiled interface beside the Python server. Restart Studio and reload the browser after a build.

The interface uses React, TypeScript, Vite, Tailwind CSS 4, and Coss UI built on Base UI. Dependency versions are recorded in `package-lock.json`.

## Update Core recording requirements

From `Contents/mods/ConditionalSpeechVoicesCore/authoring`, run:

```sh
python3 -B tools/export_studio_schema.py
python3 -B tools/export_studio_schema.py --check
```

Use `python` instead of `python3` on Windows. The exporter requires Neovim on PATH, or the `NVIM` environment variable set to its executable. Commit the generated catalogue with the Core change. The server checks its source hashes and refuses a stale catalogue.

Studio reads these definitions. It does not maintain another copy of gameplay decisions. Opening a project adds new required slots, preserves recordings and captions, and saves a backup before changes. Changed meanings require another review. Listening samples remain samples until expanded.

The launcher can update a clean official Git clone before startup. It skips local changes and continues with installed files when offline. A ZIP download needs a manual update. Updating the Steam mod alone does not update a separate Git checkout.

## Test changes

Run `npm test` for interface behavior. Run the Python authoring tests described in the [command-line guide](../Contents/mods/ConditionalSpeechVoicesCore/authoring/README.md#tests) for imports, editing, project management, and packaging. The creator checks run on Linux and macOS in GitHub Actions.

Automated tests do not prove that a microphone, browser playback, or the generated pack works in the game. Test those paths separately before a release.
