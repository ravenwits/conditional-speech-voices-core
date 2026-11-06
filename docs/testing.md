# Tests

`python tools/check.py` parses every shipped Lua file and translation JSON, then runs isolated tests for missing voice packs, observer failure recovery, hook ownership, character-specific pitch and bounded API error reporting.

Use Lua 5.1. Set `LUA` to its executable if it is not on PATH. The local runner also accepts Neovim's LuaJIT through `NVIM` for development; CI runs Lua 5.1.

The missing-pack test has no game or upstream dependency. It checks that Core offers no audio candidates without a voice pack. The observer and pitch tests use small API substitutes. They do not prove that the engine called those APIs or saved a character successfully.

The private development workspace also has broader game integration scenarios and audio checks. Those are not included here because they depend on separately distributed voice banks and game/mod files. This repository does not claim to reproduce the entire private suite.

Before a release, verify pitch after save/reload and across two characters, Q captions while shouting/sneaking/using a megaphone, and native pain reactions in game. Multiplayer needs an actual two-client session.
