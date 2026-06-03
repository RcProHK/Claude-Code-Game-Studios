# Gym-Mode HUD

> **Status**: In Design (skeleton + scope locked 2026-06-03; sections pending fresh-session authoring)
> **Author**: Frank + (pending)
> **Last Updated**: 2026-06-03
> **Implements Pillar**: **Pillar 2 — 無壓力陪伴 (Frictionless Companion)** [PRIMARY owner]
> **System #**: 20 (Presentation / MVP tier)
> **Depends On**: #11 Stat System (Approved) · #12 Ability System (Approved) · #4 Audio Manager (Approved, merged) · #2 GymSysBackendClient (set_logged event source) · #9 WorkoutStateTracker (forwarded workout events)
> **Next**: run `/design-system gym-mode-hud` in a FRESH session — it resumes section-by-section from this skeleton.

---

## ⚠️ DESIGN CONTEXT — pre-loaded constraints for authoring (read first)

*This block captures the locked context gathered when the skeleton was created (EG-2 open). The fresh authoring session should honour all of it. Delete/fold into the real sections as they are written.*

### Pillar 2 invariants (game-concept.md)
- **Core interaction = one-tap**: 「揀下一個動作 = 揀下一條 game 路線」(game-concept line 39/124) — choosing the next exercise IS the player's only input. No mid-set interaction.
- **HARD invariant** (line 184): the HUD **MUST NOT** require player attention during a set ("呢一秒 tap 一下先有 buff" is forbidden). Input frictionless, output ceremonial.
- **Visual** (line 214): HUD / stat display = high-saturation amber-gold; HP / EXP / progress readable at a glance (≤0.3s glance per the silhouette-first principle). HUD + loot text + 爆裝 VFX are FULLY saturated; world layer desaturated 30% (Layer Discipline, line 208).
- Context docs to cite: `design/art/art-bible.md`, `design/ux/interaction-patterns.md`.

### What the HUD displays (from deps)
- #11 Stat System: HP / EXP / stat values (read-only via Stat queries).
- #12 Ability System: equipped/unlocked abilities (read-only).
- #9 WorkoutStateTracker: workout phase / set progress (read-only forwarded events / queries) for progress display.

### 🔑 EG-2 GATE — #4 Audio Manager contracts this GDD MUST absorb (the reason EG-2 exists)
1. **Silent-mode banner soft-gate** (audio-manager.md Rule 5 / UI Requirements / AC-06b):
   - web + pre-gesture (LOCKED) → #20 shows a「㩒一下開聲」banner. Player's first tap (the core next-exercise input) naturally unlocks audio; banner subscribes `AudioManager.audio_unlocked` and dismisses.
   - **Banner MUST be a SOFT-GATE**: workout counting start (backend event-driven set progression) must be gated AFTER the banner is tap-dismissed (`audio_unlocked` emitted). Reason: #2 GymSys HTTP polling can push `set_logged`/`streak_updated` BEFORE the first screen tap; if the banner is not a gate, the first set's SFX all drop → breaks Pillar 1 "每個真實動作有聲音回應". Contract: implement "banner tap → unlock → THEN workout session start counts backend events"; use `AudioManager.is_audio_unlocked()` as the ready signal.
   - #20 only consumes `is_audio_unlocked()` + `audio_unlocked`; banner visual/copy is #20's.
2. **Audio-trigger consumer forwarding contract** (audio-manager.md Dependencies forward contract — relocated here by EG-1 Option B, 2026-06-03):
   - #20 (or a dedicated workout-feedback adapter) is the presentation-layer **audio-trigger consumer** that actually calls `AudioManager.play_sfx` for workout SFX (`set_complete`, `workout_complete`; coordinate `streak_chime` with #8).
   - Subscribe `#2.set_logged` directly (the #18 PR-Detection precedent — consumers subscribe #2, NOT via #9 which stays a pure data layer) + `AudioManager.audio_unlocked`.
   - **LOCKED → buffer** pending mid/high SFX (queue/defer); on `audio_unlocked` → flush. `low` priority drops (no buffer). Only buffer mid/high.
   - Owns the `set_complete` × `streak_chime` same-frame **80-120ms stagger** (this consumer is the funnel that knows same-frame timing; AudioManager is a stateless gateway and does NOT delay).
   - ⚠️ This is NOT #9 WST (locked pure data layer). #4 audio GDD forward contract already amended to point here.

### Cross-system / open items to resolve during authoring
- streak_chime is emitted by #8 Streak — confirm routing so the #20 consumer can stagger it against set_complete (a #8↔#20 co-design point).
- #33 Attention Budget & Interaction Policy (Pillar 2 enforcer) — #20 must respect `is_input_permitted()` gating.
- UX Flag: run `/ux-design gym-mode-hud` for the screen/HUD spec before epics (per game-concept line 368 + design-docs UX-spec convention). Stories should cite `design/ux/[screen].md`, not this GDD directly.

---

## Overview

[To be designed]

## Player Fantasy

[To be designed]

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
