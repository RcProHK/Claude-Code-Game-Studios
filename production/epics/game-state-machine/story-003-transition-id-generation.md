# Story 003: transition_id Generation — Collision-Safe Counter

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-004`
*(Requirement text: "`transition_id` = `wall_clock_ms × 1000 + persisted_monotonic_counter`; opaque string; persisted via `_transition_id_counter` PersistenceLayer key")*

**ADR Governing Implementation**: ADR-0006 Contract 2 (transition_id Collision-Safe Generation)
**ADR Decision Summary**: Format `"%d_%d_%s_%s" % [wall_clock_ms, counter, from, to]`. Counter persisted in PersistenceLayer under `_transition_id_counter` key. Counter incremented BEFORE write (atomic increment-then-persist). Opaque — never parsed back. Collision probability < 10^-9 per session.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_unix_time_from_system() * 1000.0` for wall_clock_ms. `PersistenceLayer.read()` sync at boot. `PersistenceLayer.write()` sync per transition.

**Control Manifest Rules (Foundation layer)**:
- Required: Counter incremented BEFORE PersistenceLayer.write (atomic increment-first)
- Required: transition_id is opaque — no code may parse it to recover from/to

---

## Acceptance Criteria

- [ ] **AC-gsm-tid-1**: GIVEN fresh boot with no persisted counter, WHEN `_generate_transition_id("BOOTING", "IDLE")` called, THEN returns non-empty String with format matching `"\d+_\d+_BOOTING_IDLE"`; counter = 1 stored in PersistenceLayer.
- [ ] **AC-gsm-tid-2**: GIVEN counter = N in PersistenceLayer, WHEN `_generate_transition_id(from, to)` called, THEN counter is N+1; same wall_clock_ms with different counter → different IDs (collision-safe within session).
- [ ] **AC-gsm-tid-3**: GIVEN transition_id generated, WHEN stored and reloaded via PersistenceLayer round-trip, THEN restored string is byte-identical.

---

## Implementation Notes

*From ADR-0006 Contract 2 (lines 134-169):*

```gdscript
const TRANSITION_ID_COUNTER_KEY: String = "_transition_id_counter"

func _generate_transition_id(from: String, to: String) -> String:
    var wall_clock_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
    var counter: int = PersistenceLayer.read(TRANSITION_ID_COUNTER_KEY)
    if counter == null: counter = 0
    counter += 1
    PersistenceLayer.write(TRANSITION_ID_COUNTER_KEY, counter)  # increment FIRST
    return "%d_%d_%s_%s" % [wall_clock_ms, counter, from, to]
```

Note: `from`/`to` are GameState enum string names (e.g. "BOOTING", "IDLE") for debug readability, but the `transition_id` is opaque — no parsing allowed.

Forward-recovery (`_forward_recover_from_tombstone`) MUST reuse tombstone's existing `transition_id` verbatim — NEVER regenerate. See Story 004.

---

## Out of Scope

- Story 004: Forward-recovery reuse of tombstone transition_id
- Story 002: The lock/transition framework that calls this

---

## QA Test Cases

**AC-gsm-tid-1** — Unit
- Given: MockPersistenceLayer with no counter stored
- When: `_generate_transition_id("BOOTING", "IDLE")` called
- Then: string matches regex pattern; counter=1 written to mock

**AC-gsm-tid-2** — Unit
- Given: MockPersistenceLayer with counter=5
- When: two transitions generated in rapid succession
- Then: IDs are distinct (counter 6 vs 7)

**AC-gsm-tid-3** — Unit
- Given: generated transition_id string
- When: written to PersistenceLayer and read back
- Then: byte-identical string returned

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_transition_id_generation.gd` — must pass

**Status**: [x] Created — `test_transition_id_generation.gd` (5 tests)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-gsm-tid-1 ✅ AC-gsm-tid-2 ✅ AC-gsm-tid-3 ✅)
**Deviations**: None
**Test Evidence**: Logic — `test_transition_id_generation.gd` (5 tests)
**Code Review**: APPROVED (inline)

---

## Dependencies

- Depends on: Story 002 (transition framework calls this), Story 005 (PersistenceLayer implemented)
- Unlocks: Story 004 (tombstone uses transition_id)
