# Developing

## Tools
| Tool | Version | Install |
|---|---|---|
| Rojo | 7.7.1 | `cargo install --locked rojo --version 7.7.1` |
| StyLua | 2.5.2 | `cargo install --locked stylua --version 2.5.2 --features luau` (the `luau` feature is required) |
| selene | 0.31.0 | `cargo install --locked selene --version 0.31.0` |
| Lune | 0.10.5 | `cargo install --locked lune --version 0.10.5` |
| luau-lsp | 1.70.1 | Release zip from GitHub, or build from source with CMake (optional locally; CI installs it) |
| ffmpeg | any | Only for `tools/audio/` |
| Blender (`bpy` 4.5) | 4.5 | `pip install bpy`; only for `tools/blender/` |

Libraries are vendored in `vendor/` at pinned commits (ProfileStore, Vide, frktest), because the Wally registry isn't reachable from the cloud environment. See `vendor/README.md`.

## Everyday commands
```bash
bash scripts/check.sh                  # everything CI runs: format, lint, tests, registry, sim gates, build, types
stylua src tests tools                 # format
lune run tests/run                     # unit tests
lune run tools/econ-sim/main -- --seeds 60 --gates   # economy simulator
rojo serve                             # live-sync into Studio (Rojo plugin)
rojo build -o build/CritterExpress.rbxl
```

## Layout
- `src/shared/Config/` — all tuning data: species, rarities, economy, products, sounds. Also the generated `AssetIds.luau`.
- `src/shared/Sim/` — pure logic with no Roblox APIs. It runs in Lune, and `tests/unit/` covers it.
- `src/shared/Net/` — remote names, schemas and rate limits. Every remote is validated and rate-limited.
- `src/server/Services/` — one service per system. They are booted in a fixed order by `main.server.luau`.
  - Services call each other only through `Registry`, and `tools/check-registry.luau` verifies those calls.
- `src/client/` — controllers (train view, critter rig, VFX, sound) plus the Vide UI in `UI/`.
- `tools/` — the economy simulator, Blender build, audio processing, cloud publishing and uploads.
- `assets/` — critter FBX meshes, audio (raw + game-ready), uploaded asset ids.

## Rules of the codebase
- **Server authority.** The client only sends intents. Every amount is computed on the server.
- **One place per value.** Numbers live in `Config`. Logic that can be pure goes in `Sim` with a test.
- **Paid randomness.** Any product that changes random outcomes is marked `random = true`. Such products show live odds and are hidden when `PolicyService` says paid random items are restricted. That check fails closed.
- **Commits.** Run `scripts/check.sh` before every push.

## Audio pipeline
1. Generate a sound in ElevenLabs and log its prompt in `assets/audio/PROMPTS.md`.
2. Save the result to `assets/audio/raw/<key>.mp3`, or for voice batches to `raw/voice_batches/`.
3. Run `python3 -I tools/audio/split_voices.py`, then `python3 -I tools/audio/process.py`.
4. Upload with `python3 tools/cloud/upload_assets.py`. This needs the Roblox API key (`docs/STATUS.md`).

## Cloud (needs the owner setup in docs/STATUS.md)
`tools/cloud/publish.py`, `upload_assets.py`, `create_products.py`, and `run_luau.py tests/cloud/smoke.luau`.
