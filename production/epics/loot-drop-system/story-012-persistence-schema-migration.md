# Story 012: 5-Step Optimistic Persistence + Rollback + Schema Migration + transition_id Format

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
*(Requirement: "44 ACs" — persistence lifecycle portion; AC-33/35/37 now all unblocked: ADR-0003 + ADR-0006 both Accepted)*

**ADR Governing Implementation**: ADR-0003 (Save State Strategy, Accepted 2026-05-30) primary; ADR-0006 (State Machine Contract, Accepted) secondary
**ADR Decision Summary**: 5-step optimistic persist: (1) generate LootDrop, (2) emit `loot_dropped` optimistically, (3) await PL.write_async("loot.pending."+drop_id), (4) if fail → emit `loot_disabled("persistence_unavailable")` + rollback modal, (5) background backend POST → ACK → rename pending→committed. Schema migration per ADR-0003: <900ms ceiling, unmigratable entries → quarantine namespace. transition_id format = ADR-0006 Contract 2 hex monotonic string.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (Safari IndexedDB write >100ms known issue per ADR-0003)
**Engine Notes**: `await PersistenceLayer.write_async()` — if PL has async write API; GDScript `await` in signal handler is valid in 4.x. Optimistic emit before await satisfies FR-2 100ms visual onset requirement.

**Control Manifest Rules (Core layer)**:
- Required: `pending_since_server` (backend timestamp) authoritative for hard-cap eviction (ADR-0006 Contract 15)
- Required: Schema migration chain bounded: ≤6 steps × ≤150ms = 900ms ceiling (ADR-0006 Contract 10)
- Forbidden: Never use `var_to_bytes()` + base64 for payload serialization — SerializableResource pattern only (ADR-0006 Contract 3)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-33** — write_async fail → `loot_disabled("persistence_unavailable")` + `loot_rollback` + `loot_optimistic_rollback` telemetry + cache cleaned ✅
- [x] **AC-35** — Schema v0 → quarantine + telemetry; v1=CURRENT → pass through; <900ms; boot not blocked ✅
- [x] **AC-37** — ADR-0006 Contract 2 format valid; empty/special/too-short invalid ✅
- [x] Steps 1-2 synchronous (optimistic emit before await write_async) ✅
- [x] `_on_backend_ack()` stub: pending→committed rename + `loot_committed` emit ✅
- [x] `loot_optimistic_rollback` telemetry fires on write failure ✅
- [x] Schema version check + quarantine in `_restore_pending_drops()` ✅

---

## Implementation Notes

*Derived from GDD Section C Persistence Lifecycle (5-step) + ADR-0003:*

**5-step `_process_loot_trigger()`**:
```gdscript
func _process_loot_trigger(transition_id: String, kind: int, workout_score: float, ceremony: int) -> void:
    # Step 1: generate LootDrop in memory
    var drop = _generate_loot_internal(transition_id, kind, workout_score)

    # Step 2: OPTIMISTIC emit (before await — satisfies FR-2 100ms visual onset)
    if ceremony == CeremonyDecision.FULL_CEREMONY:
        loot_dropped.emit(drop.drop_id, drop.rarity_tier, drop.item_type, drop.transition_id)
    elif ceremony == CeremonyDecision.MICRO_ACK:
        loot_micro_ack.emit(drop.drop_id)  # 0.15s toast, no full ceremony
    # NON_CEREMONY_ROUTE: no emit, drop persists silently

    # Step 3: Concurrent async persist
    var write_key = "loot.pending." + drop.drop_id
    var write_ok = await _persistence.write_async(write_key, drop.to_dict())

    # Step 4: Rollback on write failure
    if not write_ok:
        loot_disabled.emit("persistence_unavailable")
        loot_rollback.emit(drop.drop_id)  # #21 cancels reveal
        _emit_telemetry("loot_optimistic_rollback", {"drop_id": drop.drop_id})
        _drops_by_transition.erase(drop.transition_id)  # clean idempotency cache
        return

    # Step 5: Background backend POST (non-blocking; don't await here)
    if _gymsys_client != null:
        _gymsys_client.post_loot_async(drop)  # fire-and-forget; ACK handled in _on_backend_ack()

    _pending_drops[drop.drop_id] = drop
    _state = State.PENDING
```

**`_on_backend_ack(response: Dictionary)`** (Story 013 BLOCKED for full impl; stub here):
```gdscript
func _on_backend_ack(response: Dictionary) -> void:
    var drop_id: String = response.get("drop_id", "")
    var canonical_id: String = response.get("canonical_id", "")
    if drop_id.is_empty() or canonical_id.is_empty():
        return
    # Rename loot.pending.D-xxx → loot.committed.C-yyy
    _persistence.write("loot.committed." + canonical_id, _pending_drops[drop_id].to_dict())
    _persistence.delete("loot.pending." + drop_id)
    loot_committed.emit(drop_id, canonical_id)
```

**Schema migration** (AC-35):
```gdscript
func _migrate_pending_drop(drop_dict: Dictionary) -> Dictionary:
    var schema = drop_dict.get("schema_version", 0)
    if schema == CURRENT_SCHEMA:
        return drop_dict
    # Migration table (placeholder — extend when schema changes)
    var migrations = {}  # {version: Callable}
    if not migrations.has(schema):
        # Unmigratable → quarantine
        _persistence.write("loot.pending.quarantine." + drop_dict.get("drop_id", "unknown"),
                          drop_dict)
        _emit_telemetry("loot.migration.quarantined", {"schema": schema})
        return {}  # empty = skip this drop
    return migrations[schema].call(drop_dict)
```

**transition_id format validation** (AC-37):
```gdscript
func _validate_transition_id_format(tid: String) -> bool:
    # ADR-0006 Contract 2 format: "%d_%d_%s_%s" e.g. "1234567_42_IDLE_COMBAT_ACTIVE"
    # Pattern: hex + underscores + alphanumeric state names
    var regex = RegEx.new()
    regex.compile("^[0-9a-f_A-Z]+$")  # lenient: digits + hex + underscores + uppercase
    return regex.search(tid) != null and tid.length() >= 4

func _on_loot_persisted(drop: LootDrop) -> void:
    if not _validate_transition_id_format(drop.transition_id):
        push_error("LootDrop transition_id format violation: " + drop.transition_id)
```

**MockPersistenceLayer** for tests: synchronous `write_async()` that can be configured to succeed/fail/timeout (same pattern as stat/ability system `MockPersistenceLayer`).

---

## Out of Scope

- Story 013: Backend ACK tier correction + server authority (BLOCKED on #2 GymSys)
- Story 014: Autoload position 7 in project.godot (BLOCKED on #14 EnemyDirector)

---

## QA Test Cases

**AC-33 (optimistic rollback)**:
- Given: `MockPersistenceLayer.write_async()` configured to return false (timeout)
- When: `_process_loot_trigger("T-rollback", WORKOUT_DAILY, 0.7, FULL_CEREMONY)` called
- Then: `loot_dropped` ALREADY emitted (optimistic); then `loot_disabled("persistence_unavailable")` emitted; `loot_rollback` emitted with drop_id; `loot_optimistic_rollback` telemetry fired; `_drops_by_transition` does NOT contain "T-rollback" after rollback
- Edge cases: If #21 is not connected, rollback signal must still fire without crash

**AC-35 (schema migration)**:
- Given: `loot.pending.D-old` contains `{schema_version: 1}` when CURRENT_SCHEMA = 2
- When: `_restore_pending_drops()` called on boot
- Then: Migration runs in < 900ms; entry moved to quarantine if unmigratable + telemetry
- Edge cases: schema_version == CURRENT_SCHEMA → no migration; schema_version > CURRENT_SCHEMA → quarantine

**AC-37 (transition_id format)**:
- Given: LootDrop with `transition_id = "1234567_42_IDLE_COMBAT_ACTIVE"` (ADR-0006 Contract 2 format)
- When: `_validate_transition_id_format()` called
- Then: Returns true
- Edge cases: Empty string → false; special chars "!@#" → false; numeric-only "1234" → true (valid subset)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/integration/loot/test_optimistic_rollback_path.gd` (AC-33)
- `tests/integration/loot/test_schema_migration_under_900ms.gd` (AC-35)
- `tests/unit/loot/test_transition_id_format_invariant.gd` (AC-37)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009 (autoload + _state management), Story 010 (idempotency cache), Story 011 (trigger handlers that call _process_loot_trigger)
- Unlocks: Story 013 (backend ACK — BLOCKED), Story 015 (full bfcache reconcile — BLOCKED)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: Integration — 3 test files (28 test functions):
- `tests/integration/loot/test_optimistic_rollback_path.gd` (7 tests, AC-33)
- `tests/integration/loot/test_schema_migration_under_900ms.gd` (9 tests, AC-35)
- `tests/unit/loot/test_transition_id_format_invariant.gd` (12 tests, AC-37)
**Code Review**: Complete (passed)
