# Critter Express

A mobile-first Roblox game (working title). It's in the "steal" genre, set in the Wild West.

> The Critter Express pulls in. Buy goofy critters from its cages. They make you money. Crack the strongboxes. Steal from other ranches — but steal and you're WANTED.

**Status: Milestone 0 (foundations).** Nothing is playable yet.

## Docs
| File | What it is |
|---|---|
| [`docs/PLAN.md`](docs/PLAN.md) | The full game plan: design, hooks, prices, art, audio, tech, testing, milestones |
| [`docs/RESEARCH.md`](docs/RESEARCH.md) | Competitor research, Roblox 2026 rules and tooling facts, with sources |

## How the project is built
- The code is a [Rojo](https://rojo.space) project. Everything that ends up in the place lives in this repo.
- Most of the game logic is plain Luau with no Roblox dependencies, kept in `src/shared/Sim`. It is unit-tested headlessly with [Lune](https://lune-org.github.io/docs).
- An economy simulator in `tools/econ-sim` plays thousands of simulated players. It checks that progression pacing hits the targets in the plan.

Setup steps for Studio will be added here once the project skeleton lands.
