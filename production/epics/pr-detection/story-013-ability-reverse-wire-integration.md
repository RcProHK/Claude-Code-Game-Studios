# Story 013: #12 reverse-wire integration

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — gate green:combined 1913/1912,0 fail)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 10 reverse-wiring / G-PR-4 ✅ pinned)
**ADR**: ADR-0011;ADR-0008(boot 順序前提)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-21**:真 #12(或 contract spy)— PR confirmed(STR)→ `AbilitySystem._on_pr_breakthrough` 收 `(&"str", m)` **exactly once**(#18-side 止於 handler invocation;#12 內部 Path A 行為 #12 own)
- [ ] Reverse-wire 喺 `_ready`:`pr_breakthrough.connect(AbilitySystem._on_pr_breakthrough)`(G-PR-4 pinned:`ability_system.gd:895`,簽名 `(stat_id: StringName, magnitude: float)`;shipped comment L884-888 明文係 #18 entry point)

## Implementation Notes

- 方向理由(GDD Rule 10):#12 已留 stable entry point — ownership 已定;項目紀律唔依賴未-ready instance。012 必須先完成(否則 double-path)。

## QA Test Cases

GDD AC-21(handler spy exactly-once;真 #12 integration tier)。

## Test Evidence

**Required**:`tests/integration/pr_detection/test_ability_wire.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: **012(BLOCKING — double-path)**, 011
- Unlocks: —
