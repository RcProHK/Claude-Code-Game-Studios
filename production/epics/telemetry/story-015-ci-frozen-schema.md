# Story 015: G-TEL-4 CI-3 check_telemetry_frozen_schema.gd (frozen loot_dropped_v1)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Complete
> **Layer**: Polish
> **Type**: Static-CI
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 14(frozen schema + version-on-change)+ AC-11 + CI-3 + EC-16。**#15 FR-LOOT-3 binding,must-not-regress**。
**ADR Governing Implementation**: ADR-N/A — CI tooling,no architectural pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `tools/ci/*.gd` headless lint。

**Control Manifest Rules (Polish layer)**:
- Required: frozen field set 比對 per event_name
- Forbidden: 改 `loot_dropped` 欄位無 version bump
- Guardrail: schema change → 新 version(`_v2`),永不 in-place

---

## Acceptance Criteria

- [x] `tools/ci/check_telemetry_frozen_schema.gd` 建立(paren-balancing parser:抽 payload keys + schema_version int)
- [x] frozen registry:`loot_dropped_v1` field set = `{drop_id, rarity_tier, item_type, transition_id}`(#15 FR-LOOT-3,grep-verified vs shipped telemetry.gd:423)
- [x] grep telemetry `loot_dropped` 序列化點:增/刪欄位而 `schema_version` 無 bump → exit 非 0(probe 驗:5th-field@v1 → drift FAIL exit 1,EC-16)
- [x] 多 event_name 可擴(`FROZEN_SCHEMA` const Dictionary,event→version→field-set,data-driven)
- [x] 加入 lint sweep(workflow glob 自動)

---

## Implementation Notes

*Derived from GDD Rule 14 + AC-11 + EC-16:*

- lint 維持一個 frozen schema 表(event_name → version → field set)。`loot_dropped_v1` = 4 欄。
- 檢查 telemetry serialize `loot_dropped` 嘅 field set 同 frozen 表一致;唔一致且 version 無 bump → fail。
- runtime 上 telemetry 永遠只寫 frozen field set(EC-16:多出欄位唔序列化)—— lint 係 build-time backstop。
- #15 已 ship `loot_dropped(drop_id, rarity_tier, item_type, transition_id)`,grep-verified EXACT。

---

## Out of Scope

- Story 010:loot subscription 本體(此 lint 守佢嘅 serialize)
- Story 013/014:其他兩 lint

---

## QA Test Cases

- **AC-1 (frozen schema, AC-11)**:
  - Given: telemetry `loot_dropped` serialize = 4 欄
  - When: lint run
  - Then: exit 0
  - Edge cases: 加第 5 欄無 bump version → exit 非 0(EC-16);bump 做 `loot_dropped_v2` → 接受(version 表加新 entry)
- **AC-2 (data-driven 多 event)**:
  - Given: frozen 表加另一 event_name
  - When: lint run
  - Then: 該 event 同樣受 frozen 比對

---

## Test Evidence

**Story Type**: Static-CI
**Required evidence**: lint self-test + `tests/static/` 收口
**Status**: [x] `tests/static/test_telemetry_ci_lint.gd`(loot_dropped_v1 4-field assert + drift fixture)+ `telemetry_frozen_schema_violation.gd`;CLI probe exit 1 verified

---

## Dependencies

- Depends on: Story 010(loot serialize 存在)
- Unlocks: None(must-not-regress guard)
