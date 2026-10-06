# Status and owner checklist

Last updated: 2026-10-07 (plan v2: "complete everything").

**Short version:**
- The game is fully written: code, economy, 43 critter models, sound and voice.
- It has **never run on a real Roblox server.** This cloud environment can't reach `apis.roblox.com`, and nobody has opened it in Studio yet.
- The next step is yours (section 2). After it, a new Claude session can publish, upload and smoke-test without you.

## 0. Latest: plan v2 ("complete everything")

Everything is pushed to `main`, and all checks pass: 140 unit tests, strict types, lint, place lint, economy gates. Plan: `docs/PLAN_V2.md`.

| New | Try it |
|---|---|
| **The Bounty Trail:** 40 big quests in 8 chapters (2–3 objectives each), ending at Frontier 8, about 10+ hours for a free player (see `docs/ECONOMY.md`). Chapter finales give a title, spins, Nuggets and 2× Cash. **Weekly bounties:** 4 a week, plus a bonus for clearing all four. A quest tracker sits on the HUD | QUESTS → BOUNTY TRAIL / DAILY / WEEKLY; the tracker is left of centre |
| **Onboarding:** a red arrow and beam on every tutorial target (your reserved cage, your collect plate, Bandit Bart), hints that follow the train, then a teal arrow to the first heist | Start with a fresh save (Studio: Data → reset, or a new test account) |
| **8 gear items** now unlock across Frontiers 0–7: Grapple Hook (dash), Dynamite Decoy, Cactus Wall, Stampede Call, Ghost Lantern | Gear tab; hotbar keys 1–8 |
| **Sprint with stamina** (Shift / L3 / SPRINT button), FOV kick, dust and landing puffs | Hold Shift |
| **Trading:** same-server escrow, policy-gated | MORE → TRADE |
| **Wardrobe and visible cosmetics:** title tags, hats, lasso and poster colours, ranch themes | MORE → Wardrobe |
| **Graphics:** Future lighting, a golden-hour day cycle, a mood per zone, dust, tumbleweeds, buzzards, fireflies, and richer zones and town | Walk out to each zone |
| **Bandit Camp red light:** the bandit visibly naps, wakes and watches | Go to the Bandit Camp |
| **Whole-codebase review:** about 40 bugs fixed. The big ones: the HUD now scales on phones; idle animations now run; heist/wheel/boss reveals show the critter; the "collect" quest now counts; cosmetics now render; and the purchase-safety fixes | — |

## 0b. The overnight build (before plan v2)

Everything below is pushed to `main`, and every check passes: 119 unit tests, types, lint, place lint, economy gates. Plan and status: `docs/OVERNIGHT.md`.

| New | Try it in Studio |
|---|---|
| **Store redesign.** Tabs: Passes, Boosts, Cash, Critters, Gear, Nuggets. Picture cards with price tags. Tap a card for a big preview with an effect that matches the item: coin shower, gold glitter, clovers, speed lines, shield rings, smoke, rolling tumbleweed, trap snap, a rarity beam behind a live 3D critter, egg wobble | Open SHOP and tap through every tab and card |
| **Gear hotbar.** Keys 1/2/3 or tap, with a cooldown sweep. Smoke cloud, tumbleweed shockwave, bear trap snap | Buy the Smoke Bomb ($2,500) in the Gear tab and press 1 near a heist guard |
| **Server events** every 25 min, with a real countdown banner (right side): Crate Rain, Gold Rush (2× cash), Jackpot Restock, Bandit King | In Studio the first event fires **45 s** after you press Play |
| **Bandit King boss** in Ghost Town. He leaps every few seconds; dodge the red ring. Everyone lassoes him together (button: LASSO KING!). Loot for every helper, and a rare critter for the top lassoer | Wait for the event, or play a few events in a row |
| **Leaderboards** with a gold statue of the all-time #1: Richest (west end of the platform), Top Heisters (east end), Most Wanted (Bandit Camp) | Walk to the platform ends. "All-time" only fills in once the game is published |
| **Almanac sets.** Find every species of a rarity for +5% income, forever. Earned boosts: finish all daily quests → 15 min 2× Cash; help beat the Bandit King → 10 min Luck Potion | Open ALMANAC to see the set strip |
| Tonight's code also got a review pass, and the bugs it found are fixed | — |

**Playtest checklist for the new parts** (screenshots of anything odd help a lot):
1. Shop: does every card show a picture? Icons stay as glyphs until the image upload in section 2. 3D critters show now.
2. Preview: do the effects look good, and does the buy button work? In Studio every Robux item is granted free as **[STUDIO TEST]**.
3. Gear: is the hotbar visible after buying? Do the 1/2/3 keys work?
4. Events: does the banner count down? Do Crate Rain crates land on Main Street, and can you grab and run them home?
5. Bandit King: does he leap smoothly? Is the health bar readable? Does the loot arrive?
6. Leaderboards: are the boards readable from the platform?
7. Sprint: hold Shift (PC), click L3 (gamepad) or hold/tap the SPRINT button (phone, left of jump). Do you run ~30% faster for 5 s, does the stamina bar drain (faster while carrying) and refill, and does the FOV kick, dust and landing puff feel good? Shift-lock moved to Ctrl.
8. Trading (2-player test server, both at Frontier 1+): MORE → TRADE → invite. Add critters and nuggets, change an offer while both are READY (the countdown must stop), then finish a trade and check both ranches. Studio skips the account-age and policy checks.

## 1. What exists

| Area | State | Where |
|---|---|---|
| Plan, research, economy, art bible | Done | `docs/` |
| Server (17 services) | Written, type-checked, never run on Roblox | `src/server/` |
| Client: train, critters, HUD, menus, reveals, VFX, sound | Written, type-checked, never run on Roblox | `src/client/` |
| Pure game logic | 99 unit tests pass | `src/shared/Sim/`, `tests/unit/` |
| Economy simulator | Gates pass: first rebirth ~29 min, third ~94 min, top spender ~6.6× faster than free | `tools/econ-sim/`, `docs/ECONOMY.md` |
| Critter 3D models | 43 FBX meshes from Blender, not uploaded | `assets/critters/`, `tools/blender/` |
| In-game critter look | Procedural rig built from code (matches the Blender designs) | `src/client/Controllers/CritterRig.luau` |
| Sound effects | 26 sounds, processed | `assets/audio/game/` |
| Voice | 43 name callouts + 7 announcer lines | `assets/audio/game/voice/` |
| Prompt log | Every sound and voice prompt | `assets/audio/PROMPTS.md` |
| Cloud tools | Publish, asset upload, product ids, Luau execution | `tools/cloud/`, `tests/cloud/smoke.luau` |
| CI | GitHub Actions runs `scripts/check.sh` on every push | `.github/workflows/ci.yml` |

**Not done yet, and why:**
- **Nothing tested on Roblox.** Blocked on the API key and network access (section 2). This is the biggest risk: expect a round of fixes the first time it runs.
- **Figma UI.** Waiting on a paid Figma seat. The UI is built in code to the art bible meanwhile.
- **Music.** Plan is free licensed Creator Store tracks. They're picked in Studio or the Creator Store, then their ids go into `musicCalm` / `musicChase` in `src/shared/Config/Sounds.luau`.
- **Uploaded 3D models.** The game uses the procedural rig. Swapping in the FBX meshes is the "asset-upload spike" in the plan (`tools/cloud/upload_assets.py --models`, then load the models by id).
- **Art.** The hero pass on the top tiers is done (`assets/concept/critter_sheet_v2.png`):
  - real crowns, layered wings, flame tufts, serpent tails and a cloud;
  - black hats for Outlaws, gold hat bands for Mythic and up.
  - The train, station and buildings are still built from code parts, not Blender meshes.
- **Human playtests on phones.** Only you can do these (section 4).

## 2. Owner setup (in this order)

1. **Roblox account.**
   - Turn on 2-step verification.
   - Complete ID verification (raises upload limits).
   - **Start Roblox Premium now.** Kids/Select listing needs 2 consecutive months of it.
2. **Group + experiences.**
   - Create a Roblox group to own the game.
   - Under the group, create two experiences: `Critter Express [TEST]` (private) and the LIVE one (private until launch).
   - In TEST → Settings → Security, turn on **Enable Studio Access to API Services**.
3. **Open Cloud API key** (Creator Dashboard → Open Cloud → API Keys).
   - Restrict it to the **TEST** experience.
   - Scopes: universe-places write (publishing); Luau execution sessions read + write; assets read + write; data stores read + write.
   - Allowed IP `0.0.0.0/0` (this environment's IP changes). Expiry 90 days.
4. **This cloud environment's settings.** Open the environment menu in the session title bar → Edit.
   - Environment variables:
     - `ROBLOX_API_KEY` = the key. **Never paste it in chat.**
     - `ROBLOX_UNIVERSE_ID` and `ROBLOX_TEST_PLACE_ID`: from the TEST experience's URL and settings.
     - `ROBLOX_GROUP_ID`: the group that owns uploaded audio.
   - Network access: **Custom**, and add `apis.roblox.com`.
5. **Start a new session** in this repo. Settings only apply to new sessions. Then ask: *"Publish to TEST and run the smoke test."*
6. **Passes and products.**
   - Run `python3 tools/cloud/create_products.py --list` for the exact names, prices and descriptions.
   - Create each pass/product in Creator Hub.
   - Then give a session the ids, or run `python3 tools/cloud/create_products.py --set VIP=<id> ...` yourself.
7. **Maturity & Compliance questionnaire.** Answer Mild, and **declare paid random items**: Server Luck, Lucky Horseshoe and Sheriff's Star change odds.
8. **ElevenLabs.** Confirm a **paid plan**, which commercial use of the generated audio requires.
9. **Figma.** When you have a paid Full seat, say which team/project to use.

## 3. What a session does after setup

```bash
python3 tools/cloud/publish.py                         # build + publish to TEST
python3 tools/cloud/run_luau.py tests/cloud/smoke.luau  # boot, train, config, DataStore checks
python3 tools/cloud/upload_assets.py                    # 76 audio files -> ids -> Config/AssetIds.luau
python3 tools/cloud/publish.py                         # republish with sound
```

- **Commit the ids.** `upload_assets.py` writes `assets/ids/*.json` and regenerates `src/shared/Config/AssetIds.luau`. Commit both.
- **Unverified client.** `run_luau.py` was written without access to the real API. If the first run fails on the request format, fix the client first.
- **LIVE publish** needs `ROBLOX_LIVE_UNIVERSE_ID` and `ROBLOX_LIVE_PLACE_ID`, plus `--live --confirm-live`. Only do it after your "ship it".

## 4. Your first playtest

Do this on a phone (plus PC if you can), in the TEST place.

1. **Comprehension.**
   - Within 30 s of spawning, do you know what to do?
   - Does the RESERVED cage stand out?
2. **First buy.** Buy a critter: does it run home and earn money?
3. **Collect.** Collect at your ranch: coin burst and sound?
4. **Lock.** Lock the ranch: timer visible?
5. **Bandit tutorial (~4 min).** The tutorial bandit steals: can you lasso it back?
6. **Bandit Camp.** Hold to steal while the bandit naps, release when he peeks.
7. **Eggs.** Get an egg → hatch: is the reveal exciting? Is the name callout audible over the music?
8. **Second account.**
   - Steal from each other after the 15-min shield.
   - Does WANTED show?
   - Can the victim lasso the thief?
9. **Shop.** Open it: the odds panel lists every outcome and sums to 100%.
10. **Performance.** FPS on the weakest phone. Heat after 20 min.

Send screenshots or screen recordings of anything that looks wrong. Claude can't see the game render.

## 5. Known risks to watch on first run

- **Untested engine APIs.** Several engine APIs have never been exercised: the new Audio API wiring, Highlights, AudioPlayer assets, and TextChat-free stickers. Errors show in the server/client logs; the smoke test catches server boot failures.
- **Code-built town.** The town is built from code (`World` service). Spacing or scale may need tuning once seen.
- **Sound lengths.** Some generated sounds came out shorter or longer than asked; see the note in `PROMPTS.md`.
