# Critter Express: game plan (what we take from the winners, and the build order)

Owner's direction (2026-10-06): keep the Wild West theme, use the **Steal An Egg** loop (go out, grab from guarded spots, run it home, don't get caught), take **lots** of proven ideas from **Steal a Brainrot** and the other hits, and make the shop actually work.

Rules:
- Copy **mechanics and feel**, never characters, art, names or UI skins. Steal a Brainrot's owner sues look-alikes; see `RESEARCH.md` §1.1.
- No paid randomness without odds, no fake timers.

Status: ✅ built · 🔨 being built now · 📅 next · 🧊 later.

## 1. Ideas from the winners → our version

### From Steal a Brainrot (25.8M peak; the core "steal" loop)
| Their mechanic | Our version | Status |
|---|---|---|
| Conveyor spawns units to buy | The train arrives every 45 s with cages (Reserved + Wild) | ✅ |
| Base earns $/s per unit, collect plate | Ranch pens (raised pedestals, rarity glow, +$/s tags) | ✅ |
| Steal from unlocked bases, carry slows you, hit to drop it | Steal from ranches; lasso the carrier to take it | ✅ |
| Base lock: 60 s + 10 s per rebirth | Ranch lock plate; Frontier and the Iron Lock pass extend it | ✅ |
| **Rebirths**: cash + specific units; more income, longer lock, more floors, new gear | **Frontiers**: cash + a critter of a set rarity → income multiplier, +pens, longer lock, **new gear unlocks** | ✅ core · 🔨 gear unlocks |
| **Coin-shop gear** gated by rebirth: speed coil, invisibility cloak, … laser bypass | **Gear shop** (cash): Smoke Bomb, Tumbleweed Bomb, Bear Trap, unlocking by Frontier | 🔨 |
| Rarity ladder up to Secret and OG | Common → Secret (8 tiers, 40 species + exclusives) | ✅ |
| Mutations (Gold … Rainbow …) | 8 mutations, weather-driven | ✅ |
| **"Admin Abuse" live events** | **Server events** every ~25 min with a countdown: Crate Rain, Gold Rush, Jackpot Restock | ✅ |
| Server luck products | Server Luck ×2/×3/×5 (odds shown, policy-gated) | ✅ |
| Lucky blocks (paid random) | Not copied: paid random boxes are a compliance risk for kids | ❌ skipped |
| Index / collection | Almanac with rarity set bonuses (+5% income per completed set) | ✅ |
| Saturday updates | Weekly content drops: species, a zone, an event | 📅 process |

### From Steal An Egg (#1 in July 2026; the active run)
| Their mechanic | Our version | Status |
|---|---|---|
| Grab eggs from NPC-guarded nests | **Heist zones**: crates on nests, posse guards | ✅ |
| Sprint home while others try to snatch it | Gold arc home; others lasso the crate off you | ✅ |
| Speed training to reach harder biomes | **Speed Boots** (10 levels; the panel shows which zones you can outrun) | ✅ |
| Harder biomes with better eggs | Cactus Flats → Rattlesnake Canyon → Gold Mine → Ghost Town | ✅ |
| Hatch eggs into pets | Eggs + Hatchery with reveal cinematics | ✅ |
| **Weekly bosses** | **Bandit King** boss raid in Ghost Town (server co-op, big loot) (a server event, about every hour or two) | ✅ |

### From Grow a Garden (offline progress and check-ins)
| Their mechanic | Our version | Status |
|---|---|---|
| Offline growth | Offline earnings (25–50%, 8 h cap) | ✅ |
| Shop restocks every 5 min | Trading Post restock | ✅ |
| Weather mutations (2×–150×) | Weather events every 12 min | ✅ |
| Admin abuse before updates | Server events (see above) | ✅ |

### From Pet Simulator 99 and others (retention)
| Mechanic | Our version | Status |
|---|---|---|
| Daily rewards, streaks | 7-day streak, playtime gifts | ✅ |
| Free daily spin | Prize Wheel (free spins only, never sold) | ✅ |
| Quests | Wanted Board daily quests | ✅ |
| Leaderboards in the world | Boards for Richest (with a gold statue of the #1), Top Heisters, Most Wanted; this server + all-time | ✅ |
| Subscription (Roblox Subscriptions) | **Sheriff's Club** 199 R$/mo: x1.25 cash, +1 daily spin, Club Stetson | ✅ |
| Timer skips (9 R$ instant hatch, common in the genre) | **Instant Hatch** 9 R$ on any waiting egg | ✅ |
| Premium perks (Roblox pays for Premium playtime) | x1.1 income + Premium Top Hat | ✅ |
| Group-join reward | +100 Nuggets once (owner sets the group id) | ✅ |
| Trading | Same-server escrow trading: invite a player (MORE → TRADE), up to 6 critters + Gold Nuggets per side, both READY → 5 s countdown, server swaps atomically. Frontier 1+, 7-day accounts, PolicyService-gated; Branded and Robux-luck critters excluded | ✅ |
| Potions / boosts | 2x Cash for finishing all daily quests; Luck Potion for beating the Bandit King | ✅ |
| Image-based, chunky UI | Icon set + gold titles, stripes, mascots | ✅ (icons appear after upload) |

### The "wow" layer (our own)
| What | Status |
|---|---|
| Login cinematic (fly-over, fireworks, title slam) | ✅ |
| Rarity sky beams, speed lines, fireworks, screen shake | ✅ |
| Announcer and critter name voice lines | ✅ (silent until upload) |
| Music | 📅 needs licensed tracks picked in Creator Store |

## 2. Build order
1. 🔨 **Shop works**: Studio test purchases now; live purchases need the IDs (section 3).
2. 🔨 **Gear shop** (cash, unlocks by Frontier):
   - **Smoke Bomb**: guards lose you, plus a speed burst.
   - **Tumbleweed Bomb**: stuns nearby players and guards.
   - **Bear Trap**: placed at your gate; the first thief to step in is stunned and drops the loot.
3. 🔨 **Server events** with a countdown banner:
   - **Crate Rain**: bonus crates fall around town, first to grab wins.
   - **Gold Rush**: 2× cash for 5 min.
   - **Jackpot Restock**: every heist nest refills one rarity higher.
4. 📅 **Bandit King boss** in Ghost Town.
5. 📅 **Leaderboards** at the station.
6. 📅 **Almanac set bonuses** and **timed boosts**.
7. ✅ **Trading** (same-server escrow).

## 3. Making Robux items purchasable live (owner steps)
Roblox only sells an item once it exists in Creator Hub, and only the owner can create it.
1. In Studio: **File → Publish to Roblox** (to your TEST experience).
2. Go to Creator Hub → your experience → **Monetization**:
   - create each **Pass**;
   - create each **Developer Product**.
   `python3 tools/cloud/create_products.py --list` prints the exact names, prices and descriptions.
3. Give the IDs to a Claude session, or run `python3 tools/cloud/create_products.py --set VIP=123 DoubleCash=456 ...`.
4. **Sheriff's Club** (monthly subscription, 199 R$): Creator Hub → Monetization → **Subscriptions** → create it with the name and benefits from `--list`, then `python3 tools/cloud/create_products.py --subscription <id>`.
5. Optional **group reward**: make a Roblox group for the game, then `python3 tools/cloud/create_products.py --group <groupId>`. Members claim +100 Nuggets once under MORE.
6. Republish. Purchases are then real.

Until then, in Studio every item can be "bought" for free as a labelled **STUDIO TEST**, so their effects can be tested.
