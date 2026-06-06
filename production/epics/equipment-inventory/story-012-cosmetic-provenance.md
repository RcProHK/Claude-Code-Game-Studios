# Story 012: Cosmetic pipeline + dupe auto-convert + provenance

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2.5h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 10/11 + EC-5
**ADR Governing Implementation**: ADR-0009(primary — telemetry payload);ADR-0006 C3(secondary)
**ADR Decision Summary**: cosmetic 永不餵戰鬥(scrub + 結構排除雙防線);dupe convert = 單一 salvage 價值軌(#15 EC-38 G-3 已回填)。

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **AC-05**:GIVEN persisted cosmetic item dict(boot path)帶非空 `stat_modifiers`,WHEN boot re-hydrate,THEN `stat_modifiers == {}` + emit `inventory.stat_key.dropped`,item 照 load
- [ ] **AC-37**:GIVEN inventory 已 own cosmetic visual id X,WHEN `receive_loot()` 收同 visual id cosmetic(RARE),THEN 唔入庫、`forge_shard` += 250、return `CONVERTED_DUPE`、emit `inventory.cosmetic.dupe_converted`、tombstone 登記 `{item_id: now_unix}`
- [ ] Cosmetic:`class_tag = NEUTRAL` 強制;COSMETIC slot manual-only(Story 006 assert)
- [ ] **Provenance(全 tier)**:`provenance_text` 由 `acquired_at_unix` + `class_tag` derive(「拾於 6月3日・腿日」);**UTC 日期**(deterministic);NEUTRAL → 「自由日」
- [ ] LEGENDARY receipt `signature_text` 原樣保留(F-12;#29 ceremony payload)

---

## Implementation Notes

- Dupe detection:visual id 比較(item_metadata 帶 visual id;#17 own unlock/inventory state — #15 唔使 query)。
- Provenance derive 喺 hydration 一次過(cache 入 field;boot 120 件 <1ms)。
- Class_tag → day label mapping:STRIKE→推日 / CONTROL→拉日 / MOBILITY→腿日 / NEUTRAL→自由日(data-driven dict)。

## Out of Scope

- #26 visual rendering(consumer)
- #22/#23 display(timezone 係 presentation 層)

## QA Test Cases

GDD AC-05/AC-37 GWT。Edge cases:
- 第一件 cosmetic(未 own)→ 正常入庫,唔 convert
- dupe convert 嘅 replay(同 item_id)→ tombstone dedup no-op,shard 唔重複派
- provenance UTC:acquired_at 跨 UTC 午夜 boundary → 日期跟 UTC 唔跟 local

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_cosmetic_provenance.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002、Story 003(tombstone)
- Unlocks: None(leaf)
