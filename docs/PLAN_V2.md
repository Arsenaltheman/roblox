# Plan v2: "complete everything" (owner, 2026-10-07)

Owner asks for:
- 10+ hours of gameplay;
- big quests;
- perfect onboarding;
- perfect build quality, graphics and movement — "every little thing".

**Honest limit:** this cloud session can't see the game render. Graphics and feel are tuned by code and by reading every number. A final pass needs the owner's screenshots.

Already true: the economy simulator runs a free player for 10 h and they are still progressing (7th Frontier at ~7.3 h, income still climbing). What's missing is **reasons and goals** for those hours, and the heist loop is outside the simulator.

| # | Work | Why |
|---|---|---|
| 1 | **The Bounty Trail:** a 10+ hour campaign. 8 chapters × 5 big multi-step quests that walk you through every system. Each chapter has a finale reward: a title, a cosmetic, spins, boosts. Plus **weekly bounties** (bigger, 5 a week) | "Quests are big"; a clear goal at every hour of the 10 |
| 2 | **Gear up to Frontier 7:** new gear every Frontier, including movement gear (Grapple Dash), a guard decoy and a lockbox alarm | Something new to unlock all the way through |
| 3 | **Movement:** sprint with stamina (server-checked, phone button), FOV kick, footstep and landing dust, carry wobble, smooth camera | "Movement… every little thing" |
| 4 | **Onboarding:** every tutorial step has a world arrow on the exact target; the HUD reveals itself step by step; the first 10 minutes are scripted and the hints never go silent | "Onboarding has to be perfect" |
| 5 | **Graphics:** a moodier lighting grade, per-zone atmosphere (Ghost Town fog, Gold Mine glow), ambient life (dust, tumbleweeds, birds, fireflies at dusk), richer zone props, ranch dressing | "Graphics have to be perfect" |
| 6 | **Simulator** models heists and Trail rewards; gates check the 10 h curve | Prove the 10+ hours |
| 7 | **Trading:** same-server escrow, policy-gated (`IsPaidItemTradingAllowed`), Frontier 1+ | Last open GAMEPLAN item |
| 8 | **Whole-codebase review** (server, client, shared), with every finding fixed | "Build quality has to be perfect" |
| 9 | Rebuild, docs, playtest checklist | |

Music still needs licensed Creator Store tracks picked by the owner; nothing can be uploaded from here without the API key.
