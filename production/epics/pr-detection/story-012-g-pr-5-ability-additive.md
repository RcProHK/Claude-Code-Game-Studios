# Story 012: G-PR-5 — #12 additive 四件套(cross-epic)

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature(cross-epic touch — #12 Core)
> **Type**: Logic
> **Estimate**: S-M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(G-PR-5 gate row — scope 四件)
**ADR**: ADR-0006;Approved-upstream additive amendment(EG-1 先例)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] (a) `ability_system.gd` `_on_stat_changed` 加一行:skip `source == 0`(PR_BREAKTHROUGH)— 否則 double-path(STAT_THRESHOLD provenance 搶先 + deferred flush 100ms crash window)
- [ ] (b) **Shipped test 反轉**:`tests/unit/ability_system/test_unlock_path_b_multi_tier.gd:98-99`(現 assert PR-source 經 Path B unlock)→ 改 assert **零** Path B unlock for source==0(唔反轉 CI 即紅)
- [ ] (c) `is_boot_completed()` getter(mirror #11 G-2 先例 — AC-30 嘅 #12-half assert surface)
- [ ] (d) L890 comment 修:magnitude = relative ratio(0-2.0),唔係 PR delta
- [ ] Combined gate green(ability_system suite 其餘零變化)

## Implementation Notes

- `StatSource.PR_BREAKTHROUGH` ordinal 0(`stat_system.gd:50-51`)。改動係 additive + 行為修正(PR path 專屬 `_on_pr_breakthrough`)— #12 GDD 唔使 rewrite,story 完成後喺 #12 GDD 加一行 amendment note。

## Out of Scope

- 接線本身(013)。

## QA Test Cases

(b) 反轉 test + 新 unit:emit source==0 stat_changed → 零 `_evaluate_unlock_tiers` via Path B(spy);source==1(VOLUME)路徑不受影響。

## Test Evidence

**Required**:`tests/unit/ability_system/test_unlock_path_b_multi_tier.gd`(反轉後 pass)+ 新 assert。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可早做 — **必須先於 013**)
- Unlocks: 013
