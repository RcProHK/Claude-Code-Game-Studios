# Story 014: Cross-System Contracts — GSM Signal Split + GymSys Age Pruning

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-012` (signal surface used by GSM + GymSys)
*(AC-30: GSM subscribes to write_completed and emits own tombstone_write_completed; AC-31: GymSys uses is_expired for age pruning)*

**ADR Governing Implementation**: ADR-0006 Contract 11 (telemetry hook — GSM's tombstone_write_completed signal fed by PersistenceLayer write_completed) + Contract 14 (MockPersistenceLayer for test)
**ADR Decision Summary**: GSM subscribes to `write_completed`, filters `key == "pending_transition"`, then emits its own `tombstone_write_completed(transition_id, latency_ms)`. PersistenceLayer NEVER emits `tombstone_write_completed` directly — domain ownership separation. GymSys Client uses `is_expired(committed_at, 35*86400)` helper for age-pruning.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal filtering in GDScript: `if key == "pending_transition":` inside handler. `35 * 86400 = 3024000` seconds = 35 days.

**Control Manifest Rules (Foundation layer)**:
- Required: PersistenceLayer infra layer must not know domain concepts (`transition_id` is GSM-domain)
- Required: Cross-system signal flow tested via `MockPersistenceLayer` + mock subscribers

---

## Acceptance Criteria

- [ ] **AC-30**: GIVEN mock GSM subscribed to `write_completed`, WHEN `write("pending_transition", tombstone_dict)` fires, THEN GSM's handler receives `(key:"pending_transition", latency_ms:int, is_touch:false)`; GSM emits its own `tombstone_write_completed(transition_id, latency_ms)` (verified via spy); PersistenceLayer's own signal list has NO `tombstone_write_completed` entry (cross-ref AC-19).
- [ ] **AC-31**: GIVEN mock GymSys Client with `_committed_tombstones={"tid_A:loot-commit": 1700000000}` (committed 35d ago) AND `IClock.unix_time = 1700000000 + 35*86400 + 1`, WHEN GymSys nightly age-prune sweep runs, THEN GymSys calls `PersistenceLayer.is_expired(1700000000, 35*86400)` → returns true → tombstone deleted via `PersistenceLayer.delete("gym._committed_tombstones.tid_A:loot-commit")` (verified via delete spy).
- [ ] **AC-31b**: GIVEN fresh tombstone `committed_at = Time.get_unix_time_from_system() - 1` (1 second ago), WHEN `PersistenceLayer.is_expired(committed_at, 35*86400)` called, THEN returns `false` (not expired — negative control confirms age-prune only removes old tombstones).

---

## Implementation Notes

*From GDD Interactions table + ADR-0006 Contract 11 + Contract 15:*

1. **AC-30 test setup**: `MockGameStateMachine` subscribes to `write_completed`:
   ```gdscript
   func _on_write_completed(key: String, latency_ms: int, is_touch: bool) -> void:
       if key == "pending_transition":
           emit_signal("tombstone_write_completed", "fake_transition_id_123", latency_ms)
   ```
   Test verifies PersistenceLayer's `write_completed` fires → mock GSM handler fires → mock GSM's `tombstone_write_completed` fires.

2. **AC-31 test setup**: `MockGymSysClient` calls `_persistence.is_expired(committed_at, 35 * 86400)` and, if true, calls `_persistence.delete(key)`. Use `IClock` mock for controlled time. Use `MockPersistenceLayer` (Story 005) with delete spy.

3. Cross-system test isolation: use `MockPersistenceLayer` (NOT real PersistenceLayer) so test doesn't depend on file I/O.

---

## Out of Scope

- Real GSM implementation of `tombstone_write_completed` → story in game-state-machine epic
- Real GymSys age-pruning implementation → story in gymsys-backend-client epic

---

## QA Test Cases

**AC-30** — Integration
- Given: `MockPersistenceLayer` + mock GSM subscribed to `write_completed`
- When: `write("pending_transition", {"transition_id": "tid_123"})` called
- Then: mock GSM handler fires; mock GSM's `tombstone_write_completed` emits with transition_id from tombstone; PersistenceLayer's `get_signal_list()` has no `tombstone_write_completed`

**AC-31** — Integration
- Given: `MockPersistenceLayer` with delete spy; `IClock` at `committed_at + 35d + 1s`; mock GymSys prune logic
- When: prune sweep executes
- Then: `is_expired` returns true; delete spy fires with correct namespace key

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/persistence-layer/test_gsm_signal_split.gd` — must pass
- `tests/integration/persistence-layer/test_gymsys_age_pruning.gd` — must pass

**Status**: [x] Created — 2 integration test files (6 tests total)

---

## Dependencies

- Depends on: Story 004 (SerializableResource — tombstone dict), Story 005 (MockPersistenceLayer), Story 006 (write_completed signal), Story 007 (is_expired)
- Unlocks: Story 015 (gate verifies cross-system binding)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-30 ✅ AC-31 ✅ AC-31b ✅)
**Deviations**: Tests use MockPersistenceLayer (not real autoload) for isolation. MockGSM defined as inner class in test file.
**Test Evidence**: Integration — 2 files, 6 tests
**Code Review**: APPROVED (inline)
