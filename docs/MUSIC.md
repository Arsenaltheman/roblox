# Music: picking the tracks

The game ships with a working music system and **no tracks**. Every music id in
`src/shared/Config/Sounds.luau` is `""`, which plays silence (no errors). This page tells you how to
pick licensed tracks in Studio and where to paste their ids. It takes about 20 minutes.

## How the music works

`src/shared/Config/Music.luau` + `src/client/Controllers/Sound.luau`:

| State   | When                                                                  | Slots                      |
|---------|-----------------------------------------------------------------------|----------------------------|
| `calm`  | Normal play in town (also from second 1 of the intro)                 | `musicCalm1..3`            |
| `menu`  | Shop, eggs, wardrobe, trade, quests, almanac, settings open           | the calm tracks, quieter   |
| `tense` | Carrying a heist crate or a stolen critter (`HeistCarry`/`CarryingFrom`) | `musicTense1..2`        |
| `event` | A server event is running (`EventId`)                                 | `musicEvent1..2`           |
| `boss`  | The Bandit King is on the map (`BossActive`)                          | `musicBoss1`               |

Highest priority wins: boss > tense > event > menu > calm. Tracks loop, each state picks a random
slot (never the same one twice in a row), states crossfade over 1.5 s and a state must hold for 2 s
before the music follows it, so dropping and re-grabbing a crate never restarts the song. Reveals,
voice lines and stingers duck the music by 8 dB (back in 1 s). Stingers (heist delivered, Frontier,
chapter complete, event start, boss spawn) reuse existing sound keys; see `Music.stingers`.

A slot with an empty id is simply skipped. If a whole state has no track, that state is silent, so
fill the `calm` slots first.

## Picking tracks in Studio (licensed, free)

1. Open the place in Roblox Studio. **View → Toolbox**.
2. In the Toolbox pick **Creator Store** (the shop icon), category **Audio**, then the **Music** tab.
3. Tick the filters so only licensed music shows: **Roblox-licensed** (the APM / Roblox music library;
   everything there is cleared for use inside Roblox experiences). Searching also works: try
   `western`, `country acoustic`, `banjo`, `saloon`, `harmonica`, `chase`, `drums tension`.
4. Press play on a result to preview it. Right-click → **Copy Asset ID** (or insert it, then read the
   `SoundId` off the inserted Sound and delete the Sound).
5. The id goes into `src/shared/Config/Sounds.luau` as `id = "rbxassetid://1234567890"`. Keep the
   `bus = "music"` and `volume` values. Example:

   ```lua
   musicCalm1 = { id = "rbxassetid://1838457617", bus = "music", volume = 0.4 },
   ```

6. Play-test in Studio: walk around (calm), open the shop (same song, quieter), grab a heist crate
   (tense after 2 s), trigger an event with the Sheriff powers (event). Check nothing clips against
   the whistle and the voice lines; lower `volume` on a slot if a track is hot.
7. Commit. The id is a public asset reference; nothing is uploaded from this repo.

Rules: only use audio from the Roblox-licensed library or tracks you own. Private uploads from the
Toolbox by other creators are not licensed to you. Do not use Eleven Music until ElevenLabs confirms
Roblox games are covered (their self-serve terms exclude "Studio Games", see docs/RESEARCH.md).

## What each slot wants

Think Saturday-morning cartoon Wild West: friendly, bright, never gritty. Loops must sit under
voice lines, so avoid lead vocals and big dynamic swings.

**`musicCalm1`, `musicCalm2`, `musicCalm3` (town, intro, menus)**
90–110 BPM, major key. Acoustic guitar strumming, banjo picking, whistling, harmonica, light brushed
drums or hand claps. Think "lazy afternoon on the porch". Pick three that differ a little (one
guitar-led, one banjo-led, one with whistling) so an hour in town does not feel like one song.
Length 1.5–3 minutes; clean loop points matter more than melody.

**`musicTense1`, `musicTense2` (carrying a heist crate / a stolen critter)**
130–150 BPM. Galloping drums (train-beat snare, floor tom), muted guitar chugs, a fast fiddle or
harmonica line, maybe a tambourine. Urgent but fun, like a cartoon chase. Should still sound cheerful
when it is cut off mid-phrase by the 1.5 s crossfade back to calm.

**`musicEvent1`, `musicEvent2` (server events: Golden Express, weather, stampede)**
120–140 BPM. Brass (trumpet, trombone) and fiddle, saloon piano, honky-tonk energy. Celebratory,
"the whole town is out in the street". Pick one brighter (brass) and one more rustic (fiddle).

**`musicBoss1` (Bandit King)**
80–100 BPM. Low drums (taiko-ish toms, slow kick), bass, sparse twangy guitar stabs, a whistle or
mouth-harp motif. Spaghetti-western standoff, kept playful: a bit of menace, no horror. One track
is enough; the boss is on the map for a few minutes at most.

## Volume reference

Track volumes (`volume` in Sounds.luau) are set so a loop sits at roughly -14 LUFS under the sound
effects; the player's Music slider (0–100 % in 25 % steps) then scales the whole music bus. Voice
lines and reveals duck the music to about 40 %. If a chosen track is noticeably louder than the
others, lower its `volume` by 0.05–0.1 rather than touching the duck or the bus.
