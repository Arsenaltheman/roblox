# Redesign: Steal-a-Brainrot loop, original meme characters

Owner decisions (2026-10-06), after seeing the first build in Studio:
- **The first build felt bad:** soulless, no fun, no music, no cool UI or VFX, no lobby, and too much like a tycoon.
- **Core loop:** the Steal a Brainrot loop.
  - Characters walk down a carpet or conveyor. You buy one, it walks to your base and earns money, and others run in and steal it.
  - The base is a simple row of pedestals. Nothing to build or upgrade in the house.
- **Style:** our *own* absurd meme "brainrot" characters with loud names and voices.
  - We do **not** use any existing brainrot character, name, art or the "Steal a Brainrot" name or UI skin. Its owner sues look-alikes and Roblox demotes copies.
- **Workflow:** from now on, work happens in Claude Code on the owner's PC, connected to Roblox Studio through Studio's built-in MCP server.
  - That way every change is played and screenshotted before it's called done. The first build was made blind, and that's the main reason it failed.

## What changes
| Old (Critter Express) | New |
|---|---|
| Western town, train arriving every 45 s | One bright, loud map: a long carpet down the middle with bases on both sides; spawn lobby at one end |
| Train cages, Reserved Cage | Characters walk the carpet one after another; price tag and rarity over each head; tap to buy |
| Ranch that grows (tent → palace), pens | A base = row of glowing pedestals + a laser door you can lock; more pedestals on rebirth only |
| Lasso, WANTED, bandit camp | Steal: walk into another base, grab a character off a pedestal, run it home. Hit or slap to make a carrier drop it. Lock is the main defense |
| Western critters | Original meme characters (roster below), each with a shouted name voice line |
| Strongboxes, eggs, almanac, quests at launch | Cut for launch. Keep: rebirth, luck and weather mutations, admin-style server events, daily gift |

## What we keep
- **Server code:** server authority, ProfileStore saves and migrations, receipts, rate limits and Guard.
- **Monetization and compliance:** the products, the live odds panel, and PolicyService gating for paid luck.
- **Simulator:** the economy simulator and pricing curves, retuned.
- **Pipelines:** the audio pipeline and the cloud publish/upload tools, CI and the checks.

## Original character roster (draft, to design in Blender and test on screen)
Absurd object-and-animal mashups with sing-song Italian-style names. **All of these are invented here; check each against existing brainrot memes before shipping.**

| Rarity | Characters |
|---|---|
| Common | Spaghettini Scooterini (spaghetti on scooter wheels), Pomodoro Paracadutino (tomato with a parachute) |
| Uncommon | Frigorino Pinguino (fridge penguin), Sandalo Giraffone (giraffe in sandals) |
| Rare | Toastoro Turbino (toaster bull with a jet engine), Lavatrice Leonessa (washing-machine lion) |
| Epic | Autobusso Banano (banana-shaped bus), Mozzarello Motorello (mozzarella motorbike) |
| Legendary | Gelatone Gorillone (ice-cream gorilla) |
| Mythic | Ciambella Cosmonauta (donut astronaut) |
| Secret | one per update, hinted in events |

## Feel checklist (each must be seen working in Studio)
- [ ] **Music from second 1.** The carpet loop track, plus a hype track during events (licensed Creator Store tracks).
- [ ] **Lobby or spawn moment:** a short fly-over of the map, then a big "BUY YOUR FIRST ___!" prompt.
- [ ] **Buying:** cash pop, character shouts its name, walks to your base with a trail.
- [ ] **Base:** pedestals glow in rarity colour, a money counter ticks up on each, collect plate with a coin burst.
- [ ] **Steal:** alarm, red screen edge for the victim, thief glow, a big STOLEN! banner on success.
- [ ] **UI:** big chunky buttons, bright gradients, bouncy, readable on a phone. Nothing tiny.
- [ ] **Rebirth:** full-screen celebration.
- [ ] **Server events:** visible countdown, weather or luck takeover, everyone sees it.
