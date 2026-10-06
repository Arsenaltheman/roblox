# CRITTER EXPRESS — full game plan (Roblox, mobile-first, Wild West "steal" game)

> Repo: `arsenaltheman/roblox` (empty today, cloned at `/home/user/roblox`). Built as a Rojo project from this cloud session.
> Your decisions so far: **Rob-a-Train Western concept** · **upgrade Figma** · **unblock Roblox in this cloud environment** · **no art budget (I build all art)**.

## Decision log (these override anything below that conflicts)
| Date | Decision | Effect on the plan |
|---|---|---|
| 2026-10-06 | **Pay-to-win at Steal a Brainrot level** | Paid income boosts **multiply** (no shared cap). Robux gear with real steal/defend power: Golden Lasso, Speed Spurs, Iron Lock, Lockpick, Heavy Saddlebag, Bigger Ranch. **Sheriff's Star** pass (4,999 R$) unlocks server-wide Sheriff Powers (Golden Express, Summon Weather, Stampede) with a cooldown. Robux-only exclusive critters (Branded: can't be stolen, survive Frontier resets). Simulator gate changes from "payer ≤ 1.6× non-payer" to "**whale ≥ 2.5× faster than a free player**, while free pacing stays the same". Hard Roblox rules still apply: odds shown and policy gating for anything that changes random outcomes; no deceptive copy or fake timers. No paid commands that target or harm other players (griefing/harassment risk). |
| 2026-10-06 | **Theft harsher** | **Cut:** Payback (victim arrow/speed/lock bypass), bounty rewards, fair-value band, 2-robberies-per-hour cap, post-robbery immunity. **Kept:** 15-min newbie shield, Safe Pens (1 at F3, 2 at F6), Branded (Robux) critters unstealable, ranch Lock, carrying slows and glows, carry limit by Frontier. **Lasso stays as the counter**: owner lassos the carrier → critter returns home; anyone else lassos the carrier → they grab it and become the new carrier. |
| 2026-10-06 | **Active Luck meter** | Luck grows for every minute a player is active in the server (not idle) and resets when they leave. It gates rare cages (Outlaw/Secret) and multiplies with other luck; shown live in the odds panel. |
| 2026-10-06 | **Owner is AFK: no more questions** | I proceed on my own with sensible defaults, and keep a list of steps that need the owner (accounts, keys, Figma seat, playtests) in `docs/STATUS.md`. |

---

## 0. Context

You want a new Roblox game in the "Steal a Brainrot / Steal an Egg" family. It should be:
- understood in 5 seconds on a phone,
- playable for hours, and a game players return to every day,
- full of VFX everywhere, insane reveal animations and deep progression,
- built on the reward psychology that makes casinos compelling, translated into game mechanics (not gambling),
- full of customization,
- original-looking, not AI-made,
- priced in line with competitors.

You asked for competitor research first, then a hole-free plan covering game, hooks, prices, UI, VFX, art, audio, tech and bug-fixing, plus a 10-hour player journey.

**Outcome of this plan:** a launch-ready game built in 6 milestones (vertical slice first). Every system is designed around Roblox's much stricter 2026 rules, so the game can't be taken down and can reach the Kids/Select audience.

---

## 1. Research findings (Oct 2026)

### 1.1 Competitors
| Game | Loop | Peak → now | Why it blew up | What went wrong |
|---|---|---|---|---|
| **Steal a Brainrot** (May 2025) | Conveyor spawns a unit every 2–4 s → buy ($25 unit earns $1/s) → base pedestal earns $/s → steal by carrying a unit home → base lock (60 s + 10 s per rebirth) → rebirth | 25.8M players at once (Oct 2025, Roblox record) → ~200K now (−99%). About $64M in 10 months | Meme cast kids already knew from TikTok. "Steal from your friends" tension. Saturday updates plus "Admin Abuse" events. One-tap controls | Admin commands sold for 1,999→4,999 R$ and paid weapons (pay-to-win). Crying kids and school bullying in Japan. Auto-steal scripts and bots server-hopping to rare spawns. eBay real-money trading. Scams. Lawsuits against copycats over UI and art |
| **Steal An Egg** (Jul 2026, **#1 now**, ~1.9M players) | Grab eggs from NPC-guarded nests → sprint home (others can snatch them) → hatch pets that earn $/s → speed training → harder biomes | ~2M+ | Changed the core action (chase + hatch). Weekly bosses | **Taken down** for a TikTok-style "Reels" feed. Roblox now bars reward-for-watching feeds from kids' accounts |
| **Grow a Garden** (Mar 2025) | Plant → crops grow in real time, even offline → sell → shops restock every 5 min → weather mutations (2×–150×) | 22.3M → sequel only ~1M | Calm play, offline progress, restock check-ins, admin events, weather "lottery" | Scams and item duplication before official trading |
| **Dead Rails** (Jan 2025) | Western train survival | 600K+ | Proved **Western + train** works on Roblox | — |
| **Clones** | Copy the title | Mostly <50K | — | Hundreds exist; Roblox now pushes near-copies down. The successful ones (Escape Tsunami 5M, Plants vs Brainrots 9M, Steal An Egg) **changed the core action** |

**Price benchmarks (Robux):**
| Item | Price |
|---|---|
| VIP | 499 |
| 2× money | 119–399 |
| Server luck | 249 (2×) / 999 (4–5×) |
| Luck crates | 175–2,999 |
| Gear | 199–999 |
| Cash packs | 59–3,449 |
| Season pass | 749 |
| Private server | 79/mo |

### 1.2 Copy / fix / differentiate
| Copy the proven formula | Fix what players hate | Differentiate on day one |
|---|---|---|
| Verb-noun title that explains the game | Theft that makes kids cry → **Lock / Wanted / Payback** rules, newbie shield, fair-value matching, a Safe Pen that can't be stolen from | A **Western train as the "conveyor"**, with arrivals, doors, whistles and strongbox cars |
| Income per second; 8 rarity tiers; mutation multipliers; rebirth | Pay-to-win → **no paid weapons or power over other players** | **Bounty system**: a thief carrying a critter is WANTED, and anyone can lasso them for a reward |
| A visible collection that can be stolen | Bots → rare cages only for players active in the server ≥10 min; everything checked by the server | A **Reserved Cage** for each player on every train: fair pacing whoever else is in the server |
| Server-wide moments: weather, rare trains, Saturday admin events | Hidden odds → **every odds table visible** | Critters **lay eggs** at your ranch: passive surprises and a reason to return |
| One-tap controls; offline progress | Real-money trading and scams → trading only post-launch, with escrow and limits | **Own characters with voice lines** (no lawsuit risk); **Mild rating** → Kids/Select audience |

### 1.3 Roblox rules that shape everything
- **Paid random items.** Anything random obtained with Robux, or with currency that can be bought with Robux (including luck boosts and pity), must:
  - show every outcome's percentage (summing to 100%) before purchase, updated live;
  - be blocked when `PolicyService.ArePaidRandomItemsRestricted` is true (treat a failed check as restricted).
- **Trading** of paid items is gated by `IsPaidItemTradingAllowed`.
- **No manipulative selling:** no fake scarcity, no inaccurate or auto-restarting timers, no permanent "sales", no pushy copy aimed at minors. Paid cooldown skips are discouraged.
- **No in-game promotion or giveaways:** no prompts to Discord/X/YouTube, no Robux giveaways. Thumbnails must show the real game.
- **Kids (5–8) and Select (9–15) accounts** only see Minimal/Mild games. Listing also needs:
  - a verified creator with **Premium for 2 consecutive months**;
  - 250 plays from engaged, age-checked players within 60 days;
  - no reward-for-watching feeds.
- **The recommendation algorithm (June 2026) rewards:** play-through rate, players not leaving in the first 60 s or 1–3 min, **play days** (D1, D2–7, D8–28), playtime **capped at 60 min per player per day**, days played with friends, and spend days. It deliberately demotes games built on short-term monetization.
- **Benchmarks:** median D1 retention 10.3% (top 10%: 15.9%), median D7 1.6%, median session 9.8 min.
  - **Our targets:** D1 ≥ 16%, D7 ≥ 5%, D30 ≥ 2%, sessions ≥ 15 min, ≥ 2 sessions a day.
- About 80% of players are on mobile.

---

## 2. The game

### 2.1 Pitch
**"The Critter Express pulls in. Buy goofy critters from its cages. They make you money. Crack the strongboxes. Steal from other ranches — but steal and you're WANTED."**

- **Look:** stylized-premium Wild West. Golden-hour light, dust in the air, chunky readable shapes, saturated rarity colors. Realistic lighting touches, **not photoreal**: photoreal sells PC trailers but plays badly on a cheap phone.
- **Rating: Mild.** No guns, blood, alcohol or casino imagery. Lassos, cartoon stuns, a sarsaparilla saloon. **No ethnic caricatures** (no bandito/sombrero stereotypes, no Native imagery).
- **The train stops at the station.** Tapping moving targets is miserable on phones, and moving platforms jitter. It runs a 45 s cycle:
  1. Arrives (6 s).
  2. **Stands at a 100-stud platform for 20 s.**
  3. Leaves and loops behind the ranches in full view (19 s).
- **Title:** brand "Critter Express". Store title to be A/B tested before launch: **"Steal a Critter"** (matches what players search for and what they actually do) vs **"Rob a Train"**. The title must honestly match the gameplay, or Roblox demotes it.

### 2.2 Loops
| Time scale | What the player does |
|---|---|
| 45 s | Train arrives → your **Reserved Cage** opens (free roll of a critter matched to your progress) → BUY → lasso yank → critter runs home → cash ticks up |
| 1–5 min | Collect cash, buy wild cages, crack strongboxes, upgrade |
| 5–15 min | Weather event mutates critters · eggs to hatch · Golden Express countdown · steal or catch a thief |
| 20–60 min session | Wanted Board quests · **Frontier** (rebirth) → multiplier, more pens, ranch grows |
| Day | Offline earnings · eggs waiting · login streak · new quests · 5-min shop restocks |
| Week | Saturday update + live admin event · weekly leaderboards · 3 new critters |

### 2.3 Launch systems
1. **Critter Express.** A 45 s train cycle with 6 cars × 2 cages.
   - Every player present gets **one Reserved Cage**, rolled from their own progress band. The rest are **Wild Cages** open to everyone.
   - A strongbox car runs on every 3rd train.
   - Cage doors open at the same moment for everyone.
2. **Critters.** Our own Western mashup characters with chantable names and voice lines.
   - 8 rarities × 8 mutations, plus Shiny fusion, gives hundreds of collectible variants.
   - Species count grows 8 → 24 → 40 across milestones.
3. **Ranch.** 8 pens (+1 per Frontier, max 16), a collect plate, a sign with your name, and a lock plate.
   - The building grows tent → cabin → ranch house → mansion → gold palace.
   - Themes are presets with 6 decor sockets.
4. **Stealing — three visible rules:**
   - **LOCK** — the ranch can be locked for 60 s + 10 s per Frontier.
   - **WANTED** — a thief carrying a critter is slowed to 0.75× and glows; anyone can lasso them, which returns the critter and pays them a bounty.
   - **PAYBACK** — the victim gets a 60 s arrow to the thief and a speed boost, and can ignore the thief's lock.
   - Hidden safeguards: 15-min newbie shield, value band ("Too small to bother"), carry limit by Frontier, 2 min immunity after being robbed, max 2 robberies of the same victim per hour.
   - **Safe Pen:** pens that can't be stolen from (1 at F3, 2 at F6). Earned only, never sold.
   - **Branded critters** (bought with Robux) can never be stolen.
5. **Lasso.** Only targets WANTED players or bandits. Auto-aim with a 40-stud cone and a 2 s cooldown. No player collisions, so no body-blocking.
6. **Bandits (PvE).**
   - A tutorial bandit steals from you so you learn to lasso.
   - A **Bandit Camp "red-light" steal**: hold while the bandit naps, release when he peeks. This teaches stealing with no real loss.
7. **Strongboxes.** Hold 1.5 s from the platform. **Everyone gets their own loot** (cash, Nuggets, egg or cosmetic), with a visible lucky-streak meter.
8. **Eggs.** A ranch critter lays one every ~8 min of play (max 3 waiting).
   - Odds by parent rarity: same 75% / +1 22% / +2 3%, shown live.
   - Hatched in the reveal cinematic.
9. **Weather** every 12 min for 2 min: Gold ×1.5, Diamond ×2, Frosty ×2.5, Electric ×3, Molten ×4, Ghost ×5, Cosmic ×7, Rainbow ×10.
   - The event's mutation goes up to 25% on cages, and each ranch critter gets a 10% roll.
10. **Golden Express.** A rare train announced server-wide with a real countdown.
    - Outlaw/Secret cages need ≥10 min in this server, and Golden Express only runs on servers older than 15 min. This defeats server-hopping bots.
11. **Frontier (rebirth).** Requires cash **plus a critter worth ≥ $X**, so idling isn't enough.
    - Rewards: income ×(1 + n), +1 pen, a longer lock, a bigger carry limit, and one new unlock each time.
12. **Retention set.**
    - Playtime gifts at 1/3/5/10/15/20/30/45/60 min (paused when idle).
    - 7-day streak with a grace day.
    - Wanted Board daily and weekly quests.
    - **Almanac** (species × mutation) with set bonuses.
    - Offline earnings: 25% of income, 50% from F3, max 8 h.
    - Trading Post restocks every 5 min.
13. **Horses** (unlock at F2). Mobility upgrades, breeds and saddles. Can't ride while carrying a stolen critter.
14. **Friends.** Posse boost (+10% per friend, max +30%) and an invite button. Days played with friends is an algorithm signal.
15. **Customization.**
    - Ranch: theme packs, decor, banners, fences.
    - Your **WANTED poster** design (shown when you steal).
    - Horses: breeds and saddles.
    - Lasso: skins and trails.
    - Critters: hats, and nicknames from a curated word picker (Kids accounts can't type).
    - Emotes, titles, frames.
16. **Emote stickers** instead of chat (Kids accounts have chat off).

**Post-launch (live ops):**
- Trading: same-server escrow, F1+, account ≥ 7 days old, policy-gated.
- Armored Vault co-op heist.
- Bounty Pass season.
- New regions: Cactus Canyon, Gold Mine, Frostpeak, Ghost Town, Starfall Mesa.
- Critter sizes (Big/HUGE).
- Subscription; rewarded video ads (needs ≥ 2,000 monthly visitors; viewers 13+).
- Opt-in notifications (13+).

### 2.4 Rarities, odds, sample roster
| Rarity | Species tiers | Color | Wild-cage odds |
|---|---|---|---|
| Common | t1–6 | gray | 50% |
| Uncommon | t7–12 | green | 25% |
| Rare | t13–18 | blue | 13% |
| Epic | t19–24 | purple | 7% |
| Legendary | t25–29 | gold | 3.5% |
| Mythic | t30–34 | red | 1.2% |
| **Outlaw** | t35–38 | black-gold, animated | 0.25% |
| **Secret** | t39–40 | rainbow, animated | 0.05% |

- **Reserved Cage:** tier = your current tier + δ, where δ = −1/0/+1/+2/+3 with odds 30/40/22/7/1%. A δ of +2 or more glows as a **"Golden Ticket"** before the doors open.
- **Cage mutation chance:** 4%. Weights by mutation: Gold 40, Diamond 22, Frosty 12, Electric 10, Molten 7, Ghost 5, Cosmic 3, Rainbow 1.
- **Sample roster (own IP):**
  - Tumbleweed Tim, Cactus Carl, Sir Hay Bale, Pebble Prospector
  - Boots McGoat, Pickle Pete
  - Burrito Bronco, Yeehaw Yak, Rodeo Rooster
  - Sheriff Shrimpo, Banjo Bison, Lasso Llama
  - Gold Tooth Goose, Rattlesnake Rex
  - Steam Engine Stallion (half train, half horse)
  - Cloud Cowboy
  - La Locomotora Loca

### 2.5 World
- **Layout:** one compact town per 8-player server. The **station platform is the spine**, with 8 ranches on both sides. Every run is ≤ 8 s.
- **Around the edges:** Bandit Camp, Trading Post, Saloon (Wanted Board), Sheriff's Office (bounties, leaderboards), Stables, Hatchery.
- **The open-world feel** comes from canyon vistas, the train's loop through the scenery, and the golden-hour sky. New regions arrive as updates.

---

## 3. The hook design (reward psychology, done right)

### 3.1 Layered reward schedules — something good is always about to happen
| Schedule | In our game | Effect |
|---|---|---|
| **Variable ratio** (the slot-machine schedule: reward after an unpredictable number of tries) | Reserved-cage roll every 45 s · wild rarities · mutations · strongbox loot · egg outcomes | Highest, steadiest engagement |
| **Variable interval** (reward after unpredictable time) | Egg laying · Golden Express · weather mutations on your ranch | Keeps players checking in |
| **Fixed interval** | Playtime gifts · 5-min restocks · daily streak · 12-min weather | "Just a bit longer" goals |
| **Fixed ratio** | Quests, Almanac sets, Frontier requirements | Clear goals with progress bars |
| **Social** | Server banners for rare hatches · bounty chases · leaderboards · friend boost | Status, rivalry, belonging |

### 3.2 The casino's mental mechanics — what we use and what we refuse
**Used:**
- Anticipation before every reveal: train whistle, doors opening, egg wobbling in 3 beats, Golden Ticket glow.
- An escalating reveal that climbs the rarity ladder and **stops at the true result**.
- Celebration scaled to rarity.
- Constant small wins (cash pops) with occasional big ones.
- "Jackpot" moments the whole server sees.
- Streaks, loyalty titles and collection sets.
- Free "comps" (gifts, daily rewards).
- Visible lucky-streak meters that guarantee a good result eventually.

**Refused** (each is banned by Roblox, under FTC/lawsuit pressure in 2026, or predatory toward kids):
- Fake near-misses.
- Hidden odds.
- Fake timers or "only 2 left".
- Pushy copy.
- Paid randomness without odds.
- Paid power over other players.
- Expiring paid items.
- "Chasing losses": **no purchase prompt within 2 min of being robbed or getting a bad reveal**.
- Announcing anyone's Robux spending.

This is also the winning strategy in 2026: the algorithm now rewards games players return to, and demotes games that squeeze money.

### 3.3 First 15 minutes (median player)
| Time | What happens | Income | New thing |
|---|---|---|---|
| 0:00 | Spawn on the platform as the train pulls in (3 s camera move). HUD = cash $100 + goal pill + one big action button | — | — |
| 0:06 | **RESERVED: [your name]** cage opens → Cactus Carl → giant BUY $25 → lasso yank + his name shouted | $1/s | Buy |
| 0:10–0:25 | Buy 2–3 wild Commons; they run home along a golden trail | $3–4/s | Pens |
| 0:26 | Real "Departing 5…" countdown | | Train rhythm |
| 0:40 | Arrow home (6 s) → collect plate → coin fountain | +$40 | Collect |
| 1:00 | Playtime gift 1 | +$250 | Gifts |
| 1:20 | Train 2: a Gold Golden-Ticket cage (scripted for the tutorial) | ~$8/s | Mutations |
| 2:00 | Lock plate glows: "Protected 15:00" | | Lock, shield |
| 3:00 | Gift 2 = a free egg → hatch reveal, guaranteed Uncommon (disclosed) | ~$20/s | Eggs, reveal |
| 4:00 | Tutorial bandit grabs a critter and runs → LASSO button (auto-aim) → critter returns + bounty | +$150 | WANTED, lasso |
| 6:00 | Wanted Board: 3 daily quests | ~$35/s | Quests |
| 7:00 | Pens full (8/8) → new buys replace your weakest (50% refund) | ~$50/s | Replace |
| 8:30 | Bandit Camp red-light steal → carry home an above-your-level critter | | Stealing (PvE) |
| 10:00 | Gift 4: 25 Gold Nuggets + Hatchery | | Nuggets |
| 11:00 | A ranch critter lays an egg | ~$230/s | Passive eggs |
| 12:00 | Strongbox car → everyone gets their own loot | | Strongbox |
| 13:00 | Egg hatches; Almanac opens "11/40" | | Almanac |
| 14:00 | Goal pill: "Frontier 1: $614K + a $205K critter" with a progress bar | | Rebirth goal |
| 15:00 | Gift 5 · Golden Express countdown · shield ends → PvP stealing opens | **~$600/s** | PvP |

The HUD starts nearly empty. Each button pops in, with a bounce and a sound, as its system unlocks.

### 3.4 Ten-hour curve
These are first-pass simulation estimates. The real simulator in M0 re-verifies them.

| Played | Frontier | Best critter | Income/s | New |
|---|---|---|---|---|
| 0:15 | F0 | Uncommon | $600 | Quests, Nuggets, PvE steal |
| ~0:31 | **F1** (cinematic, tent → cabin) | | | Gear shop (Speed Spurs, Lasso+) |
| 1:00 | F2 | Rare | $15K | Horse, posse boost |
| 2:00 | F3 | Epic | $90K | Safe Pen 1, Canyon eggs, 50% offline earnings |
| 3:00 | F4 | Epic | $0.8M | Golden Express Outlaw cages |
| 4:00 | F5 | Legendary chase | $0.4M → | Upper-deck pens, Shiny fusion of duplicates |
| 5:00 | F5 | Legendary | $15M | Mythic eggs |
| 6:00 | F6 | | $2M → | Safe Pen 2, "Marshal" title |
| 7–8 | F6 | Mythic | $29M–125M | Weekly quest finale, Almanac tier-2 sets |
| 9:00 | F7 | Mythic | $200M | "Legend" frame, Outlaw carry |
| 10:00 | F7 | climbing back | $37M | Next goal: F8 ($1.29T + an Outlaw), ~3 h away. Saturday adds tiers 41+ |

**When the player leaves** they see what's waiting:
- "Your ranch earns up to $X while you're away (8 h cap)".
- A long-incubation egg started before leaving.
- **Tomorrow's streak reward shown**.
- Quest reset countdown (real).
- Frontier bar almost full.
- Friday admin event and Saturday update countdown.
- Almanac sets 1–2 entries from completion.

### 3.5 Economy formulas
All of these live in `src/shared/Config/Economy.luau`, shared by the game and the simulator.

| Quantity | Formula |
|---|---|
| Price of species tier t | **P(t) = 25 × 2^(t−1)** → $25 … $13.7T at t40 |
| Income | **I(t) = 1.6^(t−1) $/s** → $1 … $91M/s |
| Payback (price ÷ income) | 25 s × 1.25^(t−1) |
| Ranch income/s | Σ I × mutation × (1 + Frontier) × (1 + min(3, Σ boosts)) |
| Boosts (all additive, capped together) | VIP +0.5 · 2× Cash +1.0 · friends +0.1 each (max 0.3) · events +1.0 — **paid boosts can never stack into pay-to-win** |
| Frontier n (rebirth) cost | **3·P(Tₙ) plus a critter worth ≥ P(Tₙ)**, where Tₙ = 14 + 3(n−1) → F1 $614K · F2 $4.9M · F3 $39M · F4 $315M · F5 $2.5B · F6 $20B · F7 $161B · F8 $1.29T |
| Other | Sell refunds 50% · uncollected cash caps at 1 h per pen · bounty = min(10% of the critter's price, 300 s × lasso-er's income + $500), once per thief–victim pair per 10 min |

Numbers display as K/M/B/T/Qa…; Cash stays below 1e15 for exact maths.

---

## 4. Monetization (prices set against competitors; compliant by design)

- **Cash** is earned and also sold for Robux. Cash **never buys randomness**: cages are what-you-see-is-what-you-buy.
- **Gold Nuggets** are earned only: never sold, never boosted by Robux, never convertible.
- **Strongboxes and eggs** are free or cost Nuggets, so they are not "paid random items".
- **Robux luck** only affects **train cages** → live odds panel (with and without the boost) + PolicyService gating. Critters obtained under a Robux luck boost are flagged for the trading rules.

| Item | Type | R$ | Notes |
|---|---|---|---|
| VIP "Sheriff's Badge" | Pass | 499 | +0.5 income boost, +10 s lock, gold lasso trail, VIP tag |
| 2× Cash | Pass | 299 | +1.0 income boost |
| Auto-Collect | Pass | 149 | |
| Lucky Horseshoe | Pass | 399 | better cage odds; odds shown, policy-gated |
| Server Luck 2× / 3× / 5× (15 min, whole server) | Product | 249 / 499 / 999 | Policy-gated; announced without the buyer's name |
| Cash bags (= 10 min / 1 h / 6 h / 24 h of *your* income) | Product | 39 / 129 / 349 / 899 | Quoted when opened → always fair value at any stage |
| Starter Pack (once) | Product | 99 | Exclusive critter + 30 min 2× cash + hat; nothing random |
| Featured Critter (rotates weekly, for real) | Product | 199–1,499 | Direct purchase; income one tier above yours (useful, not game-breaking) |
| Cosmetics (horses, trails, ranch themes, emotes, poster frames) | Product | 49–599 | |
| Private server | Monthly | 79 | Stealing toggle |
| Post-launch: Bounty Pass (fixed rewards) · "Sheriff's Club" subscription · rewarded video | | 499 · 499/mo · free | |

- **Critters bought with Robux (Starter Pack, Featured) are "Branded": they can't be stolen** (gold brand badge). Nobody loses something they paid real money for.
- Everything is giftable to friends.
- Prices are read at runtime, so Roblox's price-optimization tests work later.
- Button copy says "View Item" / "See Price", never "BUY NOW!!".

---

## 5. Look & feel

### 5.1 Art direction and the "doesn't look AI-made" rules
- **A one-page style bible before any art:**
  - palette (desert orange, sky teal, rarity colors);
  - shape language (big heads, chunky limbs, round silhouettes);
  - outline thickness and corner radius;
  - fonts: **Luckiest Guy / Fredoka One** for headings, **Builder Sans ExtraBold** for numbers;
  - the lighting recipe.
- **AI images are mood-board drafts only** (ElevenLabs image models). Every shipped asset is rebuilt in Blender to the style bible.
- No AI text in images, no mixed styles, no free-model hodgepodge.
- **Icons and thumbnails are renders of the real in-game models** under one lighting rig.
- Hand-tuned motion everywhere (anticipation + overshoot, never linear). A sound on every action.

### 5.2 3D pipeline — I build it
- **Blender, running headless in this container:**
  - I script a modular kit: 3 rigs (quadruped, biped, blob) and a parts library (hats, bandanas, mustaches, boots, props). Critters are assembled from it.
  - I also build the train, station, buildings, ranch tiers, rocks and cacti.
  - I bake shared 512² texture atlases and generate LODs.
  - **I render preview images and look at them myself** before anything goes to Roblox.
- **Free CC0 kits** (Kenney, Quaternius, Poly Haven) as bases where they fit the style.
- **Budgets:**
  - ≤ 5–8k triangles per critter and textures ≤ 512².
  - Toon materials; **no SurfaceAppearance or unions**, so publishing stays automatable.
  - Mutations are color/material + particle overlays (no new meshes).
- **Animation in code.** Critters' bones are driven from Luau (bounce, waddle, squash-stretch, carried pose, celebrate). Keyframed moves are exported from Blender as Luau data. No Studio-only animation uploads.
- **Getting models into the game without Studio:**
  1. Upload FBX through Roblox's Assets API from here.
  2. Load the models by asset ID at server start.
  This is the first thing I prove works (M1 spike), with a fallback: you import a batch in Studio and export one file, about 10 min.
- **Honest limit:** script-built critters are simpler than a pro artist's. The style bible, consistent shading, great animation and voices are what make them charming.

### 5.3 UI (Figma, after your upgrade)
1. **Reference board.** You send 10–20 phone screenshots of competitor UIs (I can't download them from here). I use them for **layout patterns only, never pixels**. Steal a Brainrot's owner sues look-alikes.
   - **Keep the conventions players already know:** currency on top, ≤ 5 menu buttons down the left, one big action button above the jump button, nothing in the bottom-right thumb zone, rarity colors everywhere.
2. **Our identity:** chunky buttons with thick strokes and shine sweeps, wanted-poster paper, rope borders, brass star badges — clean, not cluttered.
3. **In Figma** I build the design system (color/type tokens, buttons, currency pills, rarity badges, cards, modals, toasts) and every screen at phone-landscape, tablet and PC sizes:
   - HUD, cage price tags, critter card, shop, **odds panel**;
   - strongbox/egg reveal, Frontier, Almanac, Wanted Board;
   - streak calendar, playtime gifts, customization, leaderboards;
   - settings (quality, reduced motion, volumes), welcome-back, loading.
4. **Then** I export 9-slice PNGs and icons → upload them → build in code with **Vide** (fast, fine-grained UI updates suited to low-end phones).
   - Screens use Scale sizing, safe-area insets and UIAspectRatioConstraint, with text ≥ 9 px.
   - A color-blind-safe rarity icon sits beside every rarity color.

### 5.4 VFX catalog ("VFX on everything")
| Moment | Effect |
|---|---|
| Train | Steam/smoke flipbooks, wheel sparks, whistle puff, doors bursting open, Golden Ticket cage glow |
| Buy | Lasso whip trail, rope beam, catch burst in the rarity color, squash on landing, golden run trail |
| Cash | Coin pops with bouncy numbers, collect fountain, combo glow, number roll-ups |
| Rarity auras | Rare sparkles → Epic swirl → Legendary light beams → Mythic flames → Outlaw dark-gold lightning → Secret rainbow shimmer |
| Mutations | Gold glitter · diamond refractions · frost mist · electric arcs · molten embers · ghost fade · cosmic stars · rainbow cycling |
| **Reveal** (eggs, strongboxes, Frontier) | World dims → egg wobbles ×3 with rising shake and pitch → cracks → rarity-ladder color climb → burst + light rays + shockwave → name card slams in → income counts up → voice callout. Common 1.2 s · Rare 2.5 s · Legendary 4 s · Secret 7 s with slow-mo. Skippable; "Quick reveal" setting; ≤ 3 flashes/s |
| Stealing | Alarm bell, red edge flash for the victim, WANTED poster slam, glowing thief trail, bounty stars, Payback arrow |
| Frontier | Sunset cinematic, ranch rebuilds in front of you, fireworks |
| Weather | Golden glitter rain, lightning, snow, heat haze + embers, meteors, rainbow arc, ghost-train fog |
| World | Dust motes, day–night with lanterns and fireflies, tumbleweeds |
| UI | Shine sweeps, bouncing badges, sunbursts behind rewards, screen-space confetti |

**Quality tiers** (Low/Medium/High/Ultra):
- The tier is chosen from device type, memory and measured frame time, and steps down automatically if frames get slow.
- Each tier sets particle rates, Highlights, post-effects and animation distance.
- Respects Roblox's Reduced Motion setting.

---

## 6. Audio
- **New Audio API graph:** player → bus faders (Music / SFX / UI / Voice / Ambience) → master. Music ducks under voice and during reveals; a volume slider for each bus.
- **SFX (~150), via ElevenLabs Sound Effects (connector works here):**
  - lasso whips, pitch-varied coins, train whistle and wheels, doors, strongbox cracks, rarity stingers, alarms, UI clicks;
  - loudness-normalized and **packed into sound atlases** to stay within Roblox's upload limits.
  - **Needs a paid ElevenLabs plan** (commercial rights). I log every prompt.
- **Voices (the meme hook):** a designed **Western announcer** ("YEEEHAW — it's… SHERIFF SHRIMPO!") plus a **chantable name line for every critter**, via ElevenLabs voice design + TTS.
- **Music:**
  - Roblox's free licensed Creator Store library at launch, as layered states: calm / train arriving / chase / Golden Express / reveal.
  - Eleven Music only if ElevenLabs confirms in writing that Roblox games are covered; their self-serve terms exclude "Studio Games".

---

## 7. Tech architecture

### 7.1 Toolchain
- **Install:** `cargo install rojo selene stylua lune` (crates.io works here). I build luau-lsp from source (cmake is installed) and run Blender headless (`pip install bpy` 4.x for Python 3.11).
- **Libraries** are vendored by git at pinned commits, because Wally's registry is blocked here: ProfileStore, Replica, Vide, CameraShaker, frktest.
- **Networking** is defined with **Blink** schemas. Zap isn't on crates.io. Fallback: a typed RemoteEvent wrapper of our own.

### 7.2 Repo layout
```
default.project.json  selene.toml  stylua.toml  .luaurc  net/game.blink
src/server/   main.server.luau (only Script) · Services/* · Adapters/ (Market, Policy, DataStore, Clock — mockable)
src/client/   main.client.luau (only LocalScript) · Controllers/* · UI/{App, Theme, Components, Screens}
src/shared/   Config/ (Species, Rarities, Mutations, Economy, Frontier, Products, Quests, Weather, Flags)
              Sim/ — PURE logic, runs in Lune: Economy, TrainClock, Manifest, Odds, StealRules, Offline,
                     Streak, Migrations, RateLimit, Rng (seeded PCG32), NumberFormat
              Net/ (generated)  Util/
vendor/       pinned libraries
assets/       ids/*.json (uploaded asset IDs) · src/ (blend, png, wav via Git LFS)
tools/        econ-sim/ · blender/ (kit, LOD, atlas, icon renders) · cloud/ (publish, Luau Execution, asset upload) · placelint/
tests/        unit/*.spec.luau (Lune) · cloud/*.luau (run on Roblox servers)
docs/         GDD · RESEARCH · ECONOMY · COMPLIANCE · ART_BIBLE · RELEASE · RUNBOOK
.github/workflows/ci.yml (lint + unit tests + sim + build; no secrets needed)
```
**About 70% of the logic lives in pure `Sim` modules** that I can test here without Roblox.

### 7.3 Server services (one line each)
| Service | Job |
|---|---|
| LiveConfig | Roblox Configs: live tuning of drop rates, prices, events, and **kill switches** without republishing |
| DataService | ProfileStore sessions, versioned schema, migrations, version guard |
| PlayerService | Join/leave, time-in-server, 10 Hz movement check (teleport, speed, fly) |
| EconomyService | The **only** place currency changes; reason codes; multiplier maths |
| RanchService | Plots, pens, income/collect, sell/replace, lock, shield, Safe Pen |
| TrainService | Train clock, cage manifests, BuyCage validation, Golden Express |
| StealService | Steal timer, carry escrow, WANTED, delivery, Payback |
| LassoService | Targeting, stun, return, bounty with anti-farming caps |
| BanditService | Tutorial bandit and Bandit Camp red-light |
| EggService | Laying, incubation, hatching, odds |
| WeatherService | Event schedule, mutation rolls |
| FrontierService | Rebirth requirements, reset, rewards |
| ProgressionService | Gifts, streak, quests, Almanac |
| ShopService | Gear, cosmetics, 5-min restock |
| MonetizationService | Passes/products, ProcessReceipt (idempotent), PolicyService gating, odds snapshots, gifting |
| GuardService | Rate limits, strikes, kicks, anomaly log |
| TelemetryService | Funnel / economy / progression / custom analytics, error hashing |
| LiveOpsService | Scheduled and admin events, announcements, weekly leaderboards |

**Client controllers:** State, Input (one context button: BUY / STEAL / LASSO / CRACK), Prompt, Train (renders from clock + manifest), Ranch/CritterRig (level-of-detail), Carry, Lasso, VFX, Quality, Camera/Reveal, Audio, UI, Tutorial.

### 7.4 Key mechanics
- **Server authority.**
  - Clients send *intents* only; the server computes every amount.
  - Every remote is schema-checked (Blink) and rate-limited (a unit test fails if any remote lacks a limit).
  - Invalid requests add strikes: >10 in a minute → kick and log, never auto-ban.
- **Train.** A pure function of (epoch, server time).
  - Clients render it every frame. **The server creates no train instances** and only checks requests.
  - Cage manifests are rolled with a seeded RNG, and the seed is logged so any bug can be replayed exactly.
- **Carrying (no dupes, no loss).** While carried, the critter stays in the **owner's** save, flagged in transit.
  - On delivery it moves between both saves in one step and both save immediately.
  - Lasso, a 60 s timeout or the thief leaving → it returns to the owner. If the owner leaves, it returns and the thief gets a consolation bounty.
- **Purchases.**
  - Receipt IDs are cached, and a purchase is confirmed only after the save completes.
  - Cash bags grant the larger of the quoted amount and a recomputed one.
- **Anti-bot.** A time-in-server rule for Outlaw/Secret cages. Doors open for everyone at the same moment.
- **Performance.**
  - Clients build critters from state, with level of detail: animate within 60 studs, simple stand-in beyond 150.
  - Shared texture atlases, ≤ 2 Highlights.
  - Targets: < 600 draw calls, ≥ 30 FPS on a low-end Android.

### 7.5 Save data (ProfileStore)
- **Contents:**
  - Cash, Nuggets, Frontier.
  - Critters: species, mutation, shiny, original-owner id, paid-random flag, in-transit flag.
  - Pens, Safe Pen, eggs, Almanac bitmasks, quests, streak, gifts, offline, gear, cosmetics, boosts.
  - Last 100 receipts, stats, settings, tutorial step, strikes, meta.
- **Versioned migrations** are tested against frozen fixtures of every old version.
- **Version guard:** an old server never overwrites newer data during Saturday rollouts.
- **Expand-then-contract** field changes.

### 7.6 Analytics
- **Onboarding funnel:** spawn → first buy → collect → egg → lasso → first steal → quest → 15 min → F1. **Headline metric: ≥ 90% of players buy within 30 s.**
- **Shop funnel.**
- **Economy:** every source and sink.
- **Custom events:** steals, reveals, quality tier, frame-time buckets, errors.

---

## 8. Testing, bug fixing, releases

### 8.1 Where each check runs
| Layer | Runs where | What |
|---|---|---|
| Format, lint, types | Here + GitHub CI | StyLua, selene, `luau-lsp analyze` (strict) |
| Unit tests | Here + GitHub CI | Lune + frktest over all `Sim/` and `Config/`: odds sum to 100.00, migrations, rate limits, steal rules, train clock, offline, streak date maths |
| **Economy simulator** | Here + GitHub CI | `tools/econ-sim` plays 500 simulated players per persona (Tapper, Optimizer, Thief, Payer, Returner) on the **same** config. Gates: F1 median 25–40 min · F3 1.5–2.5 h · reward gap p90 < 60 s in the first 15 min · payer ≤ 1.6× a non-payer at 10 h · Nuggets in/out within ±15% · no overflow or NaN |
| Build | Here + GitHub CI | `rojo build` + place lint (no unions, SurfaceAppearance or unknown asset IDs) |
| **On real Roblox servers** | **Here, after you unblock `apis.roblox.com`** | Publish to a private **TEST** place → automated smoke tests via Open Cloud Luau Execution: all services boot, migrations work against the TEST datastore, duplicate purchase receipts are rejected, cage-buy validation, steal escrow on disconnect, Frontier reset, PolicyService failure treated as restricted |
| Visual and feel | **You** (Studio + phone) | Playtest checklist per milestone. Send screenshots or screen recordings — **I can't see the game render from here** |
| Real devices | You | One low-end Android + one iPhone: FPS, memory, heat after 30 min, tap targets |

### 8.2 Production
- **Error telemetry:** server and client errors are hashed and deduplicated, then counted per version.
- **Health counters:** data-load time, receipt latency, strikes.
- **Bug reports:** an in-game "Report bug" button with a category picker plus filtered text (category only for Kids accounts).
- **I pull errors and reports from Roblox** when I work and turn them into GitHub issues.

### 8.3 How bugs get fixed
| Severity | Response |
|---|---|
| S0 (data loss, dupes, purchases) | Flip the kill switch immediately, fix the same day |
| S1 (progress blocked) | Fix within 24 h |
| Others | Fix in the Saturday update |

Every fix starts with a failing test or a scripted repro, then: fix → checks → TEST place → phone check → release.

### 8.4 Release train
1. Changes land on TEST all week.
2. Friday: you playtest.
3. Saturday: the exact build that passed goes LIVE, after your "ship it" in chat, or you publish it from Studio. It's tagged `live-YYYY-MM-DD`.
4. **Rollback** = republish the previous tag (≤ 5 min) + kill switches. Saves are safe thanks to the version guard.

---

## 9. Milestones (≈10 weeks to soft launch; depends on your playtest/upload time)

| # | Scope | Done when | You do |
|---|---|---|---|
| **M0 Foundations** (wk 1) | Commit this plan + research to `docs/`; toolchain; repo skeleton; CI; ProfileStore + migrations; LiveConfig; telemetry skeleton; **economy simulator v1** (re-verifies §3.4); **style bible + concept mood board**; first Figma design-system pass | CI green; `rojo build` works; sim gates pass; TEST publish + a "boot" smoke test pass on Roblox; you approve the style bible | Setup checklist (§10) |
| **M1 Buy & Earn** (wk 2–3) | Station + client-rendered train, Reserved/Wild cages, 8 ranches, 8 species, buy/collect/sell/lock, offline earnings, HUD, tutorial to 3:00, **one hero reveal**, 10 SFX + 1 track, quality tiers, **asset-upload spike** | 4 of 5 fresh testers buy within 30 s unaided; ≥ 30 FPS on a low-end Android; 30-min run without errors; saves persist; first 15 min within ±20% of the sim | First phone playtest; HUD review in Figma |
| **M2 Steal & Lasso** (wk 4–5) | Steal, carry escrow, WANTED, lasso, bounty, Payback, shield, value band, carry limit, Bandit Camp, tutorial bandit, movement checks, rate limits | Multi-player test correct at 250 ms lag; exploit suite rejected (speed, teleport, remote spam, stealing a locked ranch, disconnect mid-carry); victims rate it ≥ 3/5 | Lead a 3–4 player playtest (friends/family) |
| **M3 Juice & Retention** (wk 6–7) | Weather + mutations, strongboxes, Golden Express, eggs + Hatchery, all reveal tiers, announcements, gifts, streak, quests, Almanac, F1–F8, 24 species, critter voices | Sim gates pass; reward gap < 60 s in the first 15 min; reveals ≥ 30 FPS on Low; ≥ 6/10 testers say they'd come back tomorrow | Approve the audio pack; decide on music |
| **M4 Money & Compliance** (wk 8) | Passes/products at the §4 prices, receipts, **live odds panel** + PolicyService gating, paid-random flag, copy review, stickers, settings + accessibility, **localization** (Roblox auto-translate + text-expansion-safe UI) | Duplicate-receipt test passes; forced-restricted test hides luck products; odds total 100.00; compliance checklist done | Create passes/products in Creator Hub (I give exact names, prices, icons); fill the Maturity & Compliance questionnaire (Mild, paid random items declared) |
| **M5 Soft launch** (wk 9–10) | 40 species, theme packs + cosmetics, leaderboards, performance pass, real in-game thumbnails + icon A/B, 50-player beta → public | D1 ≥ 16% over ≥ 1,000 new players; median session ≥ 15 min; < 25% leave within 60 s; crash rate < 1%; no open S0/S1 | Pick the title from the A/B test; optional Roblox ads budget; approve the LIVE publish |
| **M6+ Live ops** (weekly) | Every Saturday: 3 species + a mutation or event + an admin event. Then trading, Armored Vault heist, Bounty Pass, new regions, subscription, rewarded video | D7 ≥ 5%, D30 ≥ 2%, ≥ 2 sessions a day | Friday playtest, Saturday "ship it", host admin events |

---

## 10. Your setup checklist (Phase 0)
1. **Roblox account.**
   - Turn on 2-step verification and complete ID/age verification (for upload limits and future features).
   - **Start Roblox Premium now**: Kids/Select listing needs 2 consecutive months.
2. **Create a Roblox group** to own the game (recommended), plus two experiences under it:
   - `Critter Express [TEST]`, kept private;
   - the LIVE one, private until launch.
   - In TEST, turn on Studio access to API services.
3. **Create an Open Cloud API key** (Creator Dashboard → Open Cloud → API Keys). Scope it to the **TEST experience only** at first:
   - place publishing (write), Luau execution sessions (read/write), assets (read/write), data stores and memory stores (read/write), configs, messaging;
   - IP 0.0.0.0/0, because this cloud environment's IP changes;
   - expiry 90 days.
4. **In this cloud environment's settings** (environment menu in the session title bar → Edit):
   - add environment variables `ROBLOX_API_KEY` (the key — **never paste it in chat**), `ROBLOX_UNIVERSE_ID`, `ROBLOX_TEST_PLACE_ID`;
   - set Network access to **Custom** and add `apis.roblox.com` (required). Optional: `create.roblox.com`, `devforum.roblox.com` (docs), `kenney.nl`, `polyhaven.com`, `dl.polyhaven.org` (free asset kits);
   - **then start a new session** in this repo. Settings only apply to new sessions. Steps: https://code.claude.com/docs/en/cloud-environments#network-access
5. **Figma:** upgrade to a paid plan with a **Full seat**, and tell me which team/project to use.
6. **ElevenLabs:** confirm you're on a **paid plan** (needed for commercial use). Budget credits for ~150 SFX and ~60 voice lines, plus some concept images.
7. **Send 10–20 phone screenshots** of competitor UIs (Steal a Brainrot, Steal An Egg, Grow a Garden, Pet Simulator 99).
8. **On your PC:** Roblox Studio + the Rojo plugin. One phone for testing, ideally plus a low-end Android.
9. **Optional later:** run Claude Code on your PC with Studio's built-in MCP so I can see and drive Studio directly (best for VFX polish).
10. **Your time:** roughly 3–5 h/week for playtests, uploads and decisions.

**Costs to expect:**
- Figma paid seat during the UI phase.
- ElevenLabs paid plan.
- Roblox Premium.
- Optional ads.

Creating passes, products and audio uploads is free.

---

## 11. Risks, unknowns and how each gets closed
| Risk / unknown | Plan |
|---|---|
| Models uploaded by API may not load cleanly without Studio (skinned meshes) | **M1 spike** in the first days; fallback = you import batches in Studio (~10 min each) |
| Script-built critters less charming than a pro artist's | Style bible, modular kit, strong animation and voices; swap in artist work later if revenue allows |
| I can't see the game render | Blender renders and Figma frames I can see; your screenshots/recordings each milestone; optional Studio MCP later |
| Luau Execution limits (datastore access, timeouts) | Verify in M0; fallback = Studio test script you run with one click |
| Blink compiler under Lune | Verify in M0; fallback = our own typed remote wrapper |
| Eleven Music licence | Creator Store music at launch |
| Audio upload limits (100/month via API) | Sound atlases; batch uploads |
| Genre fatigue / launch spike then crash | Built for D8–28 retention: offline + eggs + streak + weekly updates + friends; no reliance on a single meme |
| Copycat lawsuits / IP | Own characters, own UI skin; trademark check on the final title |
| Kids/Select eligibility timing | Premium started in M0; Mild rating; no feeds; curated nicknames |
| Scope creep | Launch scope fixed (§2.3); everything else is live ops |
| GitHub may refuse pushes of workflow files from this session (permission scope) | If refused, all checks still run here before every push; you can add the CI file later in one click |
| Large art source files (Blender) bloat the repo | Git LFS for binaries; keep sources lean (GitHub's free LFS quota is limited); exported game assets live on Roblox |

---

## 12. Verification (how we'll know it works)
- **Every change:** format, lint, type check, unit tests, the economy-simulator gates and `rojo build` all pass, here and in GitHub CI.
- **Every TEST publish:** Luau Execution smoke tests pass on real Roblox servers (boot, saves, receipts, steal escrow, policy gating).
- **Every milestone:** your playtest on phone and PC against that milestone's "Done when" column (§9); FPS and memory on a low-end Android; screenshots reviewed.
- **Soft launch:** Creator Analytics vs targets — D1 ≥ 16%, session ≥ 15 min, < 25% early quits, crash < 1%. Then D7 ≥ 5% and D30 ≥ 2% during live ops.

**First actions after you approve:**
1. Commit this plan and the full research (with sources) to `docs/` in `arsenaltheman/roblox` (first commit on `main`, since the repo is empty).
2. Install the toolchain and build the M0 skeleton and economy simulator.
3. Generate the style-bible mood board.
4. Start the Figma design system once your seat is upgraded.

Anything that needs Roblox's servers waits for the new session after your §10 setup.
