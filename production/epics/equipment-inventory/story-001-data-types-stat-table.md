# Story 001: Data types + Stat Assignment Table

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md`
**Requirement**: GDD D8/D9 + Rule 12 + § Stat Assignment Table(TR-ID 未註冊 — /architecture-review batch)

**ADR Governing Implementation**: ADR-0006: State Machine Contract(primary — Contract 3); ADR-0009(secondary)
**ADR Decision Summary**: persisted payloads = typed `SerializableResource` dict envelopes(`to_dict()` / `from_dict()` 對稱);`.tres` 寫落 `user://` FORBIDDEN。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `@export` typed Dictionary OK;新 `class_name` 要 `godot --headless --import` 刷 class cache 先 GUT 跑得。

**Control Manifest Rules (Feature layer)**:
- Required: data-driven gameplay values(table = `.tres` resource,res:// 內);doc comments on public APIs
- Forbidden: hardcoded balance values;localStorage
- Guardrail: schema migration ≤900ms(ADR-0003)

---

## Acceptance Criteria

*From GDD, scoped to this story:*

- [ ] `EquipmentItem extends SerializableResource`:fields = item_id(StringName)/ source_transition_id / item_type / rarity / class_tag / stat_modifiers(Dictionary,只准 4 derived key)/ source_receipt(nullable)/ provenance_text / is_cosmetic / lifecycle_state / is_locked / acquired_at_unix / slot_affinity;`to_dict()`/`from_dict()` 對稱 round-trip
- [ ] `SourceReceipt extends SerializableResource`:workout_date_unix / pr_snapshot / volume_snapshot / signature_text;round-trip 對稱
- [ ] Enums:`ItemLifecycle {IN_MAILBOX, IN_INVENTORY, EQUIPPED, SALVAGED}`、`EquipSlot {WEAPON, ARMOR, ACCESSORY, COSMETIC}`、`ReceiveResult {OK, QUEUED_SUSPENDED, DUPLICATE_NOOP, CONVERTED_DUPE, FAILED_ROLLBACK}`(ADR-0007:Outcome enum,ordinal 0 = safe default = OK)
- [ ] `StatAssignmentTable` `.tres` resource(res:// data,唔係 user://):WEAPON ATK [6,12,22,45,90] / ARMOR HP [20,35,60,100,160] / ACCESSORY MOVE [5,8,12,18,25] + CRIT [0,0.01,0.02,0.04,0.06];lookup(item_type, rarity) → stat_modifiers Dictionary
- [ ] Table 每格 ≤ #11 per-key contract range(ATK≤300/HP≤500/MOVE≤100/CRIT≤0.20)— config-load assertion
- [ ] AC-01(schema 部分):valid record hydrate 出嘅 `EquipmentItem` fields 全部正確 typed

---

## Implementation Notes

*From ADR-0006 Contract 3 + GDD Rule 12:*

- Persist 永遠經 dict envelope;`ResourceSaver.save()` 落 `user://` FORBIDDEN(script-embedding 風險)。
- `stat_modifiers` keys 用 StringName 對齊 #11 derived stat 名:`&"ATTACK_POWER"` / `&"MAX_HP"` / `&"MOVE_SPEED"` / `&"CRIT_CHANCE"`。
- Table 係 data-driven `.tres`(assets/data/equipment/);values 對齊 registry `equipment_stat_assignment_table`。
- 檔案:`src/feature/equipment/equipment_item.gd`、`source_receipt.gd`、`equipment_enums.gd`、`stat_assignment_table.gd` + `.tres`。

## Out of Scope

- Story 002:hydration/validation logic(本 story 只係 types + table)
- Story 008:aggregation / clamp
- Story 013:實際 persistence wiring

## QA Test Cases

- **Round-trip**:Given 一個 full-field EquipmentItem(含 receipt),When `from_dict(to_dict())`,Then 全 field 相等(deep equality)。Edge:receipt = null;stat_modifiers = {}。
- **Table lookup**:Given (WEAPON, LEGENDARY),When lookup,Then `{ATTACK_POWER: 90}`;(ACCESSORY, UNCOMMON) → `{MOVE_SPEED: 8, CRIT_CHANCE: 0.01}`;(ARMOR, COMMON) → `{MAX_HP: 20}`。Edge:CONSUMABLE/COSMETIC → `{}`。
- **Range assertion**:Given table 注入 ATK=350 嘅格,When config-load assert,Then fail loud(test 用 push_error spy / assert)。
- **Enum ordinal**:`ReceiveResult.OK == 0`(ADR-0007 Outcome convention)。

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_equipment_types.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(epic 起點)
- Unlocks: Story 002(hydration 用 types + table)、全部後續
