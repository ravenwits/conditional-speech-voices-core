# Conditional Speech Voices - Core

Source code and bug reports for the Core mod, by ravenwits.

Core handles speech rules, playback, settings and debug reports. It requires [Conditional Speech by Chuckleberry Finn](https://steamcommunity.com/sharedfiles/filedetails/?id=2398253681). Core works without a voice pack, but no recorded speech will play until you install a compatible voice pack.

## Status

Version 0.42.7. Single-player beta, tested with Project Zomboid 42.21.0. Multiplayer is not yet verified. The latest character-specific pitch setting still needs a live save/reload check.

## Install

Copy `Contents/mods/ConditionalSpeechVoicesCore` into your `Zomboid/mods` folder. Enable Conditional Speech and Core for the save. Add a voice pack for recorded dialogue, then fully restart the game. Avoid enabling a local and Workshop copy of the same mod together.

Mod ID: `Conditional-Speech-Voices-Core`

## Start Studio

Download or clone this repository. Install Python 3.11 or later and add FFmpeg to PATH. Open
`Contents/mods/ConditionalSpeechVoicesCore/authoring` and double-click **Start Studio.cmd**.
The launcher opens a browser tab. Keep the launcher window open while you work.

Use **New project** in the project picker to choose a voice name and language. Studio saves your work
under `Zomboid/VoiceProjects`. The compiled app is included in this repository.

- [Studio guide](studio/CREATOR-GUIDE.md)
- [Command-line guide](Contents/mods/ConditionalSpeechVoicesCore/authoring/README.md#command-line)

## Report a bug

[Open a bug report](https://github.com/ravenwits/conditional-speech-voices-core/issues/new?template=bug-report.yml). English and Turkish reports are welcome.

Enable Speech Debug in Mod Options, reproduce the issue, then use **Debug > Conditional Voices > Save report** from the world right-click menu. Attach `Zomboid/Lua/CSV-report.txt` and relevant `console.txt` lines. Remove private information before posting. If export fails, explain that in the form.

## Development

Run `python tools/check.py` with Lua 5.1 available. These checks cover syntax and isolated Core behavior. They do not prove live audio playback, multiplayer behavior or coverage of every recording. See [testing](docs/testing.md).

See [Core boundaries](docs/architecture.md) for scheduling, event context, Q calls and native injury ownership.

## License

Copyright (c) 2026 ravenwits. [PolyForm Strict 1.0.0](LICENSE.md).

The source is publicly readable. The license permits noncommercial use; it does not grant permission to redistribute, modify or use the software commercially. Ask for written permission before sending code changes or redistributing any part of it. Bug reports and suggestions are welcome.

The original Conditional Speech mod, language packs and recordings are not included in this repository.

## Voice pack authors

See [the provider interface and permission for independent packs](docs/voice-packs.md). Existing save identifiers remain supported.
