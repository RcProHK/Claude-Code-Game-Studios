# Mirror Hero — Visual Mockup Prototype

---
status: concluded
source: prototypes/visual-mockup/mirror-hero-mockup.html
date: 2026-05-29
reverse-documented-by: /reverse-document concept prototypes/visual-mockup
---

> **Note**: Reverse-documented from the existing HTML prototype. This prototype
> was a pre-GDD visual probe to validate the Art Bible's colour language and
> loot-ritual timing in-browser before committing to full GDD authoring.

---

## Hypothesis Tested

> *"Does the art-bible visual language — desaturated Worn Wilderness palette,
> class-colour accents, and the quiet→climax loot ritual — translate into an
> emotionally coherent feeling in a 512×288 pixel-art viewport?"*

**Verdict: CONFIRMED.** The 90 % quiet / 10 % climax tension reads clearly at
a glance. The rarity colour coding distinguishes itself from world colours
without clashing. Avatar tier silhouettes are legible at 30–45 px height.

---

## What Was Built

A single interactive HTML file (`mirror-hero-mockup.html`) rendering a live
game screen at 512×288 (2× upscale of 256×144 internal canvas).  No game
engine — pure `<canvas>` 2D API. Not a gameplay prototype; a *visual* probe.

### Scenes / Interactions

| Control | What It Shows |
|---------|--------------|
| Avatar Tier T1/T2/T3 | Silhouette shape progression — egg → hourglass → triangle; weapon scale + posture shift |
| Enemy Push / Pull / Leg | Class-archetype enemy shapes — wide-T (bark+ash), tall-V (slate cool), trapezoid-down (moss warm) with class-colour aura tint |
| ★ LOOT 爆裝儀式 | Full loot drop ritual: time-stop → world desaturate → particle burst (70 pts) → 0.4 s freeze → orb modal reveal → rarity-tinted name card → recover |

### Systems Exercised (Visual Only — No Gameplay Logic)

1. **World layer** — Worn Wilderness grove: sky gradient, organic mountain
   silhouettes, broken stone pillar environmental story hook, platform with
   angular 45/90° edges, ambient dust particles (24 pts, 1× baseline →
   3× during ritual).

2. **Avatar tier silhouette** (Art Bible §3.A / §5.A):
   - T1 egg 2.5:1 WH, slight hunch pose
   - T2 hourglass 3:1, upright
   - T3 triangle 3.5:1, swagger swagger tilt, wide shoulder trim + weapon
     raised overhead
   - Class-colour accent trim grows with tier (none → 1 px → 2 px column)

3. **Enemy type silhouettes** (Art Bible §3.A / §5.B):
   - Push → wide T-top, bark+ash, STRIKE red aura (Push = chest = STRIKE)
   - Pull → tall V-down, slate cool, CONTROL purple aura (Pull = back = CONTROL)
   - Leg → trapezoid-down, moss warm, MOBILITY blue aura (Leg = legs = MOBILITY)

4. **HUD layout** (Art Bible §7 — Diegetic UI):
   - HP bar 90 px × 5 px, bottom-left, STRIKE red fill
   - EXP bar 90 px × 3 px under HP, amber
   - Exercise progress ring top-right (9 px radius, amber arc, rep counter)
   - Skill cooldown squares bottom-right: S / C / M, 14×14 px, class colours,
     cooldown sweep overlay

5. **Loot Drop Ritual** (Art Bible §2.1 / §4.E):
   - Trigger: `lootDrop()` button (simulates boss kill / workout complete)
   - Step 1: World canvas `saturate(0.4) brightness(0.85)` — −60% sat "freeze"
   - Step 2: 70-particle burst from drop point, white → rarity colour fade
   - Step 3: Gold light column (amber gradient beam) during freeze
   - Step 4: 0.4 s delay → orb modal pops in (`orbpop` cubic-bezier spring)
   - Step 5: Hold duration = 1 200 ms + 350 ms × rarity index (C=0…L=4),
     range 1 200 ms → 2 600 ms
   - Step 6: Dismiss modal → `saturate(0.7)` recover (During-Set baseline)

---

## Colour Palette Verified

All colours baked from `design/art/art-bible.md` §4:

| Layer | Colours | Saturation |
|-------|---------|-----------|
| World (Worn Wilderness) | `#3E5B3A` moss · `#5C4A36` bark · `#4A5A66` slate · `#7A7468` ash | −30 % (During Set baseline `saturate(0.7)`) |
| Character | `#C9B89A` linen | same as world |
| Event / HUD | `#F2A93B` amber · `#FFFFFF` white | 100 % — pops against desat world |
| Loot rarity | C `#FFFFFF` · U `#6FB87A` · R `#4D8FD6` · E `#9B5FCC` · L `#FF8C42` | 100 % — distinct from world + HUD |
| Class accents | STRIKE `#E85A5A` · CONTROL `#A66BC9` · MOBILITY `#5BA8E8` | 100 % — maps to P4 Muscle = Class |
| Loot ritual | −60 % world sat + white burst + gold beam | contrast peak |

---

## What Worked

- **Two-layer saturation tension** is immediately readable: the world feels
  calm and "alive" at −30 %; loot ritual at −60 % creates a clear "everything
  stopped" signal without jarring the player.
- **Rarity colour channel** is distinct from world and HUD colours — no
  clash even at UNCOMMON green vs moss green (brightness separation sufficient).
- **Avatar tier silhouettes** read at 30–45 px height — T1 vs T3 is
  unmistakable even without the label buttons.
- **Class-colour aura on enemies** (10 % alpha tinted dots) is subtle enough
  not to overpower the silhouette but present enough to reinforce the
  STRIKE/CONTROL/MOBILITY identity.
- **0.4 s freeze then orb pop** timing feels right — long enough to register
  as a ceremony, short enough not to frustrate during a workout.
- **Rarity-scaled hold** (1.2–2.6 s) rewards higher rarity with longer
  "savour time" without artificial inflation.

## What Didn't Work / Wasn't Tested

- **No actual input / gameplay loop** — this is visual only. Responsiveness
  and one-tap feel untested.
- **Boss Reveal ritual** (Section 5 "BOSS_REVEAL" preset) not included —
  only Loot Drop post-boss. Boss entrance cinematic is deferred.
- **Avatar evolution transition animation** not shown — tier buttons snap
  instantly; the morph animation (T1 → T2) was out of scope.
- **Streak / combo HUD** (streak counter, buff indicator) absent — only
  base HP/EXP/ring/skill slots shown.
- **Mobile viewport** not validated — mockup is 512 px fixed width; touch
  target sizing and portrait layout deferred to UX spec.
- **Actual pixel font** not loaded — browser monospace used as placeholder;
  final game will use a pixel bitmap font.

---

## Design Decisions Captured (Feeds Into GDDs/ADRs)

| Finding | Adopted In |
|---------|-----------|
| Loot freeze 0.4 s is the sweet spot | `design/gdd/loot-drop-system.md` §Loot Reveal Ritual timing |
| Hold = 1 200 + 350 × rarity_index | `design/gdd/loot-drop-system.md` Tuning Knob `REVEAL_HOLD_BASE_MS` / `REVEAL_HOLD_PER_TIER_MS` |
| World −30 % sat baseline / −60 % during ritual | `design/art/art-bible.md` §2.1 Saturation Language |
| Class accent colours STRIKE/CONTROL/MOBILITY | `docs/architecture/adr-0007-class-enum-convention.md` (locked) |
| Rarity colour palette (5 tiers) | `design/art/art-bible.md` §4.E |
| Avatar T1/T2/T3 silhouette ratios (2.5:1 / 3:1 / 3.5:1) | `design/gdd/avatar-renderer.md` §Tier Shapes |
| HUD positions: bars bottom-left, ring top-right, slots bottom-right | `design/ux/interaction-patterns.md` |

---

## How to Run

Open `prototypes/visual-mockup/mirror-hero-mockup.html` in any modern browser
(Chrome / Edge / Firefox / Safari). No server, no dependencies.

- Click **T1 / T2 / T3** to switch avatar tier
- Click **Push / Pull / Leg** to switch enemy type
- Click **★ LOOT 爆裝儀式** to trigger the full loot drop ritual

---

## Status

**CONCLUDED** — Hypothesis confirmed. All visual findings absorbed into the
Art Bible, GDDs, and ADRs. This prototype is **preserved for reference only**;
do not extend or migrate code into production. See
`prototypes/.claude/docs/prototype-code.md` for lifecycle rules.
