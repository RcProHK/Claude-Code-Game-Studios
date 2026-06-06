# Story 011: enemy_killed → DYING self-filtered wiring

> **Epic**: Boss System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06

**Completion Notes (2026-06-06)**: `tests/unit/boss_system/test_enemy_killed_to_dying.gd` (5 tests; combined 267scr/1753/1752pass/0fail/1pending). The `_on_enemy_killed_self_listen(payload: EnemyKilledPayload)` handler + `_enter_state(DYING)` idempotency were already wired in `boss_instance.gd` (Story 002 scaffold) — Story 011 finalizes + comprehensively tests them: AC-11b (own id→DYING / other id→ignored / double-fire idempotent), AC-08 (exact transition_id equality filter, not prefix), EC-24 (HP→0 then enemy_killed = single DYING). Off-tree bosses so DYING→`_play_death_and_free` does cleanup-only (no queue_free), keeping the node assertable. Mock payload = real `EnemyKilledPayload.new()` (file-level class_name) with transition_id set. No source change (the 002 handler was correct).

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 8 (boss kill → enemy_killed) + Rule 11 (`_on_enemy_killed_self_listen` + `_enter_state`)
**Requirement**: `TR-boss-006` (enemy_killed.transition_id chain integrity)

**ADR Governing Implementation**: ADR-0009 (Signal Payload Schema) — primary; ADR-0006 (transition_id) secondary
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_on_enemy_killed_self_listen(payload: EnemyKilledPayload)` — `EnemyKilledPayload` is a file-level `class_name` @ src/core/enemy_killed_payload.gd:31 (extends SerializableResource). #14 real signal `enemy_director.gd:328 = enemy_killed(payload)` (untyped param, payload built via `EnemyKilledPayload.new()`); typed-handler-on-untyped-signal is valid in 4.6. `_enter_state(EnemyDirector.EnemyAIState.DYING)` (autoload-nested enum, prefix).

**Control Manifest Rules (Feature)**: #14 owns `enemy_killed` emission (Rule 8); #16 only LISTENS for its own id. Self-filter `payload.transition_id != self.transition_id → return`.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-08**: boss spawned tid="abc" + dies → observed `enemy_killed` payload.transition_id == "abc" (exact, not regenerated).
- [ ] **AC-11b**: handler connected to mock `enemy_killed(payload)` (real `EnemyKilledPayload.new()` stub with transition_id set): payload.transition_id=="abc" → `_enter_state(EnemyDirector.EnemyAIState.DYING)` once; =="OTHER" → no DYING (self-filter); second "abc" fire OR `_set_current_hp(0)` after DYING → no double-cleanup (idempotent `_enter_state` guard).
- [ ] **AC-28** (EC-24): same-frame multiple killing-blow hits (AOE) → only first triggers death; subsequent drop + `boss.dup_kill_blow` (INFO); loot once (#14 idempotency dedupe by enemy_instance_id).

---

## Implementation Notes

*From GDD Rule 11:*

- `_enter_state(new_state)`: idempotent re-entry no-op (`if _ai_state == new_state: return`) = double-cleanup guard root; `match new_state: EnemyDirector.EnemyAIState.DYING: _play_death_and_free()`.
- #16 does NOT generate transition_id; it inherits from #14 BossAnchor commit (NEVER #3).

---

## Out of Scope

- **Story 012**: `_play_death_and_free` body + cleanup. #14's emission + AOE dedupe (Approved/implemented in #14).

---

## QA Test Cases

- **AC-11b**: mock signal with `EnemyKilledPayload.new()` (tid="abc") → DYING once. tid="OTHER" → no DYING. double-fire → single cleanup.
- **AC-08**: assert payload.transition_id verbatim == spawn tid.
- **AC-28**: 3 same-frame kill hits → 1 enemy_killed observed + 2 dup_kill_blow.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/feature/boss_system/test_enemy_killed_to_dying.gd` + `test_kill_txn_chain.gd` + `test_ec24_aoe_kill_dedupe.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (BossInstance + connect), Story 007 (spawn sets transition_id)
- Unlocks: Story 012 (death → cleanup)
