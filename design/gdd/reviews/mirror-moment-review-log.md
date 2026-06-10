# Mirror Moment System (#29) — Design Review Log

## Review — 2026-06-10 — Verdict: APPROVED (NEEDS REVISION → revise-now → APPROVED, same session)
Scope signal: M
Specialists: degraded-inline (game-designer + systems-designer + qa-lead + creative-director perspectives; harness-constrained — no agent spawn, grep-verify against shipped src/GDD, same mode as #26 Pass 6)
Blocking items: 1 | Recommended: 2 | Nice-to-have: 2

### Verdict path
First review → **NEEDS REVISION** (1 BLOCKING + 2 Recommended) → user directive「跟推薦、唔問、直接做」→ revise-now in-session → all resolved → **APPROVED**.

### Citation grep-verify (project-mandated) — ALL EXACT ✅
- #26 contract (8 items) vs shipped `avatar-renderer.md` v2.1: `avatar_evolution_milestone` / `avatar_micro_evolution` / `get_evolution_snapshot()->AvatarEvolutionSnapshot` (8/8 fields) / **CR-15 deferral attribution correct** (line 182, NOT a ceremony rule) / `CR-5b` shader hue·outline·breathing / `Formula 3b` `rolling_7day_stat_delta>0` / `EC-ASSET-1`+`EMERGENCY_AVATAR.tres`+`_derive_sprite_frames` / `source_metrics` keys.
- Shipped src: GSM `GameState` enum 9/9 states (`game_state_machine.gd:80-89`) · `play(preset_id, position, multiplier)` (`particle_system_wrapper.gd:419`) · `get_current_state()->GameState` (`:241`).
- Bidirectional deps ✅: #26 line 9 lists #29 · #17 Rule 10 lists #29 · #18 Pillar-5 supporting. All 7 declared-dep GDD files exist on disk.

### Blocking resolved
- **B-1 [systems-designer] Celebration-burst layer routing self-contradiction + hidden #5 HARD constraint.** GDD line 408 (Visual: world ParticleLayer z≥20) contradicted line 432 + CR-M8 (UI: CelebrationVFXLayer 110). Grep-verified #5: ONLY `LOOT_BURST`/`LOOT_RARE_BURST` → LARGE tier (`_select_tier:599`) → reparent onto `_celebration_layer` (CelebrationVFXLayer 110, #21-owned, `register_celebration_layer:331` / `_apply_celebration_residence:359`); non-loot presets stay world-layer (z≤7) → BELOW modal backdrop → burst invisible during ceremony. **Fix**: reconciled all layer refs to CelebrationVFXLayer 110; reframed Q-OQ-PRESET as a HARD constraint (MVP MUST reuse a LOOT preset — a new avatar-evolution preset needs a #5 amendment doing BOTH size==9→N AND LARGE-tier/celebration-residence carve-out); added celebration-layer-infra dependency note (#5 handshake must be live in IDLE ceremony when #21 modal inactive).

### Recommended resolved
- **R-1 [game-designer] Flagship caption over-promises vs declared data.** Overview/Fantasy marquee ("第 6 週 · 練咗 18 次 · …") needs week-number + workout-count, but `source_metrics={stat_total, ability_count, max_class_depth, achieved_at_unix}` has neither, and #9 WST (only count source) was undeclared. **Fix**: added #9 Workout-State Tracker as Soft dep (deps + interactions tables; Soft count 4→5); reframed Q-OQ-REFLECTION-N → Q-OQ-CAPTION-N covering BOTH ceremony types; marquee examples annotated as "enriched form" (base = tier/class only, null-safe per AC-06).
- **R-2 [creative-director] ADR-0010 stale Key Interfaces.** ADR-0010 Proposed draft named `evolution_tier_changed` / `get_current_evolution_tier()` / `capture_avatar_snapshot()->Texture2D` — none shipped. **Fix at ratification**: replaced Key Interfaces block with real contract; corrected Architecture Diagram signal name; flipped Status Proposed→Accepted (2026-06-10); marked all 4 Validation Criteria met.

### Nice-to-have applied
- **N-1**: Formula 1 redundant term (`presented_this_window == not cadence_open`) — already self-acknowledged in GDD, left as documented.
- **N-2**: added intentional-註記 — `week_had_change` sticky-latch absorbs the phase difference between #26 account-anchored micro cadence and #29 ceremony-anchored cadence (no drift bug).

### Senior verdict [creative-director synthesis]
Architecturally sound — ADR-0010 seam clean (#29 zero tier-state, verified by CR-M14 + CI-MM-1 + pure gating/selection formulas). Top design risk (post-T3 REFLECTION repetitiveness / FT-2 ≥30% share rate) correctly scoped as a playtest-gated MVP hypothesis, not a spec defect. The single BLOCKING (B-1) was a citation/precision-level seam gap (layer routing), not an architectural fault — the #26-Pass-5 pattern. 4 Hard deps (#26/#1/#3/#5) all shipped → epic can open with no upstream block.

Prior verdict resolved: First review

### Carry to epic (advisory)
- Q-OQ-PRESET: lock "reuse LOOT preset" pre-`/create-stories` (B-1 HARD constraint) — confirm CelebrationVFXLayer 110 is persistent shared infra registered at #5/#21 boot.
- Q-OQ-CAPTION-N: wire #9 surface at epic time, else caption degrades to tier/class (null-safe).
- Q-OQ-CAPTURE: native-screenshot-only locked for MVP (in-app capture-to-PNG → v0.2).
- R-5-class coupling: if a NEW #5 preset is ever chosen, the #5 amendment is broader than #26's R-5 (adds LARGE-tier + celebration-residence carve-out on top of size==9→N).
