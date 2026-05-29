# Story 005: Observer Pattern + connect_for_initial_state

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-005`
*(TR-stat-005: `connect_for_initial_state` delivers 7 initial stats — ADR-006 Contract 6 binding)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 6 (`connect_for_initial_state` sentinel subscription), Contract 7 (`_last_emit_tick` race guard)
**ADR Decision Summary**: Subscribers must use `connect_for_initial_state(callable)` helper — plain `.connect()` loses the boot-time stat delivery. The helper immediately callv's current values (7 stats with `INITIAL_STATE` sentinel + `is_initial=true`), then registers the callable for future `stat_changed` emissions.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `callv([stat_id, old_val, new_val, source, is_initial])` — 5-parameter callable. `.bind()` extras on the callable break `callv` positional args — CI lint AC-34 (Story 001) catches this. `CONNECT_ONE_SHOT` not applicable here — subscriber stays connected for all future mutations.

**Control Manifest Rules (Core layer)**:
- Required: Subscribers MUST use `connect_for_initial_state(callable)` — plain `.connect("stat_changed", cb)` is FORBIDDEN (CI lint AC-34)
- Required: Callable signature must be 5 params: `(stat_id: StringName, old_value: float, new_value: float, source: StatSource, is_initial: bool)`
- Forbidden: Never pass `.bind()` extras to `connect_for_initial_state` — shifts positional args in callv

---

## Acceptance Criteria

- [ ] **AC-08** — GIVEN Stat System boot completed (Ready substate, STR=12.0, DEX=15.0, VIT=10.0, derived stats computed from these), WHEN a subscriber calls `StatSystem.connect_for_initial_state(my_callable)`, THEN `my_callable` is immediately invoked 7 times (once per stat_id: STR, DEX, VIT, MAX_HP, ATTACK_POWER, MOVE_SPEED, CRIT_CHANCE), each invocation has `source = StatSource.INITIAL_STATE` and `is_initial = true`, and the delivered `new_value` matches the current `_base` value (for base stats) or computed derived value (for derived stats).

---

## Implementation Notes

*From GDD Rule 6 + ADR-0006 Contract 6 Addendum 2026-05-28:*

1. **`connect_for_initial_state(callable: Callable) -> void`**:
   - Capture `_last_emit_tick` at connect time (Contract 7 race guard)
   - Immediately iterate all 7 stat_ids and callv the subscriber:
     ```gdscript
     for stat_id in _ALL_STAT_IDS:
         var current := get_stat(stat_id)
         callable.callv([stat_id, current, current, StatSource.INITIAL_STATE, true])
     ```
   - Then connect the callable to `stat_changed` signal for future mutations:
     ```gdscript
     stat_changed.connect(callable)
     ```
   - Race guard (Contract 7): deferred lambda checks if a real mutation already fired before initial delivery arrives — if `_last_emit_tick > captured_tick`, skip the callv (real mutation already delivered fresher state)
2. **Initial delivery `old_value == new_value`** — boot delivery has no "change"; both old and new carry the current value. Subscriber should treat `is_initial=true` as "sync state" not "a change happened".
3. **Sentinel detection** — subscriber may branch on `if source == StatSource.INITIAL_STATE` to distinguish boot delivery from real mutation. Both paths typically do the same thing (e.g., HUD redraw either way).
4. **7 stat_ids constant** — `const _ALL_STAT_IDS: Array[StringName] = [StatId.STR, StatId.DEX, StatId.VIT, StatId.MAX_HP, StatId.ATTACK_POWER, StatId.MOVE_SPEED, StatId.CRIT_CHANCE]`
5. **No `.bind()` in caller** — caller must pass bare Callable without `.bind()` extras. Helper will push_error in debug build if callable has bound args.

---

## Out of Scope

- Story 006: `stat_changed` emit in `apply_stat_delta` (real mutation path)
- Story 008: GSM Suspended gate — GSM subscribes in `_ready()` via `connect_for_initial_state`

---

## QA Test Cases

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_connect_for_initial_state.gd`

- **AC-08**: connect_for_initial_state delivers 7 initial stats
  - Given: Stat System Ready; `_base = {STR:12.0, DEX:15.0, VIT:10.0}`; derived computed accordingly
  - When: `connect_for_initial_state(my_callable)`
  - Then: `my_callable` invoked exactly 7 times; each invocation has `source == StatSource.INITIAL_STATE` and `is_initial == true`; values match `get_stat(stat_id)` for each
  - Edge cases: Call `connect_for_initial_state` twice (second subscriber also gets 7 deliveries — multiple independent subscribers); subscriber using `.bind()` extras → push_error in debug build; `connect_for_initial_state` called BEFORE `_ready()` completes (Initialising substate) → behavior TBD per Q-X3 (test documents observed behavior)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_connect_for_initial_state.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (boot must complete before helper can deliver values — Ready substate required)
- Unlocks: Story 006 (real `stat_changed` emission in `apply_stat_delta`), Story 008 (Suspended gate subscribes GSM)
