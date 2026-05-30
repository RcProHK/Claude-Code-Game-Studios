# Story 004: Formula 2 ceremony_cap_check — Dual Pool + micro_ack

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-002`, `TR-loot-003`, `TR-loot-004`, `TR-loot-007`
*(TR-loot-002: workout_id resolution; TR-loot-003: ceremony cap split MINI=5 + FINAL=1; TR-loot-004: micro_ack ceremony tier; TR-loot-007: floor protection + LRU eviction)*

**ADR Governing Implementation**: ADR-0005 (Accepted 2026-05-30) primary; ADR-0009 (Accepted 2026-05-29) secondary
**ADR Decision Summary**: `ceremony_cap_check()` splits into two independent pools: `emit_counter_mini` (MINI_BOSS + WORKOUT_DAILY, cap=5) and `emit_counter_final` (FINAL_BOSS, reserved=1). Critically: `workout_id` is NOT in boss_killed/enemy_killed signal payloads — must be late-bound via `WorkoutStateTracker.get_active_workout_id()` with explicit null branch (ADR-0009 ambient context rule). Null branch → NON_CEREMONY_ROUTE (drop generates, no ceremony). Counter housekeeping: sweep stale entries + max 500-entry LRU eviction.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary` with `String` keys (workout_id UUIDs) is stable. No post-cutoff API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: Handlers needing ambient context MUST late-bind via read API + explicit null branch (ADR-0009 §2) — `WorkoutStateTracker.get_active_workout_id()` null must be handled explicitly (INV-12)
- Required: Signal payloads MUST be minimal + intrinsic (ADR-0009 §1) — workout_id is NOT in boss_killed payload, late-bound here
- Forbidden: Never assume ambient context is non-null in a handler (ADR-0009 §2)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-06** — 6th MINI_BOSS → MICRO_ACK; `loot_ceremony_capped` signal + telemetry (seq_num=6) ×1; FINAL_BOSS same workout → FULL_CEREMONY (independent pool) ✅
- [x] **AC-07** — W-99 calls 1-5 → FULL_CEREMONY; call 6 → MICRO_ACK; W-42 counter isolated (CF-5) ✅
- [x] null workout_id → NON_CEREMONY_ROUTE; `loot_drop_unbound` telemetry; no crash ✅
- [x] FINAL_BOSS overflow (2nd call) → FULL_CEREMONY + `loot_final_boss_ceremony_overflow` telemetry; no crash ✅
- [x] `_housekeeping_sweep_counters()` → evicts oldest when >MINI_POOL_MAX_ENTRIES(500); `loot_counter_emergency_evict` telemetry ✅

---

## Implementation Notes

*Derived from GDD Formula 2 + ADR-0009 §2:*

**Key method** (lives in `src/autoload/loot_drop_system.gd`):
```gdscript
func _ceremony_cap_check(kind: int, workout_id_or_null) -> int:  # returns CeremonyDecision
    # F-1: explicit null branch (ADR-0009 §2 mandatory)
    if workout_id_or_null == null:
        _emit_telemetry("loot_drop_unbound", {
            "transition_id": _current_transition_id,
            "reason": "no_active_workout"
        })
        return CeremonyDecision.NON_CEREMONY_ROUTE

    var wid: String = workout_id_or_null

    if kind == SourceEventKind.FINAL_BOSS:
        var current = _emit_counter_final.get(wid, 0)
        if current >= FINAL_BOSS_RESERVED:
            _emit_telemetry("loot_final_boss_ceremony_overflow", {"workout_id": wid})
            return CeremonyDecision.FULL_CEREMONY  # still emit (should never reach if rules honored)
        _emit_counter_final[wid] = current + 1
        return CeremonyDecision.FULL_CEREMONY

    # MINI_BOSS or WORKOUT_DAILY → mini pool
    var current = _emit_counter_mini.get(wid, 0)
    if current >= MINI_BOSS_CEREMONY_CAP:
        _emit_telemetry("loot_ceremony_capped", {"workout_id": wid, "capped_kill_count": current + 1})
        _emit_telemetry("loot_micro_ack_triggered", {
            "workout_id": wid,
            "mini_boss_seq_num": current + 1
        })
        return CeremonyDecision.MICRO_ACK
    _emit_counter_mini[wid] = current + 1
    return CeremonyDecision.FULL_CEREMONY
```

**Constants**:
```gdscript
const MINI_BOSS_CEREMONY_CAP: int = 5     # DESIGN-FROZEN, tuning range [2, 11]
const FINAL_BOSS_RESERVED: int = 1         # LOCKED
```

**INV-12 enforcement**: Any caller of `_ceremony_cap_check()` MUST first call `_workout_tracker.get_active_workout_id()` and pass the result (null or string) as `workout_id_or_null`. CI lint `check_loot_workout_id_resolution.gd` from Story 001 enforces this.

**DI seam for testing**: `_workout_tracker` is an untyped DI seam (per stat/ability system pattern). In tests: inject `MockWorkoutStateTracker` with configurable return value for `get_active_workout_id()`.

**Housekeeping** (call on boot + after workout_completed):
```gdscript
func _housekeeping_sweep_counters() -> void:
    var cutoff = Time.get_unix_time_from_system() - HARD_CAP_DAYS * 86400
    # Note: counters use workout_id as key (UUID string), not timestamp.
    # Housekeeping sweeps by age of the associated workout session.
    # Simplified: if dict.size() > 500, evict oldest (by insertion order approximation)
    if _emit_counter_mini.size() > 500:
        var oldest_key = _emit_counter_mini.keys()[0]
        _emit_counter_mini.erase(oldest_key)
        _emit_telemetry("loot_counter_emergency_evict", {"evicted_key": oldest_key})
```

**Integration test uses MockWorkoutStateTracker** (untyped, injected via `_workout_tracker = MockWorkoutStateTracker.new()`).

---

## Out of Scope

- Story 003: Formula 1 apply_tier_ceiling_floor (provides raw_tier; this story decides ceremony path)
- Story 009: Autoload integration (this story implements the pure logic method; boot wires it up)
- Story 011: Actual boss/workout signal handlers (call `_ceremony_cap_check()`)

---

## QA Test Cases

**AC-06 (micro_ack + final reservation independence)**:
- Given: Mock returns workout_id="W-42"; emit_counter_mini["W-42"] = 5 (pre-seeded)
- When: `_ceremony_cap_check(MINI_BOSS, "W-42", ...)` called (6th call)
- Then: Returns MICRO_ACK; telemetry `loot_ceremony_capped` + `loot_micro_ack_triggered` emitted exactly once
- Then: `_ceremony_cap_check(FINAL_BOSS, "W-42", ...)` → FULL_CEREMONY (independent pool)
- Edge cases: Seq_num in telemetry must be 6 (1-indexed current+1)

**AC-07 (per-workout isolation)**:
- Given: Fresh workout W-99, emit_counter_mini has no W-99 entry
- When: `_ceremony_cap_check(MINI_BOSS, "W-99", ...)` × 6
- Then: Calls 1-5 → FULL_CEREMONY; call 6 → MICRO_ACK; W-42 counter unchanged
- Edge cases: Different workout IDs never cross-pollute counters

**null workout_id branch**:
- Given: `MockWorkoutStateTracker.get_active_workout_id()` returns null
- When: `_ceremony_cap_check(MINI_BOSS, null, ...)` called
- Then: Returns NON_CEREMONY_ROUTE; `loot_drop_unbound` telemetry emitted; NO `loot_dropped` signal emitted; drop still generated + persisted
- Edge cases: Null branch must not crash; must emit telemetry exactly once

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/integration/loot/test_ceremony_cap_micro_ack_and_final_reservation.gd` (AC-06)
- `tests/unit/loot/test_ceremony_cap_per_workout_isolation.gd` (AC-07)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (enums: SourceEventKind, CeremonyDecision), Story 003 (Formula 1 for raw_tier context)
- Unlocks: Story 009 (autoload wires ceremony_cap_check into signal handlers), Story 011 (signal handlers call ceremony_cap_check)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 5/5 passing
**Deviations**:
1. ADVISORY — `var current` → `final_current`/`mini_current` (GDScript same-scope redeclaration compile error — necessary fix, logic unchanged). Logged in tech-debt-register.md.
2. ADVISORY — `MINI_POOL_MAX_ENTRIES = 500` constant added (story notes had magic number 500 — improvement per coding-standards data-driven rule). Logged in tech-debt-register.md.
**Test Evidence**: Integration — 2 test files (17 test functions):
- `tests/integration/loot/test_ceremony_cap_micro_ack_and_final_reservation.gd` (9 tests, AC-06)
- `tests/unit/loot/test_ceremony_cap_per_workout_isolation.gd` (8 tests, AC-07)
**Code Review**: Complete (passed)
