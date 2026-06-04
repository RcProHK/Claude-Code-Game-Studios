# Interaction Pattern Library

> **Status**: Initial Version — 2026-05-28
> **Author**: ux-designer
> **Last Updated**: 2026-05-28
> **Template**: Interaction Pattern Library

---

## Overview

Mirror Hero 係一個 web-based gym companion RPG，設計為 background auto-play（Pillar 2 無壓力陪伴）。呢個 library 定義遊戲入面所有 interaction pattern，確保視覺語言一致、accessibility 要求一致、以及唔同 screen 之間嘅行為 coherent。

**Pattern authoring principles**:
1. Every pattern must serve at least one of the 5 game pillars
2. Patterns are referenced by name in screen UX specs — do not reinvent
3. If a new pattern is invented during a screen spec session, add it here before review
4. All patterns must comply with `design/accessibility-requirements.md`

**Derived from**: Art Bible Sections 7 + 4 + 3，GDD UI Requirements sections (#6 ScreenEffects, #7 Camera, #9 WorkoutStateTracker, #11 StatSystem, #12 AbilitySystem, game-concept.md)

---

## Pattern Catalog

| # | Pattern Name | Category | Used In | Status |
|---|-------------|----------|---------|--------|
| P-01 | [exercise-progress-ring](#p-01-exercise-progress-ring) | Data Display | HUD (#20) | Defined |
| P-02 | [frameless-hud-bar](#p-02-frameless-hud-bar) | Data Display | HUD (#20) | Defined |
| P-03 | [stat-number-ticker](#p-03-stat-number-ticker) | Feedback | HUD, Combat (#25) | Defined |
| P-04 | [skill-family-icon](#p-04-skill-family-icon) | Data Display | HUD (#20), Ability screen (#22) | Defined |
| P-05 | [loot-drop-modal](#p-05-loot-drop-modal) | Modal | Loot Drop Modal (#21) | Defined |
| P-06 | [rarity-color-tier](#p-06-rarity-color-tier) | Feedback | HUD, Loot Modal (#21), Inventory (#23) | Defined |
| P-07 | [motion-intensity-slider](#p-07-motion-intensity-slider) | Settings / Accessibility | Character Screen (#22) | Defined |
| P-08 | [reduce-motion-toggle](#p-08-reduce-motion-toggle) | Settings / Accessibility | Character Screen (#22) | Defined |
| P-09 | [single-tap-exercise-switch](#p-09-single-tap-exercise-switch) | Input | Exercise switch (GymSys) | Defined |
| P-10 | [damage-number-popup](#p-10-damage-number-popup) | Feedback | Combat VFX (#25) | Defined |
| P-11 | [enemy-threat-hud-bar](#p-11-enemy-threat-hud-bar) | Data Display | HUD (#20) — Boss HP | Defined |

---

## Patterns

---

### P-01: exercise-progress-ring

**Category**: Data Display
**Used In**: HUD (#20), potentially Loot Drop Modal (#21) as context
**Derived From**: Art Bible Section 7.C, GDD #9 WorkoutStateTracker (`get_set_progress() → float`)

**Description**: Circular ring showing progress through the current exercise set (0.0–1.0). Represents a discrete countdown (one full rotation = one set complete). The ring shape communicates "one complete cycle = done" — aligned with the round-trip nature of a gym set. Replaces linear bar to distinguish set progress from continuous resources (HP, EXP).

**Specification**:
- Shape: circle ring, outer diameter 16px, stroke 2px (art bible Section 7.C)
- Fill direction: clockwise from 12 o'clock
- Color: `ui_amber_primary #F2A93B` fill over `ui_ink_mid #2D323D` track
- Animation: smooth fill (linear), updates on GymSys `set_completed` events (discrete increments per rep)
- Completion pulse: at 1.0, ring pulses once with `ui_text_primary #F5EFE0` for 0.3s then resets
- Mobile tap target: minimum 44×44 px touch target zone even though ring is 16px visual size
- Empty state: full `ui_ink_mid` track, amber arc = 0 (start of session)
- Accessibility: ring fill percentage is also expressed as an ARIA progress label (v0.2+ screen reader) — for MVP, visual only

**When to Use**: Any time a discrete cycle (reps, exercises, stages) needs to be communicated as a circular countdown.

**When NOT to Use**: Continuous resources (health, exp, mana) — use [P-02 frameless-hud-bar](#p-02-frameless-hud-bar) instead. Multiple concurrent rings should be avoided (max 1 ring per HUD zone).

---

### P-02: frameless-hud-bar

**Category**: Data Display
**Used In**: HUD (#20) — health bar, exp bar
**Derived From**: Art Bible Section 7.A, Section 7.C

**Description**: A horizontal rounded-rectangle bar with no surrounding frame or panel. Used for continuous resources that scale linearly. The absence of a frame reduces visual noise during gameplay (Pillar 2) while maintaining readability via the contrast of the filled region against the track color.

**Specification**:
- Shape: rounded-rectangle, 2px corner radius
- Height tiers (importance = height):
  - Health bar: 6px
  - EXP bar: 3px
- Fill color: `ui_amber_primary #F2A93B` for EXP; red `#D94B3E` danger tint when HP < 20%
- Track color: `ui_ink_mid #2D323D`
- Border / frame: NONE — no StyleBoxFlat border (art bible Section 7.A "frameless")
- Drop shadow: 1px offset, `ui_ink_bg #1A1D24` @ 40% opacity (hard shadow, not blur)
- Animation: `ease-out quad` fill/drain, 200ms duration (art bible Section 7.D)
- Edge anchoring: screen edge, not floating in center
- Empty state: full `ui_ink_mid` track (bar at zero shows track only, no void)
- Accessibility: critical resource (HP) also uses danger red + triangle icon at low threshold (P-06 color independence rule applies)

**When to Use**: Continuous linear resources (health, exp, mana, stamina).

**When NOT to Use**: Discrete cycle progress — use [P-01 exercise-progress-ring](#p-01-exercise-progress-ring). Fixed-step cooldowns — use step-based indicator or skill icon (P-04 + cooldown sweep).

---

### P-03: stat-number-ticker

**Category**: Feedback
**Used In**: HUD (#20), Combat VFX (#25), Character Screen (#22)
**Derived From**: Art Bible Section 7.D

**Description**: A number that "ticks up" in discrete integer steps when a stat increases. Uses a step function (not smooth lerp) — each frame shows a valid integer value. This gives a "count-up" feel aligned with the pixel art aesthetic rather than a smooth slide. The discontinuous stepping communicates "real increments" matching the physical rep-by-rep nature of training (Pillar 1 visual language).

**Specification**:
- Animation curve: step function — one integer increment every 33ms (≈1 per 2 frames at 60fps)
- Duration: proportional to delta (small stat change: ~0.5s, large PR breakthrough: up to 2s)
- Font: HUD number tier — 7px monospace pixel font (m5x7 or equivalent)
- Color: `ui_amber_primary #F2A93B` with 1px `ui_ink_bg` drop shadow
- Direction: upward only for positive gains (downward for losses, same curve)
- Start value: previous stat value
- End value: new stat value
- Overrun prevention: if another change arrives during animation, snap to current value and begin new animation from there
- Accessibility: final value is stated; animation is purely aesthetic. Screen reader (v0.2+) reads only the final value.

**When to Use**: Stat changes resulting from workout events (VOLUME_TICK, PR_BREAKTHROUGH). Number reveals on character screen.

**When NOT to Use**: Real-time values that update multiple times per second (health in combat — use P-02 bar). The ticker implies "something meaningful happened" — avoid for noise.

---

### P-04: skill-family-icon

**Category**: Data Display
**Used In**: HUD (#20) — skill cooldown area, Ability screen (#22), Enemy type indicator
**Derived From**: Art Bible Section 7.C, GDD #12 AbilitySystem

**Description**: A 16×16 pixel icon representing an ability or enemy type. Uses solid-fill silhouette style with 1px ink outline and no inner detail lines. The silhouette shape encodes the skill family (Strike/Control/Mobility) so the player can read type without relying on color alone (Pillar 4 + accessibility).

**Specification**:
- Size: 16×16 px design, 64×64 px export (renders at 16×16 in HUD)
- Style: solid-fill silhouette + 1px ink outline (#1A1D24), no inner detail lines
- Background: `ui_ink_mid #2D323D` panel (16×16 px, part of cooldown tracker)
- Pixel coverage: 40-70% of 16×16 grid (art bible minimum for recognition)
- Family silhouette archetypes (P4 enforcement):
  - **Strike**: diagonal line / sharp angle / forward-pointing shape → combat red `#E85A5A` fill
  - **Control**: symmetric / outward-radiating / arc shape → control purple `#A66BC9` fill
  - **Mobility**: flowing line / upward/sideways / negative space → mobility blue `#5BA8E8` fill
- Active state: `ui_amber_primary #F2A93B` ≤3px accent (bottom edge or corner dot)
- Inactive/locked state: full `ui_ink_mid` fill, no family color (greyed out)
- Cooldown overlay: clockwise sector mask from 12 o'clock, `ui_ink_bg` overlay at 60% opacity
- Recognition test: must be identifiable at 8×8 thumbnail downscale (squint test)
- Accessibility: shape communicates family independent of color; tooltip shows family name on hover/long-press (v0.2+)

**When to Use**: Any ability/skill representation in HUD or inventory. Enemy type badge (Pull/Push/Leg) in encounter UI.

**When NOT to Use**: Full-screen ability showcase — use larger illustrated format. Items/equipment — use equipment icon variant (to be defined in #17 Equipment GDD).

---

### P-05: loot-drop-modal

**Category**: Modal
**Used In**: Loot Drop Modal (#21 — Pillar 3 signature feature)
**Derived From**: Art Bible Section 7.A (Diegetic UI moments), Section 4.E (Loot Drop saturation timeline)

**Description**: The ceremonial modal that appears when a loot item drops (mini-boss kill or workout-complete final boss kill). This is the most high-stakes UI pattern in the game — it is the Pillar 3 dopamine delivery mechanism. It must feel ritualistic, shareable, and over-the-top.

**Specification**:

*Opening sequence (total duration varies by rarity)*:
1. **World freeze** (0.4s): World layer saturates to −60% (near-greyscale), game world freezes — time-stop effect. UI and particle layers continue.
2. **Modal entry** (0.15s → 1.2s): Modal emerges from center. Entry animation: `scale 0.8 → 1.0` with elastic-light overshoot (not bouncy). Simultaneously particle burst at `3× combat baseline` from loot position.
3. **Rarity-calibrated hold** (varies: COMMON 0.2s → LEGENDARY 0.8s): Modal holds open. Rarity color trail from initial white burst.
4. **World recovery** (0.8s): World saturation returns to normal. Modal stays open until player taps dismiss.

*Modal appearance*:
- Frame style: pixel-illustrated dirty frame ("破爛布旗/鐵鏽金屬條" silhouette per art bible) — NOT clean rectangle
- Background: `ui_ink_bg #1A1D24` at 92% opacity with 8% blur (modal blur only, not screen)
- Item display: centered 64×64 px item icon at 2× scale (128×128 render)
- Item name: H1 font (11px m6x11) in `ui_text_primary`
- Rarity label: Body font (7px m5x7) in rarity color with matching rarity orb icon (P-06)
- Stats delta: stat-number-tickers (P-03) showing stat gains
- Dismiss: single tap anywhere on modal OR 5s auto-dismiss (Pillar 2 — never traps player)

*Rarity duration calibration*:
- COMMON: hold 0.2s, particle 0.5s, no slowmo
- UNCOMMON: hold 0.3s, particle 0.7s, no slowmo
- RARE: hold 0.4s, particle 1.0s, slight slowmo 0.98×
- EPIC: hold 0.6s, particle 1.2s, slowmo 0.95×, screen edge vignette
- LEGENDARY: hold 0.8s, particle 1.5s, slowmo 0.90×, full vignette, fanfare

*Accessibility*:
- Rarity is communicated by hold duration + particle density + frame ornament density (P-06) + audio — not color alone
- Auto-dismiss after 5s ensures player never gets stuck mid-set
- Reduced motion (P-08 enabled): particle density 0.5×, slowmo disabled, hold times unchanged

**When to Use**: Loot item drop events only. One modal at a time.

**When NOT to Use**: Non-item rewards (stat increases, streak milestones) — use inline celebration or toast notification pattern (to be defined).

---

### P-06: rarity-color-tier

**Category**: Feedback
**Used In**: HUD, Loot Modal (#21), Inventory (#23), Equipment screen (#22)
**Derived From**: Art Bible Section 4.B Semantic Color Usage, Section 4.C Colorblind Safety

**Description**: A five-tier visual hierarchy for item/reward rarity. NEVER communicates rarity through color alone. Every tier uses a combination of color + orb size + satellite count + animation duration + audio to ensure accessibility.

**Specification**:

| Tier | Color | Hex | Orb Size | Satellites | Trail Duration | Audio |
|------|-------|-----|----------|-----------|---------------|-------|
| COMMON | White | `#FFFFFF` | 8px | 0 | 0.3s | Tink |
| UNCOMMON | Green | `#6FB87A` | 12px | 0 | 0.5s | Tink + harmonic |
| RARE | Blue | `#4D8FD6` | 16px | 1 | 0.8s + sparkle | Tink + chime |
| EPIC | Purple | `#9B5FCC` | 16px | 2 + ring | 1.0s + rotating sparkle | Tink + 3-note |
| LEGENDARY | Orange | `#FF8C42` | 24px + pillar | pillar + vignette | 1.5s + shake + slowmo | Fanfare |

*Color-independent backup rules* (art bible Section 4.C):
- COMMON vs UNCOMMON: size difference 8px vs 12px (50% larger)
- UNCOMMON vs RARE: satellite count 0 vs 1; audio harmonic vs chime (different instrument)
- RARE vs EPIC: satellite count 1 vs 2 + ring; audio 1-note vs 3-note chime
- EPIC vs LEGENDARY: size 16px vs 24px (50% larger); screen effect (none vs vignette)

*Text label format*: rarity label must use text string ("COMMON" / "UNCOMMON" / etc.) — never rarity tier number only.

*Inventory list display*: rarity badge = colored corner accent on item card. Must include rarity text label adjacent to badge.

**When to Use**: Any time an item's rarity needs to be communicated. Use consistently — all equipment, loot, and ability tiers use this same visual language.

**When NOT to Use**: Do not create custom rarity indicators outside this 5-tier system.

---

### P-07: motion-intensity-slider

**Category**: Settings / Accessibility
**Used In**: Character Screen (#22) — Accessibility Settings section
**Derived From**: GDD #6 ScreenEffects Rule 3, `design/accessibility-requirements.md`

**Description**: A continuous slider for controlling screen shake intensity. This is a first-class accessibility feature (not hidden in "advanced settings"). The slider controls the `ScreenEffects.motion_intensity` property, which scales all screen shake amplitudes without affecting hit-pause timing.

**Specification**:
- Type: horizontal continuous slider
- Range: 0.0 to 1.0
- Default: 1.0 (full shake)
- Display: numeric percentage label ("0%" / "50%" / "100%") adjacent to slider
- Preset labels (optional for v0.2+): "None" / "Gentle" / "Full"
- Live preview: slider change should trigger a sample `HIT_HEAVY` shake preview in real-time so player can feel the result before saving
- Persistence: saves to `PersistenceLayer.write("settings.motion_intensity", value)`
- Boot: `ScreenEffects.set_motion_intensity(PersistenceLayer.read()["settings.motion_intensity"] ?? 1.0)` on autoload startup
- Visual: uses P-02 frameless bar style for track, amber fill for handle
- Accessibility: keyboard left/right adjusts in 0.1 increments; screen reader narrates label + value (v0.2+)
- Label CJK: "畫面震動強度" (繁體中文) / "Screen Shake Intensity" (English)

**When to Use**: Settings screen, accessibility section.

**When NOT to Use**: In-gameplay HUD (settings are not modified during active play).

---

### P-08: reduce-motion-toggle

**Category**: Settings / Accessibility
**Used In**: Character Screen (#22) — Accessibility Settings section
**Derived From**: GDD #7 Camera Q-V1 resolution, `design/accessibility-requirements.md`

**Description**: A boolean toggle for disabling camera zoom animations and locking the camera to avatar center. Distinct from P-07 motion-intensity-slider — this toggle addresses optical flow / stroboscopic effects from camera movement rather than screen shake vestibular effects.

**Specification**:
- Type: toggle switch (ON/OFF)
- Label CJK: "降低畫面動態" (繁體中文) / "Reduce Camera Motion" (English)
- Default: OFF (full motion)
- Effect when ON:
  - Camera dead-zone → 0% (camera locks to avatar center, eliminates optical flow)
  - Zoom animations disabled (no scale tweening during boss encounter focal mode)
  - Boss/loot rituals still trigger particle + audio channels (gameplay not removed — only camera motion disabled)
  - Note: per Apple HIG accessibility, 0% dead-zone eliminates both optical flow AND stroboscopic discontinuity
- Persistence: `PersistenceLayer.write("settings.reduce_camera_motion", enabled)`
- Boot: `CameraSystem.set_motion_reduction(PersistenceLayer.read()["settings.reduce_camera_motion"] ?? false)`
- Visual: standard toggle switch component. Left = OFF, Right = ON. Color: amber `#F2A93B` active, ink-mid `#2D323D` inactive.
- Accessibility: keyboard space bar toggles; screen reader narrates state ("on" / "off") on change (v0.2+)

**When to Use**: Settings screen, accessibility section, co-located with P-07 slider.

**When NOT to Use**: In-gameplay HUD.

---

### P-09: single-tap-exercise-switch

**Category**: Input
**Used In**: Exercise switch flow (GymSys app interaction, Pillar 2 enforcement)
**Derived From**: Game concept Pillar 2, `technical-preferences.md` Primary Input

**Description**: The primary gameplay input action — selecting the next exercise. Deliberately constrained to a single tap in the GymSys app (external). This is NOT a game UI interaction per se; it is the input contract that ALL game systems must respect when designing feedback for exercise switch events.

**Specification**:
- Input method: single tap on exercise name in GymSys app
- Device context: typically phone/tablet held in hand or set down, mid between sets
- Timing: player performs this during rest period, NOT mid-set
- Feedback in game: exercise switch triggers mini-boss spawn transition (EnemyDirector) → camera rim light transition → Exercise Switch mood state shift
- Input requirements for game UI:
  - No in-game input required to acknowledge the switch — it is fire-and-forget from game's perspective
  - Game must respond to `exercise_switched` event from GymSys BackendClient within next polling cycle (≤5.5s from event)
  - FORBIDDEN: any in-game overlay/modal that blocks gameplay and demands tap-to-dismiss during an exercise switch

**When to Use**: This pattern defines the constraint, not a UI component. Reference in any GDD or UX spec that involves exercise switching to ensure Pillar 2 compliance.

**When NOT to Use**: This pattern does not apply to menus, settings, or non-exercise-switch interactions.

---

### P-10: damage-number-popup

**Category**: Feedback
**Used In**: Combat VFX (#25)
**Derived From**: GDD #13 CombatResolver, Art Bible Section 7.D (damage number pop)

**Description**: Floating number that appears above an enemy/avatar when damage is dealt. Uses overshoot animation for satisfying impact feel. Number is proportional to actual damage value, giving player a sense of stat scaling.

**Specification**:
- Font: 7px HUD number (m5x7), monospace
- Color: white `#F5EFE0` for normal; amber `#F2A93B` for critical hit; family color for ability-specific
- Animation: spawn at hit position, scale 0.8 → 1.1× overshoot → settle 1.0×, float upward 8px over 0.8s, fade out last 0.2s
- Curve: `overshoot 1.1× → settle` in 250ms (art bible Section 7.D: "overshoot 1.1× → settle")
- Critical hit enhancement: yellow glow 1px, +20% size, 350ms animation
- Stacking: multiple simultaneous hits show separate numbers; cap at 6 concurrent popups (oldest removed first)
- Accessibility: numbers are purely feedback — gameplay does not depend on reading them. Screen reader ignores.
- Mobile: same specification, no LOD reduction (numbers are small, performance cost minimal)

**When to Use**: Every combat hit event from CombatResolver. Critical hits get enhanced treatment.

**When NOT to Use**: Stat changes from workout events (use P-03 stat-number-ticker instead — different semantic). Healing (use green color variant + upward arrow prefix "+").

---

### P-11: enemy-threat-hud-bar

**Category**: Data Display
**Used In**: HUD (#20) — Boss HP (BOSS_ENCOUNTER)
**Derived From**: GDD #20 Gym-Mode HUD (R4 B5 binding invariant), Art Bible Section 4.B/4.C colorblind safety, P-02 frameless-hud-bar (sibling variant)

**Description**: A horizontal depleting HP bar for a hostile entity (boss), displayed in the HUD top-center region. It is a deliberate visual *contrast* to the player's P-02 frameless-hud-bar so the player can distinguish "enemy threat" from "my strength" in a single 0.3s peripheral glance — **without relying on color, and without relying on the deplete animation** (a time-dimension cue that yields zero bits in a single-frame snapshot). This satisfies the binding accessibility rule that every semantic meaning carry ≥2 non-color signals.

**Specification**:
- Shape: rounded-rectangle body with **angular notched end-caps** (vs P-02 player bar's symmetric 2px rounded corners) — geometry is non-color channel #2
- **Threat glyph prefix** (non-color channel #1, glance-valid): 8×8 px enemy marker at the bar's leading edge — downward-pointing chevron ▼ + angular silhouette (skull / threat mark), `ui_ink_bg #1A1D24` outline + crimson fill. Player bar has NO prefix.
- Fill color: `ui_enemy_threat` crimson (recommended `#C8453E`, art-director final) — must be visibly distinct from Strike-class red `#E85A5A`. Color is enhancement channel #3 (NOT load-bearing).
- Track color: `ui_ink_mid #2D323D`
- Deplete direction: right → left (vs player non-depleting) — channel #4, valid only under focus
- Position: screen top-center (player anchor bars sit top-left) — separation by position
- Height: matches or slightly exceeds player HP bar (≥6px) for boss-encounter emphasis
- Animation: `ease-out quad` drain 200ms on damage; bar removed on boss defeat (no lingering empty bar)
- Accessibility: passes greyscale + deuteranopia/protanopia/tritanopia simulation — glyph prefix + angular geometry remain distinguishable from player bar at 8×8 squint (no color/deplete dependency)

**When to Use**: Hostile-entity HP in a HUD context where it must coexist with and be distinguished from player resource bars at a glance (boss fights, elite enemies).

**When NOT to Use**: Player resources — use [P-02 frameless-hud-bar](#p-02-frameless-hud-bar). Loot rarity / non-HP state — use the relevant feedback pattern. Generic enemy health in the world (non-HUD) — use floating world-space bar (to be defined if needed).

---

## Gaps & Patterns Needed

The following patterns are referenced in GDD UI Requirements sections but not yet fully defined. They should be authored when their corresponding screen UX spec is written:

| Pattern | Referenced In | Priority |
|---------|--------------|----------|
| Equipment item card | #17 Equipment + #21 Loot Modal | High (Pre-MVP) |
| Workout complete celebration | #16 Boss System Final Boss Kill | High (VS-tier) |
| Toast notification / inline message | Progress milestones, streak notifications | Medium (MVP) |
| Navigation header / back button | All screens | High (before any screen spec) |
| Settings toggle group | #22 Character Screen accessibility panel | Medium (MVP) |
| Avatar portrait frame | #22 Character Screen, P5 Mirror Moment | Medium (MVP) |
| Streak milestone badge | #8 Streak System display | Low (Pre-MVP) |
| Loading state / spinner | GymSys connection state | Medium (MVP) |

---

## Open Questions

- **OQ-P1**: Player journey map not yet created. Template available at `.claude/docs/templates/player-journey.md`. Run `/ux-design` Phase 2b or create it manually to establish player context for this screen. OQ carried from context gather phase.
- **OQ-P2**: Are there any patterns that should fire analytics events on interaction? (e.g., loot modal open/close, motion intensity changes) — resolve when #28 Telemetry GDD is authored.
- **OQ-P3**: Pattern P-05 (loot drop modal) requires input from #15 Loot Drop System GDD (not yet authored) to confirm timing and trigger contract. Modal spec is provisional pending #15.
- **OQ-P4**: Equipment item card pattern gap — will be defined during #17 Equipment & Inventory GDD authoring. Until then, no inventory screen UX spec can be finalized.
