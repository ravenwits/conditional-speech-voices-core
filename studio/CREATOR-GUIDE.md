# Make a voice pack

Studio is a local authoring tool. Players do not need to run it. Core supplies the situations and recording slots; Studio helps you fill and check them.

## Start

Use Python 3.11 or newer and a local FFmpeg executable. Pitch and speed edits require an FFmpeg build containing the rubberband filter. No Node installation or recording-service account is needed to run the compiled editor.

1. Download or clone the GitHub repository, then open `Contents/mods/ConditionalSpeechVoicesCore/authoring` and double-click **Start Studio.cmd**. Python and FFmpeg are prerequisites, not optional downloads. The launcher checks them and opens CONDITIONAL SPEECH VOICES STUDIO in your browser.
2. Create a project in the opening dialog. Choose a voice ID, language and character base. Full pack is the default. No terminal commands or Node installation are needed.
3. Keep the launcher window open while using Studio. Close it when finished. Projects are saved under `Zomboid/VoiceProjects`, outside the Steam installation.

The project picker opens existing projects; its settings button changes their details. New projects can use any language in the searchable list regardless of the game's UI language. Studio does not translate or generate recordings.

The optional 18-recording trial checks normal speech, whispers, calls, breathing, effort and pain. It is a quick audition, not a test of every emotion. Expand it to the full pack before building.

For an existing project stored elsewhere, the optional command is `python tools/launch_studio.py --project PATH --ffmpeg PATH_TO_FFMPEG`. The frontend has the same import, editing, review and build tools.

## Record and import

1. Select a situation, then a variation. Follow its meaning and recording guidance. Guidance is not part of the spoken line.
2. Record in any tool. Name each file after its slot, such as Explore_1.wav. Import one take beside the player, or use Import above the library for a batch.
3. Keep each caption within 240 characters and each take within 20 seconds. These are Studio authoring limits, not claimed engine limits. Imports over 16 MiB or 20 seconds are rejected, not silently cut.
4. Listen and approve, or mark Needs a retake. Batch import replaces missing and retake slots only. Other existing takes are kept.

Use the project switcher to change projects. Its settings button edits the name, author, optional Steam profile URL, version and description. The Steam profile becomes the pack's homepage link.

## Edit and review

The player has play/pause, stop and seeking. Edit audio saves volume, pitch and speed changes into the recording used by the game. Each render starts from the preserved original. Restore recovers that file exactly. Pitch and tempo are independent; extreme settings can still sound unnatural.

Changes that exceed the duration or peak-headroom limit are rejected. A changed file or caption needs approval again. Checking audio levels does not establish that the words, pronunciation or performance are correct.

Approve filtered and Retake filtered apply across all pages of the current filters. The confirmation shows the affected count. Missing audio is excluded, and retake never deletes files. Bulk approval is appropriate only after you have listened to those takes. It does not mean Studio listened to them for you.

Undo bulk review restores the previous review states for the last batch. It refuses to overwrite recordings edited after that batch. It does not undo audio processing.

Use **Commands** or Ctrl+K to find actions. Alt+Left/Right selects recordings, Ctrl+Enter approves and advances, and Ctrl+Shift+Z undoes the last bulk review. Space plays or pauses when the page itself has focus. Typing in a field keeps its normal editing behavior.

Edit the large phrase directly, then Save text. This updates the caption and library without changing the Core slot ID. Unicode and right-to-left text are supported. Recording guidance stays read-only.

## Build and test

Open Build voice pack, check audio levels, resolve missing takes and reviews, confirm you have the rights to distribute the recordings, then build. While checking, Studio shows an activity indicator; large packs can take several minutes. The result and a notification appear when finished. Measurements identify level outliers but do not replace listening. A trial must first expand to the full schema. The tool will not invent missing audio.

The build includes a square Workshop preview, a matching in-game icon and a
1280 × 720 image for sharing. Studio selects a representative flag from the
pack language. Languages without a mapped flag use a globe.

Close Project Zomboid. Copy the generated mod directory into your Zomboid/mods directory, keeping its 42 and common folders together. Enable Conditional Speech, Conditional Speech Voices Core and your pack. Choose the new voice at character creation. Test ordinary speech, whispers, calls, exertion and pain in the game before distributing it. Studio playback and automated checks are not proof of in-game playback or multiplayer behavior.

Back up the entire project folder, including its manifest, audio and originals. The generated game mod is an output, not a replacement for that editable project.

## Distribution

Keep Studio an optional creator download alongside Core, rather than a requirement for players. Source and compiled creator tools are kept in the GitHub repository. Workshop releases exclude the entire authoring directory, so players do not download Studio. A separate download must stay tied to its Core schema version. Do not copy and maintain a second set of gameplay rules in Studio.

The recording selector separates delivery from phrase variation. Only existing deliveries are offered. Loop repeats the selected recording for listening; it does not change the exported audio. Hover over the timeline to see seconds and milliseconds.

## Core updates and trimming

Start Studio checks the official Git checkout for updates at launch. It fast-forwards only a clean checkout on its tracked origin branch. Local edits or an unavailable connection leave the installed version intact. ZIP downloads do not update automatically; replace them with the latest repository download or use a Git clone. Restart Studio after updating Core. Core and the Studio catalogue ship together in the repository; the release check rejects a stale catalogue.

Opening a project reconciles its requirements with the installed Core catalogue. Existing text and recordings stay in place, new slots appear as missing, and a `.before-update.json` backup preserves the previous project. Trials remain trials. Review changed meanings again before building.

Trim start and Trim end remove seconds from the preserved original, before speed and pitch processing. Apply writes a separate take and clears its listening approval. Restore original also removes trimming. Empty results are rejected without changing the active take.
