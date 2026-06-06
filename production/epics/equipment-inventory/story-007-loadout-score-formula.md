# Story 007: Formula 1 — loadout_score(clamp-aware 比較鍵)

> **Epic**: Equipment & Inventory (#17)
> **Status**: Implemented (pending CI verification)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Formula 1 + STAT_WEIGHT knobs
**ADR Governing Implementation**: N/A — pure formula,no architectural pattern required(data-driven knobs per coding standards)
**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `loadout_score(effective_aggregate) = Σ STAT_WEIGHT[key] × delta`,weights = `{ATTACK_POWER: 1.0, MAX_HP: 0.25, MOVE_SPEED: 0.6, CRIT_CHANCE: 400}`(data-driven config,per-key safe range)
- [ ] **AC-18(golden vector)**:GIVEN 3×LEGENDARY 新號(cap=84):effective = {ATK 84, HP 160, MOVE 25, CRIT 0.06},THEN score = 84 + 40 + 15 + 24 = **163**
- [ ] **AC-19(clamp-aware)**:GIVEN ATK 已 at cap(SDA=28,WEAPON L equipped,effective 84)+ ARMOR slot RARE(+60 HP),WHEN 假想 ATK-heavy fixture 競爭 ARMOR slot,THEN loadout-marginal 比較唔 swap(swap 後 score 跌)
- [ ] Empty-slot 貢獻 = 0;output range [0, ~170] @ MVP table

---

## Implementation Notes

- Pure static function(`src/feature/equipment/loadout_score_calc.gd`,#13 CombatResolver static-pure 先例)— 無 state、無 singleton、unit-testable。
- 接收 post-clamp effective aggregate(clamp 由 Story 008 提供;本 story test 直接注 effective dict)。
- Weights 入 config resource(同 Stat Assignment Table 同一 .tres 或獨立)。

## Out of Scope

- Story 006:orchestration(邊個時候比較)
- Story 008:effective aggregate 點計

## QA Test Cases

GDD AC-18/AC-19 GWT。Edge cases:
- 空 aggregate `{}` → 0
- 單 key {CRIT: 0.06} → 24(scale normalization 驗證)
- weights 注入 0 → 該 key 唔貢獻(knob 行為)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_loadout_score_formula.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 001(types)
- Unlocks: Story 006
