# Story 008: Aggregation + AntiSnowball clamp + #11 push

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 8 + Formula 4 + EC-14/16 + D3/D4/D8
**ADR Governing Implementation**: ADR-0009(primary — modifier payload);ADR-0006(secondary)
**ADR Decision Summary**: push 用單一 synthetic `&"equipment_aggregate"` id;same-id re-apply = atomic replace(**#11 EC-17 已 pin,G-2 RESOLVED** — #11 唔可以加 duplicate-apply assert)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Required: `apply_equipment_modifier` 經 #11 closed API(NEVER `apply_stat_delta` 直接 — #11 Rule 4 caller whitelist:`src/feature/equipment_inventory.gd`,留意 whitelist path 對齊實際檔名,如不同須同步 #11 CI lint)。Forbidden: FR-Equipment-AntiSnowball 違反(`ANTISNOWBALL_MULT = 3.0` LOCKED 非 knob)。

---

## Acceptance Criteria

- [ ] Aggregation 只迭代 3 functional slot(**COSMETIC 結構性排除** — 最後防線)
- [ ] **Formula 4**:`equipment_atk_effective = clamp(raw_atk, 0, min(max(FLOOR=30, 3.0 × SDA), EQUIPMENT_ATK_MOD_MAX=300))`;SDA 經 `StatSystem.get_attack_power_excluding_equipment()`(Story 009)
- [ ] **AC-16**:GIVEN 新號(mock SDA=28)+ 三 slot 裝齊 LEGENDARY,THEN push == 單一 `&"equipment_aggregate"`、`ATTACK_POWER = 84`(=min(90, max(30,84)))、HP/MOVE/CRIT 原值、`equipment.antisnowball.clamp` telemetry emit
- [ ] **AC-17(per-key)**:GIVEN fixture `{ATK 350, HP 600, MOVE 150, CRIT 0.30}` + mock SDA=200,THEN push = `{ATK 300, HP 500, MOVE 100, CRIT 0.20}`(全 key clamp 至 #11 contract 上限)
- [ ] **AC-22**:GIVEN COSMETIC slot 注入帶 stat item + 3 functional 有裝備,THEN push 唔含 cosmetic delta
- [ ] **AC-38**:GIVEN 新號 + L weapon,WHEN `get_aggregate_raw_and_effective()`,THEN `{raw: 90, effective: 84}`(#22 badge contract)
- [ ] Rejection handling:`stat_mutation_rejected`(filter `source == EQUIPMENT`)→ `_pending_stat_push` flag → Ready 後 deferred 一 frame re-push(EC-14;full test Story 015)

---

## Implementation Notes

- Clamp 雙下界 + 雙上界(GDD Formula 4 Pass 1 重寫)— 負值 passthrough 同 range 衝突都封。
- D8 下 raw_atk = Σ ATTACK_POWER deltas(無 STR/DEX 放大分支 — derived-keys-only 令 decomposition 需求結構性消失)。
- Push 永遠係 operation 最後一步(Rule 6 mutation discipline,Story 006/016)。
- #11 mock 經 untyped DI seam(seam 2;typed Node seam compile-time fail — project 已知教訓)。

## Out of Scope

- Story 009:#11 真 API 實作(本 story 用 mock)
- Story 015:rejection retry full path(本 story 只 flag set)
- Story 016:re-entrancy guard

## QA Test Cases

GDD AC-16/17/22/38 GWT。Edge cases:
- 全 slot 空 → push `{}` 或 remove(pin:push empty aggregate = same-id replace with zero deltas)
- SDA = 0(corruption path)→ cap = max(30, 0) = 30(FLOOR bind)
- raw = 0 → effective 0(無 clamp telemetry)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_aggregation_antisnowball.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 006、Story 007
- Unlocks: Story 010(salvage re-push)、Story 013/014/015
