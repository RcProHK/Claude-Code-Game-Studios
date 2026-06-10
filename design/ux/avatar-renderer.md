# UX Spec: Avatar Renderer (#26) — In-World Render Surface

> **Status**: In Design
> **Author**: user + ux-designer (full-autonomous, 2026-06-10)
> **Last Updated**: 2026-06-10
> **Journey Phase(s)**: In-Session (mid-set 0.3s glance) + Week-End Ceremony (hero-pose consumed by #29)
> **Template**: UX Spec (adapted — non-interactive render surface)
> **Coupled pair**: #29 Mirror Moment (`design/ux/mirror-moment.md`) consumes the hero-pose visual defined here.

---

> **⚠️ Spec nature — read first.** #26 Avatar Renderer **owns NO panel UI, NO menu, NO button, and accepts ZERO player input** (avatar-renderer.md line 641 + 86). It is a **Character-Layer sprite** rendered from canonical data. Therefore the interaction-centric sections of the standard UX template (Navigation, Entry/Exit, Interaction Map, Events Fired) are **N/A by design** — explicitly marked below with the reason, never silently dropped. The genuinely UX-bearing concerns for a passive render surface are: **silhouette readability**, **posture/tier visual differentiation**, the **hero-pose shared-asset contract** (the seam #29 composes), and **accessibility**. Those are fully specified. All ceremony/screenshot/share UI lives in **#29** (ADR-0010 / #26 CR-17).

---

## Purpose & Player Need

The player needs to **recognise their own progress at a glance, without stopping to read**. During a gym set the player gives the screen a ~0.3–1s glance between reps; the avatar must answer three questions in that glance — *what class am I, what am I doing, how far have I evolved* — purely from its silhouette. Once a week, the same avatar (in a dedicated still "hero pose") becomes the subject the Mirror Moment ceremony (#29) frames, dims the world behind, and invites the player to screenshot. The render surface's job is to make the avatar an **honest, instantly-legible receipt of real training** — never a cosmetic that could lie (Pillar 1).

> "The player arrives at this surface wanting to **confirm 'I trained' in one look** — and, at week's end, to **see a body worth screenshotting**."

---

## Player Context on Arrival

The avatar is **always on screen during gameplay** — there is no "arrival." Two viewing contexts matter:

| Context | When | Player emotional state | Attention budget |
|---|---|---|---|
| **Mid-set glance** | During / between reps (GSM `WORKOUT_ACTIVE` / `REST_PERIOD`) | Focused on the workout, physically occupied, glancing | ~0.3s, peripheral — silhouette must carry everything (FT-1/FT-4) |
| **Hero-pose / ceremony** | Week-end first-open in a non-workout context, composed by #29 | Calm, reflective, pride-seeking | Full attention, still frame, screenshot-intent |

The design assumes the **mid-set glance is the worst case** and optimises silhouette legibility for it. The hero-pose context is a superset (more time, full saturation, world dimmed by #29) so it inherits the same legibility for free.

---

## Navigation Position

**N/A — not a navigable screen.** The avatar is a persistent Character-Layer sprite, not a destination in the navigation hierarchy. It has no parent screen and cannot be "opened" or "closed." (When the avatar's *state* is inspected as data, that is #22 Character Screen — a separate spec — reading via the CR-11 getters; when it is *framed for a ceremony*, that is #29.)

---

## Entry & Exit Points

**N/A — persistent render surface.** The avatar exists for the whole session (Booting → IDLE → COMBAT/CAST ⇄ SUSPENDED, per the #26 internal render-FSM). There is no player-triggered entry or exit. The only "lifecycle" is engine-level (boot derive, suspend pause, resume restore) and is fully owned by #26's GDD state machine — no player action involved.

---

## Layout Specification

### Information Hierarchy

In a 0.3s silhouette glance, the player must read — **in this priority order**:

1. **Class** (STRIKE / CONTROL / MOBILITY) — read from **silhouette mass shape** (FT-4: ≥80% classify from a 16×16 black silhouette). *Highest priority — it's the identity.*
2. **Action state** (idle / combat / cast) — read from **pose + motion** of the animation loop (FT-1).
3. **Evolution tier** (T0–T3) — read from **silhouette size/definition delta** (wider, more-defined mass as tier rises). *Discoverable across weeks, not split-second critical.*
4. **Micro-evolution texture** (hue/outline/breathing shader) — *lowest priority, additive flavour; never load-bearing for any of the above (it is shader-only, not silhouette).*

> **Binding constraint (from #26 + art-director)**: class is communicated by **silhouette mass change, NOT palette** — palette-swap was rejected because it fails FT-4 (colour is not legible at 16×16 / under colour-blindness). This is also an accessibility guarantee (see Accessibility).

### Layout Zones

**Single zone — the avatar occupies the Character Layer in world space.** There are no sub-zones, panels, or chrome owned by #26. Placement is governed by ADR-0001 CanvasLayer topology:

| Layer | z | Owner | Content |
|---|---|---|---|
| World | 0 | world | background |
| **Character (10)** | avatar `z_index = 0`, range **[-10, 10]** | **#26** | the avatar sprite (the only thing #26 renders) |
| Particle (20) | — | #5 | combat/celebration particles (always above avatar) |
| HUD / Event (100+) | — | #20 / #21 / #29 | HUD, modals, **ceremony overlay (#29)** |

The avatar never raws `z_index > 50` (CR-7). Combat/cast effect sprite displacement ≤ 4 px; any particle burst ≤ 2× sprite bbox — so the silhouette is never visually shattered.

### Component Inventory

| "Component" | Type | Interactive? | Pattern | Notes |
|---|---|---|---|---|
| Avatar sprite | `AnimatedSprite2D` (Character Layer) | **No** | — (render surface, not a UI pattern) | driven by `AvatarVisualState` (posture, tier, anim) |
| Hero-pose still | still frame within the (posture,tier) `SpriteFrames` | **No** | **Hero-Pose Shared Asset** (new — see below) | the frame #29 composes the ceremony around |

This spec introduces **no interactive components** and therefore references no entries from `design/ux/interaction-patterns.md`. It does define one **shared-asset contract** (Hero-Pose) that #29's spec consumes.

### Hero-Pose Shared-Asset Contract (the ADR-0010 visual seam)

This is the one piece of cross-spec value. **#26 owns the hero-pose ASSET; #29 owns its COMPOSITION** (canvas, ghost offset, divider, badge, share affordance). The seam:

- For each `(class_posture, evolution_tier)` SpriteFrames, exactly **one frame index** is designated the **hero pose** — a still, front-facing, symmetrical, "mirror" stance (the gym-mirror confirmation pose). Exposed to #29 as `AvatarEvolutionSnapshot.hero_pose_frame`.
- **Composition-neutral requirements #26 guarantees about the hero-pose frame** (so #29 can compose without surprises):
  - **Centred + upright** — the silhouette's vertical axis is centred in the frame; feet near the bottom safe-edge, head clear of the top edge.
  - **Self-contained** — no mid-action limb extension, no in-progress VFX baked into the sprite (effects are #5's layer, not the sprite).
  - **Transparent margins** — ≥ 1 px transparent border on all sides so #29's ghost-offset + scaling never clips.
  - **Silhouette-legible at the same FT-4 bar** as the gameplay sprites (class readable from mass alone).
- **#26 renders NOTHING of the ceremony** — it exposes the frame index + sprite paths only (CR-11 / CR-17). #29 decides the 9:16 canvas, gradient backdrop, 30%-opacity prior-tier ghost, divider, tier badge, and the screenshot affordance.

### ASCII Wireframe

Not a panelled screen, but the in-world render relationship + the hero-pose seam:

```
  GAMEPLAY (mid-set glance)                 WEEK-END (hero-pose, composed by #29)
  ┌───────────────────────────┐            ┌───────────────────────────┐
  │  HUD (layer 100, #20)      │            │  #29 ceremony overlay      │ ← #29 owns
  │                           │            │   (CelebrationVFXLayer 110 │   ALL of this
  │        ░▓█▓░   ← avatar    │            │    + ModalLayer 120)       │
  │       ▒▓███▓▒   Character  │            │   ┌─────────────┐         │
  │        ▓███▓    Layer 10   │            │   │ ghost│ HERO  │ ← #26    │
  │   ────────────  (z 0)      │            │   │ (T-1)│ POSE  │   provides
  │   world (layer 0)          │            │   │  30% │ frame │   the frame
  └───────────────────────────┘            │   └─────────────┘   only    │
       ▲ #26 renders this                  │   [T2] caption  [截圖分享]  │
       silhouette only                     └───────────────────────────┘
                                                ▲ #26 renders NONE of this
```

---

## States & Variants

#26 has **render states** (driven by GSM + canonical data), not player-facing screen variants. The visible matrix:

| State / Variant | Trigger | What the silhouette shows |
|---|---|---|
| **Idle** | GSM ∉ combat, no cast | breathing idle loop, current (posture,tier) sprite |
| **Combat** | GSM `COMBAT_ACTIVE` / `BOSS_ENCOUNTER` | combat loop; sprite swap deferred to next IDLE (anti-flicker) |
| **Cast** | `#12.ability_cast(caster==player)` | cast anim (≤100ms onset, 300ms hard window) |
| **Suspended** | GSM `SUSPENDED` (tab/bfcache) | `AnimatedSprite2D.pause()` holds current frame (NOT reset) |
| **Posture variant** | dominant_class STRIKE/CONTROL/MOBILITY | different silhouette **mass** (not colour); swap gated by CR-9 hysteresis + workout-window lock |
| **Tier variant** | T0 → T3 (monotonic) | base sprite swap, wider/more-defined mass; never regresses |
| **Micro-evolution** | weekly shader delta | hue/outline/breathing shift — **same silhouette**, texture only |
| **Hero-pose** | requested via `hero_pose_frame` (by #29) | still mirror stance of the current (posture,tier) |
| **Emergency fallback** | SpriteFrames load fail (EC-ASSET-1) | `EMERGENCY_AVATAR.tres` (T0 STRIKE idle) — silhouette never breaks |

> **No "empty state"** — the avatar always derives *some* state (fresh account = T0 STRIKE idle). There is no data-absent blank; the emergency fallback covers asset failure.

---

## Interaction Map

**N/A — zero player input.** #26 accepts no taps, clicks, keys, or gamepad input. The avatar is driven entirely by upstream canonical signals (`#11.stat_changed`, `#12.ability_unlocked`, `#12.ability_cast`, GSM `state_changed`). Player-perceived interactivity (anticipating the week-end evolved sprite) is **emotional, not input-driven**. Any interaction *around* the avatar (inspecting stats, the ceremony screenshot) belongs to #22 / #29.

---

## Events Fired

**N/A as UI events.** #26 emits **domain signals**, not UI/analytics events: `avatar_visual_updated`, `avatar_evolution_milestone(tier, source_metrics)`, `avatar_micro_evolution(delta_kind, source_metrics)`, `avatar_cast_dropped`. These are consumed by #22 (state read) and #29 (ceremony trigger). No player action originates them — they are reactions to canonical-data changes. (Telemetry for the *ceremony* — `mirror.shared` etc. — is #29's.)

---

## Transitions & Animations

| Transition | Behaviour | Constraint |
|---|---|---|
| Idle ⇄ Combat | anim cut ≤ 1 frame | CR-2 Option C (boss shares combat anim) |
| → Cast | onset ≤ 100 ms; 300 ms hard window uninterruptible | CR-10 |
| Posture swap | only outside workout window + after `POSTURE_HYSTERESIS_SECONDS` (300s) | CR-9 — no mid-set flicker (P2) |
| Tier evolution (silhouette) | base sprite swap | **NO Pokémon-cutscene** — no `Camera2D` zoom-shake, no `ScreenEffects` saturation drop > 30%, no transformation anim > 1.5s (P5 guard). The *celebration* framing is #29's; #26's swap is quiet. |
| Micro-evolution | shader uniform tween (hue/outline/breathing) | shader-only; **disabled under reduced-motion** |
| Suspend → resume | ≤ 30s restore exact frame; > 30s re-derive to IDLE | CR-8 / Formula 5, bfcache 30s parity |

> **Reduced-motion is a first-class path** (see Accessibility) — breathing freezes, posture transitions become instant cuts, micro shader tween is off. Tier identity (silhouette) is unaffected — information is never carried by motion alone.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| dominant_class (STR/DEX/VIT) | #11 Stat | Read | CR-16 — class derives from 3 base stats ONLY |
| evolution_tier, ability_count, stat_total, max_class_depth | #11 / #12 | Read | Formula 2 tier derivation |
| ability_cast trigger | #12 Ability | Read | cast anim |
| GSM state | #1 GSM | Read | anim state + suspend + workout-window lock |
| tier history / last_emitted_tier | #3 Persistence (`avatar.*`) | Read/Write | CR-12 — **#26 owns this; #29 must NOT** (ADR-0010) |
| SpriteFrames / hero_pose_frame | `posture_config.tres` (#26 data) | Read | the (posture,tier) → asset LUT |

#26 **writes only `avatar.*`** persistence; it owns all evolution-tier state. The UX surface itself owns no game state. (#29 reads a snapshot; it never writes tier — CI-MM-4.)

---

## Accessibility

Committed against `design/accessibility-requirements.md` (verify tier at review). #26's accessibility is **mostly structural and already enforced by the GDD**:

- **Colour is never the sole differentiator.** Class is read from **silhouette mass**, not palette (FT-4, 16×16 black silhouette ≥ 80% classifiable). This is the strongest colour-blind guarantee in the game and is a hard binding constraint, not a nice-to-have.
- **Reduced motion** (`motion_reduction` slider, owned by #6): idle breathing **freezes at frame 0**; posture transitions become **instant cut** (no blend); micro-evolution shader tween is **disabled**. **No information is lost** — tier and class are silhouette/pose, not motion.
- **Screen reader**: #26 **emits signals, not announcements**. The ARIA live-region announce for a significant avatar change is owned by **#22** (avatar state) and the milestone announce by **#29** (ceremony) — so #26 has no announce surface of its own, but its signals are the trigger source. (When repeated in #29's spec, the ceremony announce is `platform_detect.announce_aria("Mirror Moment：第 N 週進化到 T{tier}", polite)`.)
- **No flashing / no rapid strobe**: tier swap is a single quiet replacement (no > 30% saturation flash, P5 guard); celebration flashing, if any, is #29's particle layer under the same reduced-motion slider.
- **Glance legibility doubles as low-vision support**: the FT-1 "≤1s glance identifies class+state+tier" bar means the avatar is readable without sustained focus.

---

## Localization Considerations

**Minimal — #26 renders no text.** The avatar sprite carries zero strings. Any text *about* the avatar (class names, tier labels, the ceremony caption) is rendered by #22 / #29 and localised in those specs. The only localisation-adjacent concern: the **silhouette must stay class-legible across all locales** (it is language-independent by construction — a strength). No 40%-expansion layout risk here. (Caption text expansion is #29's concern.)

---

## Acceptance Criteria

> These are the UX-surface criteria; they complement (do not replace) the 33 functional ACs in the #26 GDD. Verifiable by a tester without reading another doc.

- [ ] **Glance legibility (core purpose)** — 10 playtesters given a ≤ 1s mid-set glance identify **class + action-state + tier** at ≥ 80% accuracy (FT-1 / AC-31).
- [ ] **Silhouette class read** — a 16×16 pure-black silhouette of each class is correctly classified by ≥ 80% of testers across the 3 classes (FT-4 / AC-32, colour removed).
- [ ] **Tier delta is visible** — placing T0 and T3 silhouettes of the same class side by side, ≥ 80% of testers identify which is "more evolved" without a label.
- [ ] **Hero-pose composability** — for all 12 (class × tier) hero-pose frames: the silhouette is centred, fully inside the frame with ≥ 1 px transparent margin on all sides, and contains no baked-in VFX (visual inspection — so #29 can ghost/scale without clipping).
- [ ] **Reduced-motion path** — with `motion_reduction` on: breathing is frozen, posture change is an instant cut, micro shader tween is off, **and class + tier remain fully readable** (no information lost).
- [ ] **No Pokémon-cutscene on tier-up** — a tier evolution triggers no camera zoom/shake, no > 30% saturation drop, and no transformation animation > 1.5s on #26's surface (the celebration is #29's layer, verified separately).
- [ ] **Render-surface purity** — the avatar sits on Character Layer 10 with `z_index ∈ [-10, 10]`; #26 renders no panel, button, or ceremony chrome (matches AC-26 + AC-30).

---

## Open Questions

| ID | Question | Owner | Resolution |
|----|----------|-------|------------|
| **Q-UX-HEROPOSE** | Is the hero-pose a **dedicated authored frame** per (class,tier) or a **designated index into the idle loop**? (12 dedicated stills vs reuse an idle frame) | art-director + #26 owner | **pre-`/asset-spec`** — affects the Q-OQ-ASSET sheet count (36 anim sheets + **12 hero stills** already in #26 Q-OQ-ASSET). Default: dedicated still (best mirror-stance control). |
| **Q-UX-ASSET-THROUGHPUT** | 36 sprite sheets + 12 hero stills, solo-dev throughput (#26 Q-OQ-ASSET / AC-asset). Does the hero-pose add 12 to the production budget or fold into existing sheets? | art-director | pre-`/create-stories` scope gate (shared with #26 Q-OQ-ASSET) |
| **Q-UX-A11Y-TIER** | Accessibility tier not explicitly pinned per-screen — confirm WCAG-AA-equivalent baseline applies (colour-independence already exceeds it via silhouette-mass). | ux-designer | `/ux-review` |
| **Player-journey gap** | No `design/player-journey.md` exists — the In-Session / Week-End contexts above are inferred from game-concept Retention Hooks. Consider authoring the journey map to validate. | — | post-spec |

> **Cross-link**: `design/ux/mirror-moment.md` (#29) **consumes the Hero-Pose Shared-Asset Contract** defined here. The two specs are a coupled pair; #29 owns composition, #26 owns the asset. Keep the hero-pose requirements in sync across both.
