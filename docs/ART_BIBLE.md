# Art bible: Critter Express

One page that every model, effect, UI screen and thumbnail follows. Consistency is what keeps the game from looking AI-made or thrown together.

## Mood
- Golden-hour Wild West: warm sun low in the sky, long soft shadows, dust in the air, teal sky overhead.
- Toy-like and chunky: everything looks squeezable and readable from far away on a phone.
- Mild rating: no guns, blood, alcohol, gambling props, or ethnic or Native caricatures.

## Palette
Source of truth: `src/shared/Config/Palette.luau`.

| Role | Colors |
|---|---|
| World | sand `#E8B97E`, dark sand `#C98F55`, dirt `#B9774A`, rock `#B06A45` / `#8A4E33`, cactus `#4E9A4B` |
| Wood & metal | wood `#8A5A3B`, dark wood `#5B3A26`, light wood `#B9835A`, iron `#3B3A3F`, rail `#6D6A70`, brass `#E2A93B` |
| Accents | train red `#E2463A`, gold `#FFC83D`, sky teal `#3FB7B0` / deep `#1E6F86` |
| UI | paper `#F3E2C0`, cream `#FFF4DD`, ink `#2B1D14` (outlines and text) |
| Rarities | Common gray, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic red, Outlaw black-gold, Secret pink-rainbow |

Every rarity color is always paired with its glyph (● ▲ ■ ◆ ★ ✦ ☠ ?) so color-blind players can tell them apart.

## Shapes
**Critters**
- Big round body, head merged into it, eyes about 30% of the face, tiny feet, one strong "costume" feature: hat, mustache, horns, shell, wheels…
- The silhouette must read at 50 px.

**Proportions**
- Chunky: thick trims, oversized wheels and hats. Bevel every hard edge.
- No thin spindly geometry, which disappears on phones.

**Rigs**
- `blob`, `biped` and `quadruped` (see `CritterLooks.luau`).
- Motion is code-driven: bounce, waddle, squash.

**Budgets**
- Critter ≤ 5–8k triangles; prop ≤ 2k; train car ≤ 6k.
- Textures ≤ 512² (shared atlas per family).
- No SurfaceAppearance and no unions (keeps publishing automatable).

## Materials and lighting
**Materials**
- Toon-flat colors with a soft top-down gradient.
- Real materials only where they add feel: WoodPlanks, Metal for brass and iron, Sand for ground.
- Mutations are the exception and may change material: Foil (Gold), Glass (Diamond), Ice (Frosty), CrackedLava (Molten), Neon (Cosmic).

**Lighting** (in `default.project.json`)
- Future lighting, soft shadows (ShadowSoftness 0.3), warm sun-side ColorShift.
- Shadows lifted by a bright warm OutdoorAmbient so they stay readable on phones.
- Atmosphere haze 1.5 with orange decay.
- Bloom 0.45 (threshold 1.8, so only neon and lanterns glow), subtle SunRays.
- ColorCorrection "Grade": +15% saturation, +10% contrast.
- Weather tints "Grade" toward that weather's mutation color (Vfx).
- Day cycle (client Ambience): ClockTime drifts 16.0 → 18.5 → 16.0 every 20 minutes from server
  time, so it is always golden hour. Lanterns fade up toward dusk; exposure lifts a little.
- Zone moods (client Ambience): Atmosphere and a separate "ZoneGrade" blend toward Ghost Town's
  cold green-grey fog, Gold Mine's golden glow or Rattlesnake Canyon's red haze, and back in town.

## UI
- **Buttons:** chunky, 3 px ink outline, 14 px corners, top-lit gradient, white text with an ink stroke, and a bounce on press (0.9 → overshoot back to 1).
- **Fonts:**
  - Luckiest Guy for titles and buttons.
  - Fredoka One for headings and names.
  - Builder Sans ExtraBold for numbers.
- **Panels:** wanted-poster paper with a red title tab and a round red close button.
- **Layout:**
  - Wallet top-center.
  - Menu column on the left, at most 5 buttons.
  - Gift and badges top-right.
  - The one big action button bottom-right, above the jump button.
  - Nothing else in the bottom-right thumb zone.
- **Copy:** friendly and honest. Purchase buttons say "View Item"; never "BUY NOW!!", fake timers or "only 2 left".

## Effects
| Moment | Effect |
|---|---|
| Rare and up | Sparkle aura in the rarity color |
| Legendary and up | Adds a light |
| Mythic and up | Adds flame wisps |
| Secret | Cycles rainbow |
| Cash | Gold sparkle burst plus a "+$X" pop that floats up |
| Reveals | 3 wobbles of rising intensity, one flash, spinning rays, a name card slam. Never more than 3 flashes a second. Reduced Motion turns off flashes and shakes |

**Quality tiers** scale particle counts: Low 30%, Medium 60%, High 100%.

## How we avoid the "AI look"
- AI image models are used only for mood boards and briefs. Nothing AI-generated ships without being rebuilt to this bible.
- No generated text inside images. All text is real UI text.
- No mixing styles. Free models are only used if restyled to this palette and these proportions.
- Icons and thumbnails are renders of the actual in-game models under one lighting rig.
- Motion is hand-tuned: anticipation and overshoot everywhere, never linear tweens.
