# Critter Express

A mobile-first Roblox game (working title). It's in the "steal" genre, set in the Wild West.

> The Critter Express pulls in. Buy goofy critters from its cages. They make you money. Crack the strongboxes. Steal from other ranches — but steal and you're WANTED.

**Status:** the whole game is written and checked headlessly, but it has not run on a real Roblox server yet. See [`docs/STATUS.md`](docs/STATUS.md) for what's done and the owner steps that unlock publishing and testing.

## Docs
| File | What it is |
|---|---|
| [`docs/PLAN.md`](docs/PLAN.md) | The full game plan: design, hooks, prices, art, audio, tech, testing, milestones |
| [`docs/RESEARCH.md`](docs/RESEARCH.md) | Competitor research, Roblox 2026 rules and tooling facts, with sources |
| [`docs/STATUS.md`](docs/STATUS.md) | What's done, what's left, and the owner setup checklist |
| [`docs/DEVELOPING.md`](docs/DEVELOPING.md) | Tools, commands, code layout and pipelines |
| [`docs/ECONOMY.md`](docs/ECONOMY.md) | Economy formulas, simulator results and tuning history |
| [`docs/ART_BIBLE.md`](docs/ART_BIBLE.md) | The visual rules every model, effect and screen follows |
| [`assets/audio/PROMPTS.md`](assets/audio/PROMPTS.md) | Every generated sound and voice line, with its prompt |

## How the project is built
- The code is a [Rojo](https://rojo.space) project. Everything that ends up in the place lives in this repo.
- Most of the game logic is plain Luau with no Roblox dependencies, kept in `src/shared/Sim`. It is unit-tested headlessly with [Lune](https://lune-org.github.io/docs).
- An economy simulator in `tools/econ-sim` plays thousands of simulated players. It checks that progression pacing hits the targets in the plan.

## Trying it in Studio
1. Install [Rojo](https://rojo.space) 7.7 and its Studio plugin.
2. Run `rojo serve` in this folder, then connect from the plugin in an empty Baseplate.
3. Press Play. The town, train and UI are all built by the code. Sounds stay silent until they're uploaded (see `docs/STATUS.md`).

Checks: `bash scripts/check.sh` (tools listed in `docs/DEVELOPING.md`).
