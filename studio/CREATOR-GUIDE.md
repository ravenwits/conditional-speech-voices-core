# Create a voice pack with Studio

Use CONDITIONAL SPEECH VOICES STUDIO to prepare a voice pack through your browser. Studio runs on your computer. It does not generate voices or upload recordings.

## Install the prerequisites

Install [Python](https://www.python.org/downloads/) 3.11 or newer and [FFmpeg](https://ffmpeg.org/download.html). Put both executables on PATH. To build a pack, also install Lua 5.1, LuaJIT, or Neovim. Pitch and speed edits require FFmpeg's `rubberband` filter. Cover generation requires its `drawtext` filter.

Download or clone the Core GitHub repository. The compiled interface is included. You do not need Node to use Studio.

## Start Studio

Open `Contents/mods/ConditionalSpeechVoicesCore/authoring` in the repository.

- On Windows, double-click `Start Studio.cmd`.
- On Linux or macOS, run `sh "Start Studio.sh"` from a terminal in that directory.

The launcher opens your browser. Keep the terminal window open. Press Ctrl+C to stop the server when finished. The server accepts connections only from this computer.

If FFmpeg is not on PATH, pass its executable path:

```sh
python3 -B tools/launch_studio.py --ffmpeg /path/to/ffmpeg
```

On Windows, use `python` instead of `python3`. To open an existing project, add `--project /path/to/project.json`. By default, Studio stores projects in `Zomboid/VoiceProjects` under your home directory. The `--projects` option changes this location.

## Create a project

1. Open the project picker and choose **New project**.
2. Enter a unique voice ID. Include your creator name, such as `raven_alex`, to reduce conflicts with other packs.
3. Enter the name players see at character creation. This name does not replace a vanilla voice. Another voice can have the same display name, so choose a distinct name.
4. Choose the language, character base, and scope.
5. Choose **Create project**.

Full pack is the default. **Listening sample** contains 18 takes for speech, whispers, calls, breathing, effort, and pain. Expand the sample before building a pack.

Languages are independent of the game's interface language. English and Turkish reference text is supplied. Translate other languages before recording. Keep the intended meaning and severity.

Use the settings button beside a project to edit its name, author, Steam profile URL, version, and description. A pack version has three numeric parts, such as `1.0.0`. Voice IDs must remain stable after release. Core rejects conflicting IDs and prefixes rather than replacing another pack.

## Add recordings

Select a situation, delivery, and variation. Follow the recording guidance without speaking it aloud.

- **Import audio** replaces the selected take.
- **Record audio** lets you choose a microphone, record, and listen. Only **Use this recording** saves the take to your project.
- **Batch import** matches filenames to slots, such as `Explore_1.wav` or `raven_alex_Explore_1.mp3`. It fills missing slots and replaces takes marked **Needs a retake**. Other recordings stay unchanged.

Use **Download slot names** in Batch import for the current slot list. Unknown filenames are skipped. Duplicate inputs for one slot are rejected.

Imports support WAV, FLAC, MP3, Ogg, Opus, M4A, MP4, AAC, and WebM. Each file must be at most 16 MiB and 20 seconds. Studio converts uploads to mono MP3 at 96 kbps. A failed import keeps the previous take.

Edit the large phrase and choose **Save text** to change the caption. Captions support Unicode and right-to-left text, with a limit of 240 characters. The slot ID remains unchanged.

## Edit and review takes

Use the player to listen, seek, or loop. **Edit audio** applies volume, pitch, speed, and trimming to the saved take. Each edit starts from a preserved original. **Restore** recovers that original.

Trim start and Trim end remove time from the original before speed processing. The controls cannot remove the whole recording. Excessive peak levels and outputs longer than 20 seconds are rejected.

Choose **Approve**, **Needs a retake**, or **Needs listening**. Audio and caption changes require another review. Approval records your decision; it does not mean Studio checked pronunciation or acting.

The sidebar's bulk actions affect matching recordings across all pages. Missing recordings are excluded. **Undo** restores the previous bulk decision unless a later edit changed a take. It does not undo audio edits.

Open **Commands** for keyboard shortcuts and available actions. The shortcut labels in that menu reflect the current app behavior.

## Build and test the pack

1. Open **Build voice pack**.
2. Choose **Check audio levels** and wait for the result. Listen to flagged takes.
3. Resolve missing audio and unapproved takes.
4. Confirm that you have the rights to distribute the recordings.
5. Choose **Build package**.

The output contains `workshop.txt`, `preview.png`, `preview-16x9.png`, and the mod under `Contents/mods`. The mod includes its icon and poster. Existing output folders are not overwritten. Increase the version for the next build.

The square cover uses a representative flag and language label. English uses the US flag and **English (US)**. Languages without a mapped flag use a globe.

To upload, copy the generated project folder into `Zomboid/Workshop` under your home directory. Use Project Zomboid's Workshop menu to review the description, preview, dependencies, and visibility before uploading. Studio does not publish automatically.

To test locally, close the game and copy the generated mod directory into `Zomboid/mods`. Keep its `42` and `common` directories together. Enable Conditional Speech, Conditional Speech Voices Core, and your pack. Select the new voice at character creation and test speech, whispers, calls, exertion, and pain. Do not enable both a local and a Steam copy of the same mod.

Studio playback is not proof of in-game sound or multiplayer behavior. Back up your whole project directory, including its original audio. The generated Workshop folder does not replace that editable project.

## Update Studio and Core requirements

The launcher checks for updates when you use a clean clone of the official repository. Local source edits prevent automatic updates. Offline use keeps the installed version. ZIP downloads require a fresh download.

After updating the repository, restart Studio. Opening a project updates its required slots from the bundled Core catalogue and preserves captions and audio. New slots appear as missing. A `.before-update.json` file preserves the previous manifest. A Steam subscription update does not update this separate creator tool.

## Use the command line

The [command-line guide](../Contents/mods/ConditionalSpeechVoicesCore/authoring/README.md) covers the same project files and tools. You can switch between Studio and the command line without converting your project.
