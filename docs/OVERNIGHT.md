# Overnight build plan (2026-10-06 → 07)

The owner is asleep and can't answer questions, so everything below is decided here and built in this order. Each step:
1. is finished with `scripts/check.sh` all green;
2. is committed and pushed to `main`;
3. gets its status ticked here.

Nothing is published to Roblox: that still waits for the owner's "ship it".

| # | Work | Why | Status |
|---|---|---|---|
| 1 | **Store redesign.** Tabs: Passes · Boosts · Cash · Critters · Gear · Nuggets. Picture cards with price tags and OWNED/LOCKED badges. Tap a card for a big preview with an effect that matches the item (coin shower, speed lines, clovers, shield pulse, smoke, rolling tumbleweed, trap snap, rarity beam with a live 3D critter, egg wobble) | Owner: "sort the store… display the product with a picture and a really cool effect" | ✅ |
| 2 | **Gear in play.** Hotbar: keys 1/2/3 and touch buttons, cooldown sweep, owned only. World effects for smoke, tumbleweed, trap set/snap, gear bought, crate drop, spin earned | Gear can be bought but has no buttons yet | ✅ |
| 3 | **Server events** about every 25 min with a real countdown banner: **Crate Rain** (bonus crates fall around town), **Gold Rush** (2× cash for 5 min), **Jackpot Restock** (every nest refills one rarity higher) | Steal a Brainrot's "admin abuse" moments; gives everyone a reason to stay | ✅ |
| 4 | **Bandit King boss** in Ghost Town: shared health bar, the whole server lassoes him, everyone who helped gets loot | Steal An Egg's weekly-boss hook | 📅 |
| 5 | **Station leaderboards:** richest ranch, most heists, most critters stolen. In-world boards plus a top-3 statue podium | Status and rivalry | 📅 |
| 6 | **Almanac set bonuses** (+income for each completed rarity set) and **timed boosts** (2× luck / 2× cash potions from the wheel and quests) | Long-term goals | 📅 |
| 7 | **Bug sweep:** read every service and controller for nil errors, leaks and exploit gaps. Rebuild `build/CritterExpress.rbxl`. Write the morning summary and a playtest checklist in `STATUS.md` | So the morning playtest goes smoothly | 📅 |

Rules that stay in force:
- Robux never buys wheel spins or Nuggets.
- Every random paid thing shows odds.
- No fake timers.
- Our own art only: generated icon sheets made for this game, Blender, or 3D critters in a ViewportFrame.
