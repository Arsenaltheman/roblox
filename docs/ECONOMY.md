# Economy

All numbers live in `src/shared/Config/*.luau`. The formulas live in `src/shared/Sim/Economy.luau`. The game and the simulator read the same files, so the simulator tests exactly what ships.

## Formulas
| What | Formula |
|---|---|
| Critter price, tier t | 25 × 2^(t−1): $25 at t1, $205K at t14, $13.7T at t40 |
| Critter income | 1.6^(t−1) $/s: $1 at t1, $450 at t14, $91M at t40 |
| Ranch income | Σ(income × mutation) × (1 + Frontier) × (1 + free boosts, capped at +1.3) × paid multipliers |
| Paid multipliers (they multiply) | 2× Cash ×2 · VIP ×1.5 → ×3 together |
| Frontier n (rebirth) | 6 × price(T) cash **plus** owning a critter of tier ≥ T, where T = 14 + 3(n−1), capped at 40. Past the cap, each Frontier costs 4× more (endless prestige until new tiers ship) |
| After a Frontier | Cash resets to cost/1000 (min $100). Critters reset except **Branded** (Robux) ones. Income ×(1 + n), +1 pen |
| Reserved cage | Your band tier + {−1, 0, +1, +2, +3} at 30/40/22/7/1%. Luck (Active Luck × Lucky Horseshoe × Server Luck) boosts the upgrade chances as √luck |
| Active Luck | 1 + 0.04 per active minute in this server, max ×2.2. Resets when you leave. Outlaw cages need 10 active minutes, Secret 20 |

## Simulated pacing (200 players per persona, 10 h of play)
Run it yourself: `lune run tools/econ-sim/main`. The full output is written to `tools/econ-sim/out/summary.md`.

**Free player ("Tapper"):** collects every 2 min, catches 80% of trains, buys wild cages half the time.

| Rebirth | Median time | p10–p90 |
|---|---|---|
| F1 | 29 min | 22–34 min |
| F2 | 58 min | 45–61 min |
| F3 | 94 min | 83–101 min |
| F4 | 2.4 h | 2.2–2.6 h |
| F5 | 3.5 h | 3.2–3.7 h |
| F6 | 5.1 h | 4.7–5.4 h |
| F7 | 7.3 h | 6.8–7.8 h |

Income checkpoints for the free player (median):

| Time played | Income/s |
|---|---|
| 15 min | $556/s |
| 1 h | $12K/s |
| 2 h | $289K/s |
| 5 h | $47M/s |
| 10 h | $1.5B/s |

**Whale** (every pass, all exclusives, Server Luck ×3 running): F3 in **14 min**, about **6.6× faster** than a free player. They keep progressing through endless Frontiers rather than running out of game.

**Returner** (45 min a day for 14 days, collecting offline earnings): reaches F10 by day 14. Coming back daily beats one long binge.

**Other results**
- A reward lands at least every 45 s (p90) during the first 15 minutes.
- Gold Nuggets are spent as fast as they're earned (98%), so they don't pile up.
- No run produced NaN or infinite values.

## Gates (checked on every change)
| Gate | Target | Result |
|---|---|---|
| Free player's first rebirth (F1) | 25–40 min | 29 min ✅ |
| Free player's third rebirth (F3) | 1.5–2.5 h | 94 min ✅ |
| Optimizer's F1 isn't absurdly fast | ≥ 18 min | 24 min ✅ |
| Reward gap in first 15 min (p90) | < 60 s | 45 s ✅ |
| Pay-to-win is strong | Whale ≥ 2.5× faster | 6.6× ✅ |
| Pay-to-win sanity | Whale ≤ 10× faster | 6.6× ✅ |
| Nuggets don't pile up | spent ≥ 85% of earned | 98% ✅ |
| No broken maths | 0 NaN/inf runs | 0 ✅ |

## Tuning history
| Change | Why |
|---|---|
| Frontier cost multiplier 3 → 6 | Free players hit F1 in 20 min and F3 in 74 min, too fast for the plan |
| Exclusive critter tier bonus +1/+3/+5 → 0/+1/+2 | Whales reached F3 in 5 min and maxed every tier in about 2 h |
| Quest cash 300 s → 120 s of income; 15-min gift 300 s → 150 s | The 20-min quest pushed almost every player over F1 at exactly 20 min |
| Endless Frontiers past tier 40 (×4 cost each) | Whales hit a hard wall at F9 with nothing left to do |
| Cash ceiling 1e15 → 1e30 | Needed for the endless Frontiers; the ceiling is only a runaway-bug guard |

## What the model simplifies
- Other players are modeled as a 50% chance of beating you to a wild cage. Robberies are one attempt every 12 min with 50% success.
- Thieves succeed 45% of the time, once every 4 min.
- Quests are modeled as one every 20 min.
- Egg hatching is instant in the model; in game it takes 2 min.

These assumptions get replaced with real numbers from analytics after the beta.

## The Bounty Trail against the curve
The Trail (`src/shared/Config/Trail.luau`) has 8 chapters. Chapter n ends at Frontier n, so a free player finishes chapter 7 around 7.2 h and the last chapter around 9.4–10+ h (F8 in the table above). Its checked goals sit inside the simulated curve:

| Goal | Chapter (ends at) | Simulator says |
|---|---|---|
| $300K/s | 4 (F4, ~2.4 h) | $344K/s at 2 h |
| Own a Legendary (t25) | 5 (F5, ~3.4 h) | best tier t25 at 3 h |
| $40M/s | 6 (F6, ~5.1 h) | $47.5M/s at 5 h |
| Own a Mythic (t30) | 7 (F7, ~7.2 h) | t30 at 5 h |

The counted goals (80 heists, 6 Bandit King wins and so on) add play on top.

The simulator does **not** model heist income yet, so real progress is a little faster than this table. The Trail's heist and boss counts make up for that in time played.
