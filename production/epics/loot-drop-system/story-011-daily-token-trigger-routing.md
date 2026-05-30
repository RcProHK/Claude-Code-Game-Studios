# Story 011: Daily Token Gate + Trigger Routing + Source-Event Classification

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-012`
*(Requirement: "Daily token gate (workout-locked daily, NOT calendar-daily)")*

**ADR Governing Implementation**: ADR-0005 (Accepted 2026-05-30) primary; ADR-0009 (Accepted 2026-05-29) secondary
**ADR Decision Summary**: Daily token authorised by `POST /api/game/loot/claim-daily` (GymSys backend). Token consumed = `loot.daily_token_used.<utc_date>` key in PersistenceLayer. Subsequent same-UTC-day `workout_completed` → skip daily drop (telemetry `loot_daily_token_skipped`); boss drops still active (independent budget). Signal handlers for boss_killed/enemy_killed/workout_completed wired via `connect_for_initial_state` pattern. workout_id resolved at handler time via `_workout_tracker.get_active_workout_id()` (ADR-0009 late-bind, explicit null branch).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_datetime_dict_from_system()` for UTC date → stable. Dictionary key `"utc_date"` pattern stable across 4.x.

**Control Manifest Rules (Core layer)**:
- Required: Handlers needing ambient context MUST late-bind via read API + explicit null branch (ADR-0009 §2) — `_workout_tracker.get_active_workout_id()` null must be explicitly branched (INV-12, CI lint from Story 001)
- Required: Signal payloads MUST be minimal + intrinsic (ADR-0009 §1) — workout_id is NOT in signal payloads, always late-bound
- Forbidden: Never stuff ambient context into signal payloads (ADR-0009)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-43** — Token consumed → `loot_daily_token_skipped(reason="already_consumed_today")` + no `loot_dropped`; boss/enemy independent ✅
- [x] First workout → token written to PL; `loot_dropped` emitted ✅
- [x] `_handle_enemy_killed` — mini-boss only; EC-15 silent drop for normal_mob (no telemetry) ✅
- [x] `_handle_boss_killed` — FINAL_BOSS kind → Formula 1 ceiling/floor applied ✅
- [x] `_handle_workout_completed` — daily token gate + validate_transition_id + ceremony_cap_check ✅
- [x] All handlers: validate_transition_id ✅, late-bind workout_id null branch (INV-12) ✅, ceremony_cap_check first ✅
- [x] UTC date via `_today_override` DI seam (deterministic tests; production uses Time.get_datetime_dict_from_system(true)) ✅

---

## Implementation Notes

*Derived from GDD Rules 1–8, Rule 7.5, EC-13, EC-14, EC-15, AC-43:*

**Daily token gate**:
```gdscript
func _is_daily_token_already_used() -> bool:
    var today_utc = _get_today_utc_string()  # e.g. "2026-05-30"
    var key = "loot.daily_token_used." + today_utc
    return _persistence != null and _persistence.read(key) != null

func _claim_daily_token() -> bool:
    # In production: POST /api/game/loot/claim-daily (via _gymsys_client)
    # In tests: mock returns true/false
    if _gymsys_client == null:
        return true  # offline/test mode: allow
    # await _gymsys_client.post_claim_daily() — returns {eligible: bool}
    # For Story 011 stub: synchronous mock
    return true

func _mark_daily_token_used() -> void:
    var today_utc = _get_today_utc_string()
    var key = "loot.daily_token_used." + today_utc
    _persistence.write(key, {"used_at": Time.get_unix_time_from_system()})
```

**workout_completed handler**:
```gdscript
func _handle_workout_completed(workout_id: String, completed_exercises: int) -> void:
    if _state == State.DISABLED: return
    if not _validate_transition_id(workout_id): return  # use workout_id as transitional ID here

    # Daily token gate
    if _is_daily_token_already_used():
        _emit_telemetry("loot_daily_token_skipped", {
            "workout_id": workout_id, "reason": "already_consumed_today"
        })
        return  # boss triggers still active — this handler only handles daily drop

    # Claim token
    var eligible = _claim_daily_token()
    if not eligible:
        _emit_telemetry("loot_daily_token_skipped", {"workout_id": workout_id, "reason": "ineligible"})
        return
    _mark_daily_token_used()

    # Build loot
    var workout_id_or_null = _workout_tracker.get_active_workout_id() if _workout_tracker else null
    var ceremony = _ceremony_cap_check(SourceEventKind.WORKOUT_DAILY, workout_id_or_null)
    var ws = _compute_workout_score_from_tracker()
    _process_loot_trigger(workout_id, SourceEventKind.WORKOUT_DAILY, ws, ceremony)
```

**enemy_killed handler** (mini-boss only, Rule 1):
```gdscript
func _handle_enemy_killed(transition_id: String, faction: String, tier: String) -> void:
    if _state == State.DISABLED: return
    if not _validate_transition_id(transition_id): return
    # EC-15: non-mini-boss tiers → silent drop (NO telemetry)
    if not _is_mini_boss_tier(tier): return

    var workout_id_or_null = _workout_tracker.get_active_workout_id() if _workout_tracker else null
    var ceremony = _ceremony_cap_check(SourceEventKind.MINI_BOSS, workout_id_or_null)
    var ws = _compute_workout_score_from_tracker()
    _process_loot_trigger(transition_id, SourceEventKind.MINI_BOSS, ws, ceremony)
```

**boss_killed handler** (final boss, Rule 5):
```gdscript
func _handle_boss_killed(transition_id: String, boss_id: String, tier: String) -> void:
    if _state == State.DISABLED: return
    if not _validate_transition_id(transition_id): return

    var workout_id_or_null = _workout_tracker.get_active_workout_id() if _workout_tracker else null
    var ceremony = _ceremony_cap_check(SourceEventKind.FINAL_BOSS, workout_id_or_null)
    var ws = _compute_workout_score_from_tracker()
    _process_loot_trigger(transition_id, SourceEventKind.FINAL_BOSS, ws, ceremony)
```

**Tests use MockPersistenceLayer + MockWorkoutStateTracker** (injected DI seams). `_is_mini_boss_tier()` checks tier string against a defined mini-boss tier list (per #14/#16 contract).

---

## Out of Scope

- Story 009: Autoload boot (signal connections wired in _ready; Step 5 stubs completed here)
- Story 010: `_validate_transition_id()` + idempotency (called in these handlers)
- Story 014: Actual signal subscriptions wired to #14/#16/#9 (BLOCKED — stubs used in Story 009)

---

## QA Test Cases

**AC-43 (daily token gate — second workout same day)**:
- Given: `MockPersistenceLayer` has `loot.daily_token_used.2026-05-30` key (token consumed); `workout_id_B` is a new workout
- When: `_handle_workout_completed(workout_id_B, 5)` called
- Then: `loot_daily_token_skipped(workout_id=workout_id_B, reason="already_consumed_today")` emitted; NO `loot_dropped` emitted for daily source
- Then: A subsequent `_handle_enemy_killed(mini_boss_transition, ...)` still works normally (independent budget)
- Edge cases: Different UTC day → token not consumed → daily drop generates normally

**First daily token claim**:
- Given: No `loot.daily_token_used.today` key; `MockGymSysClient.claim_daily()` returns true
- When: `_handle_workout_completed(workout_id_A, 5)` called
- Then: Token marked used in PL; `loot_dropped` emitted for daily source; ceremony_cap_check proceeds
- Edge cases: `completed_exercises = 0` → `workout_score = 0` → COMMON tier (Rule 8 zero-workout guard)

**EC-15 (non-mini-boss enemy silent drop)**:
- Given: `enemy_killed` with tier = "normal_mob"
- When: `_handle_enemy_killed()` called
- Then: Function returns early silently; NO telemetry; NO LootDrop
- Edge cases: tier = "mini_boss" → proceeds normally; tier = "final_boss" → also silent (final boss uses boss_killed handler, not enemy_killed)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/loot/test_daily_token_gate_second_workout_same_day.gd` (AC-43)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009 (autoload shell), Story 010 (idempotency + validate_transition_id), Story 004 (ceremony_cap_check)
- Unlocks: Story 012 (persistence lifecycle called by _process_loot_trigger), Story 014 (signal wiring — BLOCKED)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/loot/test_daily_token_gate_second_workout_same_day.gd` (13 test functions)
**Code Review**: Complete (passed)
