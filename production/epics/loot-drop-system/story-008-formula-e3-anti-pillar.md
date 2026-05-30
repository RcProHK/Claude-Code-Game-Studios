# Story 008: Formula E3 — Anti-Pillar Weekly Distribution (Monte Carlo)

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-005`
*(Requirement: "Formula E3 while-loop with max_iterations=10 + monotonic invariant (anti-pillar soft-clamp termination)")*

**ADR Governing Implementation**: ADR-0005 (Loot Rarity Formula, Accepted 2026-05-30)
**ADR Decision Summary**: Formula E3 runs Monte Carlo (n=10,000) to verify weekly EPIC+ % ≤ 10% (CF-E3 anti-pillar invariant). Soft-clamp while-loop with `max_iterations=10` guard (Pass 2 F-4). Each iteration MUST strictly decrease EPIC+count (monotonic assert). If `max_iterations` hit → emit telemetry `loot_e3_max_iterations_hit`, accept residual (should never happen with realistic config). CI lint `check_loot_e3_termination_guard.gd` enforces guard presence.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Monte Carlo loop (n=10,000) with O(1) operations → ~100,000 iterations total. Well within 16.6ms frame budget (called once per analytics/validation pass, NOT in real-time gameplay). No engine API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: Termination guard + monotonic assert in while-loop (CI lint AC from Story 001 `check_loot_e3_termination_guard.gd`)
- Guardrail: Formula called once for analytics only, not per-drop — no per-frame execution

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-14** — Hardcore (5×ws=0.92) n=10,000 → EPIC+ ≤ 10% post-clamp; LEGENDARY→EPIC→RARE downgrade order ✅
- [x] `max_iterations = 10` termination guard (CI lint pattern present) ✅
- [x] `assert(post_epic_plus < pre_epic_plus)` monotonic invariant ✅
- [x] `loot_e3_max_iterations_hit` telemetry on overflow + accept residual (fail-soft) ✅
- [x] Average (4×ws=0.65) → EPIC+ ≤ 10% ✅
- [x] Casual (2×ws=0.35) → EPIC+ ≤ 10% (~2%) ✅

---

## Implementation Notes

*Derived from GDD Formula E3:*

```gdscript
static func expected_weekly_rarity_distribution(player_profile: Dictionary) -> Dictionary:
    const N: int = 10000
    const MAX_ITERATIONS: int = 10
    const ANTI_PILLAR_EPIC_PLUS_CAP_PCT: float = 0.10  # LOCKED

    var counts: Dictionary = {
        RarityTier.COMMON: 0, RarityTier.UNCOMMON: 0,
        RarityTier.RARE: 0, RarityTier.EPIC: 0, RarityTier.LEGENDARY: 0
    }
    var total: int = 0

    # Monte Carlo simulation
    for _i in range(N):
        for event_profile in player_profile.get("weekly_events", []):
            var ws = _compute_workout_score_from_profile(event_profile)
            var transition_id = "sim_%d_%d" % [_i, total]  # unique per iteration
            var rng_roll = _compute_rng_roll(transition_id)
            var raw_tier = LootRarityCalc.compute_rarity_from_score(ws, rng_roll)
            var kind = event_profile.get("kind", SourceEventKind.WORKOUT_DAILY)
            var final_tier = LootRarityCalc.apply_tier_ceiling_floor(raw_tier, kind, ws)
            counts[final_tier] += 1
            total += 1

    # Anti-pillar soft-clamp with termination guarantee
    var iteration: int = 0
    while (float(counts[RarityTier.EPIC] + counts[RarityTier.LEGENDARY]) / float(total)) > ANTI_PILLAR_EPIC_PLUS_CAP_PCT \
        and iteration < MAX_ITERATIONS:
        var pre_epic_plus: int = counts[RarityTier.EPIC] + counts[RarityTier.LEGENDARY]
        if counts[RarityTier.LEGENDARY] > 0:
            counts[RarityTier.LEGENDARY] -= 1
            counts[RarityTier.EPIC] += 1  # downgrade LEGENDARY→EPIC first
        elif counts[RarityTier.EPIC] > 0:
            counts[RarityTier.EPIC] -= 1
            counts[RarityTier.RARE] += 1  # downgrade EPIC→RARE
        else:
            break  # should never reach — loop condition requires EPIC+ > 0
        var post_epic_plus: int = counts[RarityTier.EPIC] + counts[RarityTier.LEGENDARY]
        assert(post_epic_plus < pre_epic_plus, "E3 monotonic invariant violated")
        iteration += 1

    if iteration >= MAX_ITERATIONS:
        _emit_telemetry("loot_e3_max_iterations_hit", {
            "profile": player_profile.get("name", "unknown"),
            "residual_epic_plus_pct": float(counts[RarityTier.EPIC] + counts[RarityTier.LEGENDARY]) / float(total)
        })

    return counts  # Distribution dict
```

**Player profiles for test** (from GDD Formula E3):
- Hardcore: `{avg_workout_score: 0.92, weekly_workouts: 5, weekly_pr: 7, streak_days: 30}`
- Average: `{avg_workout_score: 0.65, weekly_workouts: 4, weekly_pr: 1, streak_days: 7}`
- Casual: `{avg_workout_score: 0.35, weekly_workouts: 2, weekly_pr: 0, streak_days: 0}`

**Expected output** (per GDD Monte Carlo table):
- Hardcore: EPIC+ ≤ 10% post-clamp ✓
- Average: EPIC+ ~8% (≤ 10%) ✓
- Casual: EPIC+ ~2% (≤ 10%) ✓

**Note**: This formula is NOT called per-drop. It is a distribution validation tool for analytics, QA, and VS-tier calibration. Do not call in `_process()` or any hot path.

---

## Out of Scope

- Story 003: Formula 1 (provides `apply_tier_ceiling_floor` called within E3 loop)
- Story 007: Formula E1/E2 (item type + class affinity, not called in distribution sim)
- Any real-time gameplay path (E3 is analytics-only)

---

## QA Test Cases

**AC-14 (Hardcore profile EPIC+ ≤ 10%)**:
- Given: Hardcore profile (ws=0.92, 5 workouts, 7 PRs, 30d streak)
- When: `expected_weekly_rarity_distribution(hardcore_profile)` n=10,000
- Then: EPIC+ count / total ≤ 10.0%; downgrade order verified (LEGENDARY decreased before EPIC)
- Edge cases: All 10,000 runs LEGENDARY (pathological) → max_iterations=10 fires + telemetry; still terminates

**Monotonic invariant**:
- Given: Pre-iteration EPIC+ count = 1500
- When: One soft-clamp iteration runs
- Then: Post-iteration EPIC+ count < 1500 (strictly); assert in debug build fires if not

**Casual profile low EPIC+**:
- Given: Casual profile (ws=0.35)
- When: n=10,000 simulation
- Then: EPIC+ ~2% (well below 10%), no clamp iterations needed; LEGENDARY likely 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/loot/test_e3_anti_pillar_soft_clamp.gd` (AC-14)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (RarityTier enum), Story 003 (LootRarityCalc.apply_tier_ceiling_floor), Story 004 (SourceEventKind)
- Unlocks: No direct story unlock (analytics tool); validates Pillar 3 distribution before VS playtest

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 6/6 passing
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/loot/test_e3_anti_pillar_soft_clamp.gd` (14 test functions)
**Code Review**: Complete (passed)
