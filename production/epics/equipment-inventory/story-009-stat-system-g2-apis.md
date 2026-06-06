# Story 009: #11 G-2 additive APIs(cross-epic)

> **Epic**: Equipment & Inventory (#17)
> **Status**: Implemented (pending CI verification)
> **Layer**: Core(cross-epic touch — 改 #11 Stat System)
> **Type**: Logic
> **Estimate**: S (~1.5h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/stat-system.md`(G-2 amendments 2026-06-06,spec 已落地)— L228 `is_boot_completed()` + L267 `get_attack_power_excluding_equipment()`
**ADR Governing Implementation**: ADR-0006(primary — Contract 4 rationale)
**ADR Decision Summary**: 後 boot 嘅 autoload 用 sync getter assert,**唔 await `boot_completed` signal**(Contract 4 下 signal 已 fire = permanent hang)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Required: #11 closed API 紀律 — 新 API 係 read-only,唔開 mutation 面。Cross-epic 先例:additive cross-system stories(#4 EG / #10 Q5 patch)。

---

## Acceptance Criteria

- [ ] `StatSystem.is_boot_completed() -> bool`:`_ready()` 完成後 true;sync getter,side-effect-free
- [ ] `StatSystem.get_attack_power_excluding_equipment() -> float`:回傳 `ATK_BASE + STR×ATK_PER_STR + DEX×ATK_PER_DEX`,**內部用 `_base` dict,唔經 modifier table**;O(1) side-effect-free
- [ ] 新號 default(10/10/10 @ default knobs)→ **28.0**(golden,= #17 全 doc baseline)
- [ ] Equipment modifier 在場時(modifier table 有 `equipment_aggregate`)→ 回傳值**不變**(excluding 語意驗證)
- [ ] 現有 stat_system tests 全 green(no regression)

---

## Implementation Notes

- 檔案:`src/autoload/stat_system.gd`(#11 owned;本 story 係 #17 epic 嘅 cross-epic touch,spec 已喺 #11 GDD G-2 amendment)。
- **唔好**喺 #17 inline 重抄 formula(single source of truth — drift 溫床)。
- Knob 值經 #11 現有 config 讀(ATK_BASE=10 / ATK_PER_STR=1.5 / ATK_PER_DEX=0.3)。

## Out of Scope

- #17 嘅 clamp 邏輯(Story 008 — consumer)

## QA Test Cases

- **Golden**:Given default base stats,When call,Then 28.0(±epsilon)。
- **Excluding**:Given `apply_equipment_modifier(&"equipment_aggregate", {ATTACK_POWER: 50, ...})` applied,When call,Then 仍然 28.0。
- **Boot getter**:Given StatSystem `_ready()` 完成,Then `is_boot_completed() == true`;test double 模擬 boot 前 → false。
- Edge:STR=999/DEX=999 → 1808.2(contract range 上界)。

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_g2_additive_apis.gd`(放 #11 test dir — owner-aligned)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可以最早做 — Story 008 嘅真依賴)
- Unlocks: Story 008(SDA source)、Story 014(boot assert)
