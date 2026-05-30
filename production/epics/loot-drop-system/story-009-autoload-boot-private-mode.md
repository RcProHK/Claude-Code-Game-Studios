# Story 009: LootDropSystem Autoload — Boot Sequence + State Machine + Private Mode Gate

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-019`
*(Requirement: "44 ACs — 34 BLOCKING + 4 ADR-RATIFICATION-GATED" — private mode gate portion; AC-23/24 now unblocked since ADR-0003 Accepted 2026-05-30)*

**ADR Governing Implementation**: ADR-0005 (Accepted 2026-05-30) primary; ADR-0003 (Accepted 2026-05-30) secondary; ADR-0006 (Accepted) tertiary; ADR-0009 (Accepted 2026-05-29) quaternary
**ADR Decision Summary**: Autoload position 7 (after #14 EnemyDirector, before #21 LootRevealModal). Boot sequence: (1) load LootRarityConfig, (2) connect_for_initial_state GSM, (3) read PL pending, (4) await backend_ready, (5) subscribe signals, (6) TTL check. Private Mode: if `private_mode_detected = true` → state = Disabled, emit `loot_disabled("private_mode")`, all triggers short-circuit. DI seams: untyped `_persistence`, `_gsm`, `_streak_system`, `_workout_tracker`, `_enemy_director`, `_boss_system`, `_gymsys_client`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `await` in `_ready()` is permitted for backend_ready; use `get_tree().process_frame` for deferred transitions (ADR-0006 Contract 5). `connect_for_initial_state` requires sentinel pattern per Contract 6.

**Control Manifest Rules (Core layer)**:
- Required: GSM subscribers MUST use `connect_for_initial_state(callable)` — direct `state_changed.connect()` in `_ready()` loses signal (ADR-0006 Contract 6)
- Required: `_assert_knob_invariants()` called in `_ready()` BEFORE reconciliation (ADR-0006 Contract 8)
- Required: Handlers needing ambient context MUST late-bind via read API + explicit null branch (ADR-0009 §2)
- Forbidden: Never emit `state_changed` from autoload `_ready()` (ADR-0006 Contract 4)
- Forbidden: Never pass `.bind()` callables to `connect_for_initial_state` (ADR-0006 Contract 6)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-23** — Private mode on boot → DISABLED state; `loot_disabled("private_mode")` emitted; triggers short-circuit ✅
- [x] **AC-24** — Private mode mid-session → Disabled; volatile drops retained; no double-emit ✅
- [x] Autoload file `src/autoload/loot_drop_system.gd` with `class_name LootDropSystem extends Node` ✅
- [x] 6 states: BOOTING/IDLE/PENDING/REVEALING/SUSPENDED/DISABLED (Family A enum) ✅
- [x] Boot 6-step sequence implemented ✅
- [x] 7 untyped DI seams: `_persistence`, `_gsm`, `_streak_system`, `_workout_tracker`, `_enemy_director`, `_boss_system`, `_gymsys_client` ✅
- [x] Public API: `subscribe()`, `get_pending_drops()`, `get_drop()`, `is_private_mode_blocked()` ✅
- [x] `_assert_knob_invariants()` called first in `_ready()` (Contract 8) ✅
- [x] `connect_for_initial_state` for GSM, no `.bind()` (Contract 6) ✅
- [x] Boot budget ≤ 100ms documented ✅
- [x] **ADVISORY (AC-38)**: `rarity_tier` String in signal payload; forward constraint to #21 documented ✅
- [x] **ADVISORY (AC-39)**: FR-2 timing ≤ 100ms — forward constraint to #21 documented ✅
- [x] **ADVISORY (AC-40)**: `rarity_tier` as String in `loot_dropped` payload ✅

---

## Implementation Notes

*Derived from GDD Section C Boot Sequence + ADR-0005/0003/0006:*

**File**: `src/autoload/loot_drop_system.gd`

**Enum declarations** (or import from story 002's enum file):
```gdscript
class_name LootDropSystem extends Node

enum State { BOOTING, IDLE, PENDING, REVEALING, SUSPENDED, DISABLED }
var _state: State = State.BOOTING

# DI seams (untyped — typed Node fails compile-time member check per project pattern)
var _persistence = null
var _gsm = null
var _streak_system = null
var _workout_tracker = null
var _enemy_director = null
var _boss_system = null
var _gymsys_client = null

# Signals
signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
signal loot_pending_recovered(drop_id: String, source_event_kind: String)
signal loot_disabled(reason: String)
signal loot_committed(drop_id: String, canonical_id_from_backend: String)
signal loot_ceremony_capped(workout_id: String, capped_kill_count: int)

# Internal state
var _pending_drops: Dictionary = {}          # drop_id → LootDrop
var _drops_by_transition: Dictionary = {}    # transition_id → LootDrop (idempotency cache)
var _emit_counter_mini: Dictionary = {}      # workout_id → int
var _emit_counter_final: Dictionary = {}     # workout_id → int
var _config: LootRarityConfig = null
var _rng := RandomNumberGenerator.new()
```

**Boot sequence** (6 steps per GDD):
```gdscript
func _ready() -> void:
    _assert_knob_invariants()  # Contract 8: before reconciliation
    # Step 1: Load config (fail-hard if missing — EC-03)
    _config = load("res://data/loot/LootRarityConfig.tres")
    if _config == null:
        push_error("LootDropSystem: LootRarityConfig.tres missing — EC-03 hard fail")
        _enter_disabled("config_missing")
        return
    _config._validate()  # INV-1 + INV-6 asserts

    # Step 2: connect_for_initial_state (Contract 6)
    if _gsm != null:
        _gsm.connect_for_initial_state(_on_gsm_state_changed)

    # Private Mode gate (ADR-0003)
    if _persistence != null and _persistence.is_private_mode():
        _enter_disabled("private_mode")
        return

    # Step 3: Restore pending drops from PersistenceLayer
    if _persistence != null:
        _restore_pending_drops()

    # Step 4: await backend_ready (race guard — no signal subscriptions before this)
    if _gymsys_client != null:
        await _gymsys_client.backend_ready

    # Step 5: Subscribe upstream signals
    if _persistence != null:
        _persistence.private_mode_detected.connect(_on_private_mode_detected)
    # Boss/enemy/workout signals wired in Story 011

    # Step 6: TTL check
    _check_pending_ttl()

    _state = State.IDLE
    boot_completed.emit()  # optional boot signal
```

**Private Mode** (AC-23/24):
```gdscript
func _on_private_mode_detected() -> void:
    if _state == State.DISABLED:
        return
    _enter_disabled("private_mode")

func _enter_disabled(reason: String) -> void:
    _state = State.DISABLED
    loot_disabled.emit(reason)

func _process_trigger_event(_event_kind: int, _transition_id: String) -> void:
    if _state == State.DISABLED:
        return  # short-circuit per Rule 16
```

**`_assert_knob_invariants()`**:
```gdscript
func _assert_knob_invariants() -> void:
    assert(MINI_BOSS_CEREMONY_CAP >= 2, "INV-G2: ceremony cap must be ≥ 2")
    assert(FINAL_BOSS_RESERVED == 1, "FINAL_BOSS_RESERVED must be 1 (LOCKED)")
```

**Tests use MockPersistenceLayer** (same pattern as stat/ability system: inject via `_persistence = MockPersistenceLayer.new()` before calling `_ready()`). Use `await get_tree().process_frame` NOT `await _sut.ready`.

---

## Out of Scope

- Story 010: Idempotency + release guard (implements internal methods used by this story's trigger routing)
- Story 011: Signal handler wiring for boss_killed/enemy_killed/workout_completed (Step 5 stubs here)
- Story 012: 5-step persistence lifecycle (Step 3 full implementation)
- Story 014: Autoload position 7 registration in project.godot (BLOCKED on #14 EnemyDirector)

---

## QA Test Cases

**AC-23 (Private Mode boot gate)**:
- Given: `MockPersistenceLayer.is_private_mode()` returns true
- When: `LootDropSystem._ready()` executes (with injected mock)
- Then: `_state == State.DISABLED`; `loot_disabled("private_mode")` emitted; `_process_trigger_event()` returns early without generating any LootDrop
- Edge cases: Private mode detected before Step 4 (backend_ready) → must short-circuit before await

**AC-24 (Private Mode mid-session)**:
- Given: System in Idle state; `MockPersistenceLayer` emits `private_mode_detected`
- When: `_on_private_mode_detected()` called
- Then: `_state → Disabled`; new trigger events short-circuit; already-revealed drops remain in `_pending_drops` (volatile); loot_disabled("private_mode") emitted
- Edge cases: Already Disabled → no re-emit; signal connected exactly once

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/integration/loot/test_private_mode_disabled_state.gd` (AC-23)
- `tests/integration/loot/test_private_mode_mid_session.gd` (AC-24)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (CI lints), Story 002 (data types), Story 003 (LootRarityCalc), Story 004 (ceremony cap method), Story 005 (TTL check), Story 006 (reconcile method)
- Unlocks: Story 010 (idempotency methods added to this autoload), Story 011 (signal handlers added), Story 012 (persistence lifecycle), Story 014 (BLOCKED — boot position 7 registration)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 12/12 BLOCKING + 3 ADVISORY passing
**Deviations**:
- ADVISORY — `var _config: LootRarityConfig = null` DI seam added (story notes didn't list it). Allows tests to inject config without disk load; consistent with project DI seam pattern. Logged in tech-debt-register.md.
**Test Evidence**: Integration — 2 test files (14 test functions):
- `tests/integration/loot/test_private_mode_disabled_state.gd` (7 tests, AC-23)
- `tests/integration/loot/test_private_mode_mid_session.gd` (7 tests, AC-24)
**Code Review**: Complete (passed)
