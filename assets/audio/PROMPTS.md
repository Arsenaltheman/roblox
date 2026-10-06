# Audio prompts log

Every generated sound, with the exact prompt, so it can be regenerated or tweaked.
Generator: ElevenLabs Sound Effects (`eleven_text_to_sound_v2`, prompt influence 0.3, no loop).
Format: MP3 128 kbps, 44.1 kHz stereo. Commercial use needs a paid ElevenLabs plan (see docs/STATUS.md).

Layout:
- `raw/` holds the files exactly as generated. `raw/voice_batches/` holds the batched voice recordings.
- `tools/audio/split_voices.py` cuts each batch on its pauses into `raw/voice/` (ignored by git: derived).
- `tools/audio/process.py` trims silence, caps length, fades and peak-normalizes into `game/` (Ogg Vorbis).
- `game/<key>.ogg` and `game/voice/<key>.ogg` are what gets uploaded. Keys match `src/shared/Config/Sounds.luau`;
  the asset ids are filled in there after the Roblox upload.

Regenerating one sound: run its prompt again in the flow, drop the result in `raw/` under the same name, run both scripts.

## Flow "Critter Express SFX v1" (tUg49bZGNL4xr6Moeatx)

| File | Key | Prompt |
|---|---|---|
| coin.mp3 | coin | Bright cartoon coin collect sound, a quick cascade of three shiny gold coin clinks with a sparkly chime tail, playful mobile game reward, clean, no music, under 1 second |
| whistle.mp3 | whistle | Old western steam locomotive whistle, two cheerful toots, cartoonish and warm, slight echo across a desert canyon, about 2 seconds |
| lassoThrow.mp3 | lassoThrow | Cowboy lasso rope spinning whoosh then a snappy rope catch tug, cartoon game sound effect, short and punchy, under 1.2 seconds |
| alarm.mp3 | alarm | Frantic old west brass alarm bell ringing fast, cartoon theft alert for a kids game, urgent but not scary, 1.5 seconds |
| eggWobble.mp3 | eggWobble | Cartoon egg wobbling and rattling on a wooden table with a rising anticipation tone, cute and suspenseful, 0.8 seconds |
| revealLegendary.mp3 | revealLegendary | Epic legendary reward reveal stinger for a mobile game: egg cracks open, magical shimmering whoosh, triumphant brass and banjo hit with sparkles, western flavor, 2.5 seconds |
| click.mp3 | click | Soft chunky wooden button click for a cartoon mobile game menu, satisfying pop, very short, 0.2 seconds |
| toast.mp3 | toast | Friendly two-note wooden marimba notification blip for a cartoon game, light and cheerful, 0.4 seconds |
| giftReady.mp3 | giftReady | Gift ready jingle for a mobile game, sparkly bell shimmer rising up with a happy ding at the end, cartoon, 1 second |
| collect.mp3 | collect | Big cartoon cash collect: a fountain of gold coins pouring into a pile with a cash register cha-ching at the end, satisfying, 1.5 seconds |
| buy.mp3 | buy | Purchase confirm sound for a cartoon western game: coin drop into a tin, a bright upward pluck of a banjo string, happy, 0.6 seconds |
| doors.mp3 | doors | Old wooden train freight doors sliding open with a metal latch clunk and a steam hiss, cartoonish, 1.2 seconds |
| lassoCatch.mp3 | lassoCatch | Rope lasso snapping tight around a target, a taut rope creak and a cartoon boing, punchy, 0.6 seconds |
| stolen.mp3 | stolen | Cartoon sneaky theft sting: quick tiptoe pizzicato strings and a sly descending slide whistle, playful not scary, 1 second |
| caught.mp3 | caught | Triumphant cartoon gotcha sound: a rope yank, a comedic thud, then a short heroic brass ta-da, western flavor, 1.2 seconds |
| lock.mp3 | lock | Heavy iron padlock snapping shut with a deep metallic clunk and a short magical force-field hum, cartoon game, 0.8 seconds |
| eggCrack.mp3 | eggCrack | Cartoon eggshell cracking open with a crisp crunch and a soft magical poof, cute game sound, 0.7 seconds |
| revealCommon.mp3 | revealCommon | Small cheerful reward reveal for a mobile game: a light pop and a short happy banjo strum, modest, 1 second |
| revealRare.mp3 | revealRare | Rare item reveal for a cartoon western game: shimmering chime sweep upward into a bright fiddle and banjo flourish, exciting, 1.5 seconds |
| revealEpic.mp3 | revealEpic | Epic item reveal stinger for a mobile game: deep magical whoosh, purple sparkle shimmer, big brass and harmonica hit, western flavor, 2 seconds |
| revealMythic.mp3 | revealMythic | Mythic reward reveal for a kids game: rumbling build up, fiery whoosh, thunderous orchestral western brass hit with choir and crackling sparks, huge and triumphant, 3 seconds |
| revealSecret.mp3 | revealSecret | Ultra rare secret reward reveal: mysterious music box twinkle, slow-motion reverse swell, then a dazzling rainbow sparkle explosion with angelic choir and celebratory western fanfare, 4 seconds |
| strongboxOpen.mp3 | strongboxOpen | Old iron strongbox being cracked open: lock mechanism clicks, heavy lid creaks open, a burst of gold coin shimmer, cartoon, 1.5 seconds |
| frontier.mp3 | frontier | Level up rebirth celebration for a western cartoon game: rising whoosh, fireworks pops, triumphant brass and banjo fanfare with a cowboy yeehaw crowd cheer, 3 seconds |
| weatherStart.mp3 | weatherStart | Magical desert weather event starting: distant rolling thunder, wind gust rising, a shimmering magical chime swell, cinematic but cartoon friendly, 2.5 seconds |
| goldenExpress.mp3 | goldenExpress | Special golden train arriving: long majestic steam whistle, chugging wheels, glittering chimes and a regal brass fanfare, exciting announcement, 3 seconds |

Note: the model chooses its own length and often ignores the one in the prompt. `revealSecret` came out
0.5 s, so the secret reveal leans on the 3-beat egg wobble and crack before it. A longer take is worth
regenerating when credits allow.

## Voice lines

Voice: ElevenLabs premade "Liam – Energetic, Social Media Creator" (`TX3LPaxmHKxFdv7VOQHJ`), model
`eleven_multilingual_v2`. Each batch is one recording with `<break time="1.5s" />` between lines.

| Batch file | Lines (in order; each is "<Name>!") |
|---|---|
| b1.mp3 | Cactus Carl, Tumbleweed Tim, Sir Hay Bale, Pebble Prospector, Dusty Bunny, Lil' Lantern, Boots McGoat, Pickle Pete, Saddle Snail, Horseshoe Hank, Cornbread Corgi |
| b2.mp3 | Windmill Willy, Burrito Bronco, Yeehaw Yak, Rodeo Rooster, Wagon Wheel Walrus, Prairie Pancake, Coyote Kazoo, Sheriff Shrimpo, Banjo Bison, Lasso Llama, Tin Star Toad |
| b3.mp3 | Canyon Capybara, Gold Pan Panda, Gold Tooth Goose, Rattlesnake Rex, Thunderhoof, Dynamo Armadillo, Steamboat Sloth, Steam Engine Stallion, Cyclone Coyote, Sunset Serpent, Golden Spur Griffin |
| b4.mp3 | Canyon Colossus, Midnight Marauder, Black Hat Badger, Phantom Rider, Dust Devil Dragon, Cloud Cowboy, La Locomotora Loca, Deputy Duck, Golden Locomotive, Diamond Desperado |
| ann.mp3 | ann_itsA "Yeeeehaw! It's...", ann_trainArriving "All aboard! The Critter Express is pulling in!", ann_goldenExpress "The Golden Express is comin' down the line!", ann_thief "Thief! Lasso 'em!", ann_frontier "New frontier, partner!", ann_weather "Weather's turnin'!", ann_strongbox "Strongbox on board!" |
