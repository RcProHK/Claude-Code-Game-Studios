# Story 003: Equipment Modifier Layer

> **Epic**: Stat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-06 ✓ AC-07 ✓ AC-08 ✓)
**Deviations**: ADVISORY — AC-07 PL spy structural only (Story 004 completes it); StatModifier.deltas untyped dict (future refactor suggestion)
**Test Evidence**: Integration — `tests/integration/stat_system/test_equipment_not_persisted.gd` (4 tests) + Unit — `tests/unit/stat_system/test_equipment_modifier_allow_list.gd` (8 tests)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (StatModifier.deltas type safety, PL spy deferred)

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-004`
*(TR-stat-004: Source/stat allow-list — EQUIPMENT all-7; modifier layer NOT persisted)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 3 (SerializableResource — modifier NOT persisted), Contract 4 (sequential boot — #17 Equipment replays modifiers after its own `_ready()`)
**ADR Decision Summary**: Equipment modifiers are transient — they affect computed derived stats but are never written to `stat.*` namespace. Stat System boots with empty modifier table; #17 Equipment Inventory replays all equipped items in its own `_ready()`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class StatModifier extends RefCounted` — not a Resource, not serialized. Dictionary operations on `_equipment_modifiers` are O(1). Signal emit after derived recompute fires synchronously before `apply_equipment_modifier` returns.

**Control Manifest Rules (Core layer)**:
- Required: Equipment modifier path is `apply_equipment_modifier(equipment_id, StatModifier)` — NEVER call `apply_stat_delta` for equipment changes (Rule 4 caller whitelist)
- Required: `_equipment_modifiers` table is empty at boot — #17 must replay modifiers in its own `_ready()` after Stat System boots
- Forbidden: Never persist `_equipment_modifiers` to `stat.*` namespace

---

## Acceptance Criteria

- [ ] **AC-06** — GIVEN Stat System Ready, WHEN `apply_equipment_modifier("eq_test", StatModifier.new({StatId.MAX_HP: 50, StatId.CRIT_CHANCE: 0.05}))` is called (via #17 Equipment path), THEN modifier is accepted, derived stats recompute, `stat_changed(MAX_HP, old, new, EQUIPMENT, false)` fires AND `stat_changed(CRIT_CHANCE, old, new, EQUIPMENT, false)` fires (one signal per affected derived stat).
  *(Note: AC-06 is unit-level — tests in-memory recompute + signal emit. Verify with `tests/unit/stat_system/test_equipment_modifier_allow_list.gd`)*
- [ ] **AC-07** — GIVEN Apply equipment modifier that would push `StatId.STR` to 20 (+10 modifier over base 10), WHEN Stat System `_ready()` runs again (simulating reload), THEN `_base[STR]` is still 10.0 (persisted value), `_equipment_modifiers` is an empty Dictionary, AND PersistenceLayer spy confirms it never received a `write("stat.str", 20, ...)` call.
  *(Note: AC-07 is integration-level — requires PersistenceLayer spy. Verify with `tests/integration/stat_system/test_equipment_not_persisted.gd`)*
- [ ] **AC-08** — GIVEN `apply_equipment_modifier("ring_01", ModifierA{MAX_HP: +30})` called first, WHEN `apply_equipment_modifier("ring_01", ModifierB{MAX_HP: +50})` called with same equipment_id, THEN `_equipment_modifiers` contains exactly ONE entry for `"ring_01"` (ModifierB overwrites ModifierA — idempotent), `stat_changed(MAX_HP, ...)` fires only once total (for the net new value, not twice), AND removing `"ring_01"` afterwards returns MAX_HP to its pre-modifier baseline.
  *(Note: AC-08 is unit-level — idempotent overwrite + clean removal. Verify with `tests/unit/stat_system/test_equipment_modifier_allow_list.gd`)*

---

## Implementation Notes

*From GDD Rule 5:*

1. **`class StatModifier extends RefCounted`** — `var deltas: Dictionary` where keys are `StatId` StringNames and values are float deltas.
2. **`_equipment_modifiers: Dictionary[StringName, StatModifier]`** — keyed by `equipment_id`. Private field — CI lint AC-02 guards against external access.
3. **`apply_equipment_modifier(equipment_id: StringName, modifier: StatModifier) -> void`**:
   - `_equipment_modifiers[equipment_id] = modifier` (idempotent — same ID overwrites)
   - For each derived stat affected by `modifier.deltas`: recompute + emit `stat_changed(..., EQUIPMENT, false)`
4. **`remove_equipment_modifier(equipment_id: StringName) -> void`**:
   - If `equipment_id` not in `_equipment_modifiers` → no-op, no emit, return void (silent OK per EC-18)
   - Otherwise: remove + recompute affected derived stats + emit `stat_changed`
5. **NOT persisted**: `apply_equipment_modifier` must NOT call `PersistenceLayer.write()`. Only `apply_stat_delta` for base stats triggers persistence (Rule 13 step 4).
6. **Derived stat compute**: Each derived stat formula (F3-F6) reads from `_base` + sums `_equipment_modifiers` for its relevant mod key. Recompute is triggered after any modifier add/remove.
7. **Boot**: `_equipment_modifiers` initialized as empty `{}` in `_ready()`. #17 Equipment Inventory calls `apply_equipment_modifier` for each equipped item in its own `_ready()` (per Contract 4 sequential boot ordering).
8. **Performance**: `apply_equipment_modifier` is event-driven (called on equip/unequip, not per-frame). Dictionary ops + signal emit are O(1) per affected stat. No frame-rate concern; formal profiling deferred to Story 009 derived formula budget.

---

## Out of Scope

- Story 005: `connect_for_initial_state` delivery of modifier-affected derived stats (observer pattern)
- Story 006: Persistence write path for `_base` (equipment modifiers are explicitly NOT persisted)
- Story 009: Derived stat formulas F3-F6 (implementation; this story only covers modifier acceptance + signal emit)

---

## QA Test Cases

**Story Type**: Integration (AC-06 = unit evidence; AC-07 = integration evidence)

- **AC-06**: Modifier apply + signal emit (unit path)
  - Given: STR=DEX=VIT=10, no existing modifiers
  - When: `apply_equipment_modifier("ring_01", StatModifier{MAX_HP:+50, CRIT_CHANCE:+0.05})`
  - Then: `stat_changed(MAX_HP, 160, 210, EQUIPMENT, false)` fires; `stat_changed(CRIT_CHANCE, 0.015, 0.065, EQUIPMENT, false)` fires; no `stat_changed` for unaffected stats (STR/ATTACK_POWER)
  - Edge cases: Same `equipment_id` applied twice (second overwrites first — idempotent); modifier with unknown stat_id key (`"luk"`) — silently ignored (no push_error per EC-19)

- **AC-07**: Modifier NOT persisted (integration path)
  - Given: Apply `StatModifier{STR:+10}` → in-memory base effective value appears 20; then simulate `_ready()` re-run with PersistenceLayer spy
  - When: `_ready()` reads `PersistenceLayer.read("stat.str")` → returns 10.0 (persisted value unchanged)
  - Then: `_base[STR] == 10.0`; `_equipment_modifiers` is empty `{}`; PersistenceLayer spy confirms zero `write("stat.str", ...)` calls from modifier path
  - Edge cases: Remove modifier for unknown equipment_id → no-op, no emit (EC-18); apply modifier during Reconciling substate → rejected (EC-21)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Unit: `tests/unit/stat_system/test_equipment_modifier_allow_list.gd` (AC-06)
- Integration: `tests/integration/stat_system/test_equipment_not_persisted.gd` (AC-07)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (StatSource enum + EQUIPMENT source allow-list must be defined)
- Unlocks: Story 009 (derived formula tests use modifier to validate `equipment_*_mod` inputs)
