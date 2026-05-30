# Story 004: Unlock Path A (PR_BREAKTHROUGH) + Atomic Write Sequence

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-4 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-10/13/17/29)
**Deviations**: ADVISORY — `ability.unlocked.*` namespace per ADR-0003 (Proposed) used under ADR-0006 C11; ability_unlocked signal is 2-arg (id, source:int) per AC-20 locked signature (GDD Rule 13 mentioned is_initial — dropped per AC-20). Persist-first change required injecting MockPersistenceLayer into 2 Batch A tests (regression fixed same session).
**Test Evidence**: test_unlock_path_a_pr_breakthrough.gd, test_persistence_flush_policy.gd, test_atomic_write_ordering.gd, test_persist_fail_rollback.gd
**Code Review**: Batch B self-verified (persist-first → mutate → emit; UnlockRecord SerializableResource)

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-008`, `TR-ability-010`, `TR-ability-014`
*(TR-ability-008: Unlock evaluation Path A (PR_BREAKTHROUGH). TR-ability-010: Persistence namespace per-source flush policy. TR-ability-014: Atomic unlock write ordering: persist → mutate → emit)*

**ADR Governing Implementation**: ADR-0006 Contract 3 (SerializableResource envelope — `UnlockRecord`); ADR-0003 (Proposed ⚠️ — `ability.unlocked.*` namespace; proceed under ADR-0006 C11 Accepted, mark advisory).
**ADR Decision Summary**: Unlock write sequence is persist-FIRST (prevent phantom state); `UnlockRecord` extends `SerializableResource`; key format `"ability.unlocked." + ability_id.to_lower()`. PR_BREAKTHROUGH flush=true (critical), STAT_THRESHOLD flush=false (debounced).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PersistenceLayer.write(key, value_dict, flush: bool) -> bool` returns bool (WASM-side accept; not IDB commit ack — Contract 11). `Time.get_unix_time_from_system()` for unlock timestamp. Untyped `_persistence = null` DI seam (see ADR-0006 + streak_system pattern).

**Control Manifest Rules (Core layer)**:
- Required: Persist BEFORE in-memory mutate — if write returns false, abort (leave `_unlocked_abilities` unchanged)
- Required: Emit AFTER in-memory mutate — subscriber must see new ability via `get_unlocked_abilities()` inside handler
- Forbidden: Never `await` in `unlock_ability` or any helper it calls (ADR-0006 Contract 12)

---

## Acceptance Criteria

- [ ] **AC-10** — GIVEN STR=210, STRIKE_TIER_1 already unlocked, STRIKE_TIER_2+TIER_3 locked, WHEN `unlock_ability(AbilityId.STRIKE_TIER_3_OVERHAND, UnlockSource.PR_BREAKTHROUGH)` invoked (via internal handler with STR context), THEN returns `true`, `_unlocked_abilities` contains `STRIKE_TIER_3_OVERHAND`, `ability_unlocked(STRIKE_TIER_3_OVERHAND, PR_BREAKTHROUGH)` emits exactly once, PersistenceLayer.write for key `"ability.unlocked.strike_tier_3_overhand"` called BEFORE in-memory mutation (Rule 13 persist-first ordering).
- [ ] **AC-13** — GIVEN AbilitySystem with mocked PersistenceLayer recording `write(key, value, flush)` calls, WHEN `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, UnlockSource.PR_BREAKTHROUGH)` AND `unlock_ability(AbilityId.STRIKE_TIER_2_HOOK, UnlockSource.STAT_THRESHOLD)` invoked, THEN PR_BREAKTHROUGH write recorded with key `"ability.unlocked.strike_tier_1_jab"` + `flush=true`; STAT_THRESHOLD write with `flush=false`.
- [ ] **AC-17** — GIVEN mocked PersistenceLayer recording timestamps AND signal listener, WHEN `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, UnlockSource.PR_BREAKTHROUGH)` invoked, THEN: PL.write timestamp T1 < `_unlocked_abilities` mutation T2 < `ability_unlocked` signal T3 (strict ordering: persist → mutate → emit).
- [ ] **AC-29** — GIVEN mocked PersistenceLayer.write returns `false`, `_unlocked_abilities` empty, WHEN `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, UnlockSource.PR_BREAKTHROUGH)` invoked, THEN returns `false`, `_unlocked_abilities` remains empty (Rule 13 rollback — in-memory unchanged), `ability_unlock_save_failed(STRIKE_TIER_1_JAB)` emits exactly once, no `ability_unlocked` signal fires.

---

## Implementation Notes

*From GDD Rules 7, 9, 13 + ADR-0006 Contract 3/11:*

1. **`UnlockRecord` class** (extends `SerializableResource` per ADR-0006 Contract 3):
   ```gdscript
   class UnlockRecord extends SerializableResource:
       var first_unlocked_at_unix: int = 0
       var source: int = UnlockSource.INITIAL_STATE  # int, not typed enum, for serialization
       var source_event_id: String = ""
       func to_dict() -> Dictionary: ...
       static func from_dict(data: Dictionary) -> SerializableResource: ...
   ```
2. **`_persistence` DI seam** (untyped, duck-typed — see streak_system.gd pattern):
   ```gdscript
   var _persistence = null
   func _ready() -> void:
       if _persistence == null: _persistence = PersistenceLayer
   ```
3. **`flush_for_source(source: UnlockSource) -> bool`**:
   - `PR_BREAKTHROUGH` → `true` (critical unlock moment — must survive crash)
   - `STAT_THRESHOLD` → `false` (debounced — Stat System already batched)
4. **`unlock_ability` body** (after Story 003 allow-list + idempotent guard):
   - Step 1: Validate (source enum, allow-list, idempotent guard) — from Story 003
   - Step 2: Construct `UnlockRecord`
   - Step 3: `persist_ok = _persistence.write("ability.unlocked." + String(ability_id), record.to_dict(), flush_for_source(source))`
   - Step 4: If not persist_ok → emit `ability_unlock_save_failed` + return false
   - Step 5: `_unlocked_abilities[ability_id] = record`  (mutate AFTER persist)
   - Step 6: `ability_unlocked.emit(ability_id, source, false)` (emit AFTER mutate)
   - Step 7: return true
5. **Path A trigger** (`_on_pr_breakthrough` internal handler):
   - Subscribed to #18's `pr_breakthrough(stat_id, magnitude)` signal (mock for VS tier)
   - Calls `_evaluate_unlock(stat_id, StatSystem.get_stat(stat_id), PR_BREAKTHROUGH)`
   - `_evaluate_unlock` calls `unlock_ability` internally (sets `_unlock_call_permitted = true`)
6. **`ability.unlocked.*` namespace** — ADR-0003 Proposed (advisory for VS tier; proceed per ADR-0006 C11).

---

## Out of Scope

- Story 005: Path B (STAT_THRESHOLD via stat_changed subscription)
- Story 007: Boot reconciliation reading back these keys
- Story 008: GSM Suspended gate (unlock also rejects during Suspended)

---

## QA Test Cases

**Story Type**: Integration (PersistenceLayer mock required)

- **AC-10**: Path A PR_BREAKTHROUGH unlock
  - Given: MockPL (write=true), STRIKE_TIER_1 pre-set as unlocked, STR mock stat=210
  - When: `unlock_ability(STRIKE_TIER_3_OVERHAND, PR_BREAKTHROUGH)` via internal path
  - Then: Returns true; `_unlocked_abilities` has STRIKE_TIER_3; `ability_unlocked` fires; PL.write called with correct key before mutation

- **AC-13**: Flush policy
  - Given: FlushSpyPersistence recording `{key, value, flush}` per write
  - When: Two unlock calls — PR_BREAKTHROUGH and STAT_THRESHOLD
  - Then: First write flush=true; second write flush=false

- **AC-17**: Strict persist→mutate→emit ordering
  - Given: MockPL with counter + signal watch
  - When: Single unlock call
  - Then: PL.write happens first (counter T1), then `_unlocked_abilities` mutation (T2), then signal (T3); T1 < T2 < T3

- **AC-29**: Persist-fail rollback
  - Given: MockPL always returns false from write()
  - When: `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)`
  - Then: Returns false; `_unlocked_abilities` empty; `ability_unlock_save_failed` fires; no `ability_unlocked` fires

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ability_system/test_unlock_path_a_pr_breakthrough.gd`, `tests/unit/ability_system/test_persistence_flush_policy.gd`, `tests/unit/ability_system/test_atomic_write_ordering.gd`, `tests/unit/ability_system/test_persist_fail_rollback.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (allow-list + idempotent guard must exist; Story 002 enums required)
- Unlocks: Story 005 (Path B builds on same `unlock_ability` + `_evaluate_unlock` logic), Story 007 (boot reads keys written here)
