# Story 003: Formula 1 apply_tier_ceiling_floor + Pillar 1 Anti-Fabrication Proofs

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-001`, `TR-loot-006`
*(TR-loot-001: "Loot rarity formula per ADR-0005"; TR-loot-006: "Rule 4 dual-gate: workout-score tier ceiling floor(workout_score×5)")*

**ADR Governing Implementation**: ADR-0005 (Loot Rarity Formula, Accepted 2026-05-30)
**ADR Decision Summary**: Two-stage formula — Stage 1: `loot_rarity_score = workout_score×0.75 + rng_roll×0.25`; Stage 2: `final_tier = max(raw_tier, COMMON)`. Formula 1 applies source-event ceiling/floor on top. Max RNG alone (workout_score=0) = 0.25 < EPIC threshold 0.72 → architectural Pillar 1 proof. `tier_from_score()` uses data-driven thresholds from `LootRarityConfig.tres`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator.seed` (stable); GDScript `float` = IEEE 754 double on WASM (no precision concern for threshold comparisons, verified per ADR-0005). `clamp()`, `min()`, `max()` stable across all 4.x.

**Control Manifest Rules (Core layer)**:
- Required: Formula uses `_rng.seed = hash(transition_id)` before every roll — NEVER global `randf()`/`randi()` (ADR-0005 + CI lint AC-26)
- Forbidden: Re-derive ADR-0005 formula constants — read from `LootRarityConfig.tres` only (ADR-0005 data-driven)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-01** — 1,000-iter Pillar 1 proof: all kinds × all tiers with ws=0.0 → COMMON ✅
- [x] **AC-02** — Monte Carlo 10,000 deterministic sweep (ws=0.001): zero EPIC results; proof `max_score=0.2508 < 0.72` ✅
- [x] **AC-03** — `apply_tier_ceiling_floor(EPIC, MINI_BOSS, 0.78)` → RARE; dual-gate implemented ✅
- [x] **AC-04** — `apply_tier_ceiling_floor(COMMON, FINAL_BOSS, 0.4)` → UNCOMMON; LEGENDARY→LEGENDARY ✅
- [x] **AC-05** — zero-workout guard (ws=0.0) → COMMON overrides all kinds including FINAL_BOSS; INV-11 ✅
- [x] `tier_from_score(score)` — descending threshold scan, COMMON fallback, boundary tests ✅
- [x] Rule 4 dual-gate: `ws_ceiling = int(floor(clamp(ws,0,1)×5))` in MINI_BOSS branch ✅
- [x] `compute_rarity()` — full pipeline with `_compute_workout_score` + `_compute_rng_roll` (seeded) ✅

---

## Implementation Notes

*Derived from ADR-0005 Decision + GDD Formula 1:*

Implement as a pure static class or inner class `LootRarityCalc` (NOT autoload — pure function, no state):

```gdscript
class_name LootRarityCalc

static func compute_rarity(
    completed_exercises: int,
    pr_breakthrough_count: int,
    streak_count: int,
    transition_id: String,
    config: LootRarityConfig = null
) -> int:  # returns RarityTier ordinal
    if config == null:
        config = load("res://data/loot/LootRarityConfig.tres")
    var ws = _compute_workout_score(completed_exercises, pr_breakthrough_count, streak_count, config)
    var rng_roll = _compute_rng_roll(transition_id)
    var loot_score = clamp(ws * config.workout_weight + rng_roll * config.rng_weight, 0.0, 1.0)
    var raw_tier = tier_from_score(loot_score, config)
    return max(raw_tier, LootDropSystem.RarityTier.COMMON)  # Pillar 3 floor

static func apply_tier_ceiling_floor(raw_tier: int, kind: int, ws: float) -> int:
    # Logic order: zero-workout guard → COMMON floor → source-event clamp
    if ws == 0.0:
        return LootDropSystem.RarityTier.COMMON  # Rule 8 + INV-11
    if kind == LootDropSystem.SourceEventKind.FINAL_BOSS:
        return max(raw_tier, LootDropSystem.RarityTier.UNCOMMON)  # Rule 5 floor
    if kind == LootDropSystem.SourceEventKind.MINI_BOSS:
        var ws_ceiling = floor(clamp(ws, 0.0, 1.0) * 5)  # Rule 4 dual-gate
        var capped = min(raw_tier, LootDropSystem.RarityTier.RARE)    # hard RARE ceiling
        capped = min(capped, int(ws_ceiling))
        return max(capped, LootDropSystem.RarityTier.COMMON)  # Pillar 3 floor
    # WORKOUT_DAILY: ADR-0005 Pillar 3 floor only
    return max(raw_tier, LootDropSystem.RarityTier.COMMON)

static func tier_from_score(score: float, config: LootRarityConfig) -> int:
    for i in range(config.tier_thresholds.size() - 1, -1, -1):
        if score >= config.tier_thresholds[i]:
            return config.tier_values[i]
    return LootDropSystem.RarityTier.COMMON  # fallback
```

**workout_score computation**:
```gdscript
static func _compute_workout_score(exercises: int, prs: int, streak: int, config: LootRarityConfig) -> float:
    var volume = min(1.0, float(exercises) / float(config.target_exercises))
    var pr_factor = min(config.max_pr_factor, 1.0 + config.pr_bonus_per_pr * float(prs))
    var streak_factor = 1.0 + min(float(streak) / config.streak_scale, config.max_streak_bonus)
    return clamp(volume * pr_factor * streak_factor, 0.0, 1.0)

static func _compute_rng_roll(transition_id: String) -> float:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(transition_id)
    return rng.randf()
```

**Test file location**: `tests/unit/loot/test_pillar1_proofs.gd` covers AC-01/02; `tests/unit/loot/test_apply_tier_ceiling_floor.gd` covers AC-03/04/05.

---

## Out of Scope

- Story 002: `LootRarityConfig` resource definition (must exist before this story)
- Story 004: Formula 2 ceremony_cap_check (uses Formula 1 output but is a separate concern)
- Story 009: Autoload integration (Formula 1 is pure function, no autoload needed)

---

## QA Test Cases

**AC-01 (Pillar 1 — workout_score=0 never exceeds COMMON)**:
- Given: `_rng.seed = hash("T-deadbeef")`, `ws = 0.0`, kind = WORKOUT_DAILY
- When: `apply_tier_ceiling_floor()` called 1,000 times across varied `transition_id` seeds
- Then: All results == COMMON; assert `result == RarityTier.COMMON` each iteration
- Edge cases: Also test kind=MINI_BOSS + kind=FINAL_BOSS with ws=0.0 → both should still return COMMON (zero-workout guard is highest priority)

**AC-02 (max RNG < EPIC threshold proof)**:
- Given: `workout_score = 0.001` (epsilon), `rng_roll ∈ [0.0, 1.0]`
- When: Monte Carlo 10,000 runs with varied `transition_id`
- Then: `raw_tier` never reaches EPIC (max score = 0.001×0.75 + 1.0×0.25 = 0.2508 < 0.72); zero EPIC results
- Edge cases: Test boundary at `workout_score = 0.0` → max score = 0.25 < 0.35 (below COMMON threshold)

**AC-03 (MINI_BOSS ceiling)**:
- Given: `raw_tier = EPIC, kind = MINI_BOSS, ws = 0.78`
- When: `apply_tier_ceiling_floor()` called
- Then: result == RARE; `ws_ceiling = floor(0.78 × 5) = 3` (EPIC ordinal), but hard cap is RARE (ordinal 2) → effective = RARE
- Edge cases: `raw_tier = RARE, ws = 0.6` → RARE ≤ ceiling → no change; `ws = 0.2, raw_tier = COMMON` → ws_ceiling = 1 (UNCOMMON) but COMMON < UNCOMMON ceiling → COMMON (Pillar 3 floor)

**AC-04 (FINAL_BOSS floor)**:
- Given: `raw_tier = COMMON, kind = FINAL_BOSS, ws = 0.4`
- When: `apply_tier_ceiling_floor()` called
- Then: result == UNCOMMON (lifted by floor)
- Edge cases: `raw_tier = LEGENDARY, kind = FINAL_BOSS, ws = 0.9` → LEGENDARY unchanged (no ceiling for final boss)

**AC-05 (zero-workout guard overrides ALL)**:
- Given: `raw_tier = LEGENDARY, kind = WORKOUT_DAILY, ws = 0.0`
- When: `apply_tier_ceiling_floor()` called
- Then: result == COMMON (zero-workout guard beats Pillar 3 floor — already at COMMON)
- Edge cases: `kind = FINAL_BOSS, ws = 0.0, raw_tier = LEGENDARY` → COMMON (zero-workout guard highest priority, overrides final boss floor)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 
- `tests/unit/loot/test_pillar1_rng_alone_never_exceeds_common.gd` (AC-01)
- `tests/unit/loot/test_rng_ceiling_below_epic.gd` (AC-02)
- `tests/unit/loot/test_apply_tier_ceiling_floor.gd` (AC-03, AC-04, AC-05)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (LootRarityConfig + enums must exist)
- Unlocks: Story 004 (Formula 2 uses Formula 1 output), Story 009 (autoload uses compute_rarity)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 8/8 passing
**Deviations**:
1. ADVISORY — `LootEnums.RarityTier` / `LootEnums.SourceEventKind` used instead of story notes' `LootDropSystem.*`. Autoload is a stub (Story 009). When Story 009 creates the autoload with enum re-exports, caller sites may need updating. Logged in tech-debt-register.md.
2. ADVISORY — Config path `res://assets/data/loot/loot_rarity_config.tres` (aligned to CI lint), not `res://data/loot/` as stated in story notes. Logged in tech-debt-register.md.
**Test Evidence**: Logic — 3 unit test files (23 test functions total):
- `tests/unit/loot/test_pillar1_rng_alone_never_exceeds_common.gd` (AC-01)
- `tests/unit/loot/test_rng_ceiling_below_epic.gd` (AC-02)
- `tests/unit/loot/test_apply_tier_ceiling_floor.gd` (AC-03/04/05)
**Code Review**: Complete (passed)
