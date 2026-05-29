# Story 013: Rule 7 — workout_completed Force-Transition to LootDrop

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-015`
*(Requirement text: "Rule 7: workout_completed priority 1 force-transition to LootDrop from any state (including BossEncounter → INTERRUPTED_WITH_CREDIT)")*

**ADR Governing Implementation**: ADR-0006 Contract 1 (transition from any state)
**ADR Decision Summary**: `workout_completed(workout_id)` event enqueued at priority 1 (higher than normal gameplay, lower than 401 session-invalidated). Forces transition to `LootDrop` from any state, including mid-BossEncounter with `BossOutcome.INTERRUPTED_WITH_CREDIT`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Priority 1 in event queue ensures workout_completed processes before normal transitions but after 401 invalidation.

**Control Manifest Rules (Foundation layer)**:
- Required: workout_completed enqueued at priority 1 (not 2)
- Required: BossEncounter → LootDrop uses INTERRUPTED_WITH_CREDIT outcome

---

## Acceptance Criteria

- [ ] **AC-gsm-wc-1**: GIVEN state = WORKOUT_ACTIVE, WHEN `workout_completed` event received, THEN state transitions to LOOT_DROP; `transition_id` generated.
- [ ] **AC-gsm-wc-2**: GIVEN state = BOSS_ENCOUNTER (mid-fight), WHEN `workout_completed` fires, THEN state = LOOT_DROP; `BossPayload.outcome = INTERRUPTED_WITH_CREDIT`.
- [ ] **AC-gsm-wc-3**: GIVEN `workout_completed` enqueued at priority 1 AND normal event at priority 2, WHEN queue drains, THEN `workout_completed` processed first.

---

## Implementation Notes

```gdscript
func on_workout_completed(workout_id: String) -> void:
    var event = {"type": "workout_completed", "workout_id": workout_id}
    enqueue_event(event, 1)  # priority 1 — force transition

# In event handler:
func _handle_workout_completed(event) -> void:
    var boss_outcome = BossPayload.BossOutcome.INTERRUPTED_WITH_CREDIT \
        if _current_state == GameState.BOSS_ENCOUNTER else null
    var payload = StateTransitionPayload.new()
    payload.source_event = "workout_completed"
    if boss_outcome != null:
        var boss = BossPayload.new()
        boss.outcome = boss_outcome
        payload.data = {"boss": boss.to_dict()}
    _request_transition_to(GameState.LOOT_DROP, payload)
```

---

## Out of Scope

- LootDrop reveal ceremony (LootDrop System epic)
- Story 011: Boot reconciliation that handles workout_completed during suspend

---

## QA Test Cases

**AC-gsm-wc-1** — Integration
- Given: GSM in WORKOUT_ACTIVE
- When: `on_workout_completed` called
- Then: state = LOOT_DROP; transition recorded

**AC-gsm-wc-2** — Integration
- Given: GSM in BOSS_ENCOUNTER
- When: `on_workout_completed` fires
- Then: state = LOOT_DROP; boss payload = INTERRUPTED_WITH_CREDIT

**AC-gsm-wc-3** — Unit
- Given: both events enqueued (workout=p1, normal=p2)
- When: 1 frame drains
- Then: workout_completed processed first

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/state_machine/test_workout_completed_transition.gd` — must pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (transition primitive), Story 009 (event queue)
- Unlocks: LootDrop System epic (gets transition_id from enemy_killed chain)
