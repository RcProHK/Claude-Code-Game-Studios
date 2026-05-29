# Story 004: Tombstone Write + Forward-Recovery (Contract 2+3)

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (4+ hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-005`, `TR-gsm-006`
*(TR-005: "Forward-recovery reuses tombstone transition_id verbatim"; TR-006: "Tombstone via Contract 3 to_dict/from_dict + get_script().get_global_name()")*

**ADR Governing Implementation**: ADR-0006 Contract 2 (forward-recovery reuse) + Contract 3 (tombstone serialization envelope)
**ADR Decision Summary**: Rule 2 step 2 writes tombstone `{transition_id, from, to, payload}` via `PersistenceLayer.write("gsm.pending_transition", tombstone, flush=true)`. Rule 2 step 5 removes it. On WASM reload, Rule 5 boot reconciliation detects tombstone → forward-recovery replays steps 3-8 with ORIGINAL transition_id (never regenerates). `payload_type` via `get_script().get_global_name()`.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `JSON.stringify` preserves int64 within GDScript. `get_script().get_global_name()` returns class_name string. `ClassDB.instantiate(payload_type)` for forward-recovery.

**Control Manifest Rules (Foundation layer)**:
- Required: `payload_type = get_script().get_global_name()` (NOT `get_class()`)
- Required: Forward-recovery MUST reuse tombstone `transition_id` verbatim
- Forbidden: `_generate_transition_id()` in forward-recovery path (CI enforced)

---

## Acceptance Criteria

- [ ] **AC-11a**: GIVEN `BossPayload(outcome=DEFEATED)` embedded in tombstone, WHEN tombstone written via `PersistenceLayer.write("gsm.pending_transition", tombstone)` then read back, THEN `BossPayload.from_dict(read_result.payload)` returns `outcome==DEFEATED`; `payload_type == "BossPayload"` (NOT `"Resource"`).
- [ ] **AC-21**: GIVEN tombstone with `transition_id="test_id"`, WHEN forward-recovery runs, THEN forward-recovery uses `transition_id="test_id"` verbatim (no regeneration); CI lint confirms `_generate_transition_id` absent from `_forward_recover*` functions.
- [ ] **AC-32b**: GIVEN `_forward_recover_from_tombstone(tombstone)` implementation, WHEN scanned by CI, THEN zero calls to `_generate_transition_id()` (ADR-0006 Contract 2 binding).

---

## Implementation Notes

*From ADR-0006 Contract 2+3 (lines 134-270):*

```gdscript
# Rule 2 step 2: write tombstone (flush=true = critical path)
func _write_tombstone(tid: String, from: GameState, to: GameState, payload: StateTransitionPayload) -> void:
    var payload_type: String = ""
    if payload != null and payload.get_script() != null:
        payload_type = payload.get_script().get_global_name()
    var tombstone: Dictionary = {
        "transition_id": tid,
        "from": GameState.find_key(from),
        "to": GameState.find_key(to),
        "wall_clock_anchor": Time.get_unix_time_from_system(),
        "monotonic_anchor": Time.get_ticks_usec(),
        "payload": payload.to_dict() if payload is SerializableResource else {},
        "payload_type": payload_type,
    }
    PersistenceLayer.write("gsm.pending_transition", tombstone, true)

# Rule 2 step 5: remove tombstone
func _remove_tombstone() -> void:
    PersistenceLayer.delete("gsm.pending_transition")

# Forward-recovery (Rule 5 priority 3): MUST reuse existing transition_id
func _forward_recover_from_tombstone(tombstone: Dictionary) -> void:
    var existing_id: String = tombstone["transition_id"]   # REUSE — never regenerate
    # ... replay steps 3-8 with existing_id ...
```

CI lint `tools/ci/check_forward_recover_no_generate.sh`: scan `_forward_recover*` functions for `_generate_transition_id` calls.

---

## Out of Scope

- Story 011: Full boot reconciliation Rule 5 priority cascade
- Story 017: Backend write (Rule 2 step 6)

---

## QA Test Cases

**AC-11a** — Integration
- Given: BossPayload with DEFEATED outcome
- When: tombstone dict written via MockPersistenceLayer and read back
- Then: from_dict reconstructs correctly; payload_type = "BossPayload"

**AC-21** — Integration + CI
- Given: tombstone with known transition_id
- When: forward-recovery path executes
- Then: same transition_id used; no new ID generated

**AC-32b** — Static/CI
- Given: `_forward_recover*` functions
- When: CI scans for `_generate_transition_id`
- Then: zero matches

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/state_machine/test_tombstone_round_trip.gd` — must pass
- `tools/ci/check_forward_recover_no_generate.sh` — must exit 0

**Status**: [x] Created — `test_tombstone_round_trip.gd` (4 tests) + CI script

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-11a ✅ AC-21 ✅ AC-32b ✅)
**Deviations**: Forward-recovery payload dispatch handles StateTransitionPayload directly. BossPayload nested inside `payload.data["boss"]` per GDD line 603 — Story 011 wires full Rule 5 cascade.
**Test Evidence**: Integration — `test_tombstone_round_trip.gd` (4 tests) + `check_forward_recover_no_generate.sh`
**Code Review**: APPROVED (inline)

---

## Dependencies

- Depends on: Story 003 (transition_id), PersistenceLayer epic (Stories 002+003) Complete
- Unlocks: Story 011 (boot reconciliation uses tombstone detection)
