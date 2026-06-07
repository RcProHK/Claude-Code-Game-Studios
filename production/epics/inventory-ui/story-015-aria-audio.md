# Story 015: ARIA announce set + event→cue map 驗收(mapping-level)

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — UI Requirements ARIA 加項 + Visual/Audio event→cue map(binding)
**Requirement**: direct GDD trace(AC-28 / AC-29)

**ADR Governing Implementation**: N/A — seams shipped(`platform_detect.announce_aria` + #4 `play_sfx`)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: spy #4 play_sfx calls(#22 AC-42 同款 idiom);positive-control 同 spy instance

**Control Manifest Rules (Presentation)**: 零新 cue(map 係 closed set)

---

## Acceptance Criteria

- [ ] **AC-28**:bulk / claim / equip / unequip / 單件 salvage / error toast / section 切換(+ list summary「收藏 N 件」)全 announce(coalesced);disabled 入口 focus → announce 原因;positive control 先行
- [ ] **AC-29**:完整 walkthrough(GDD op 名單 17 ops)→ **逐 event assert = map 指派 cue**(mapping 唔係 set-membership);silent events 零 call;`ui_back` 零 call;positive control 先行
- [ ] Focus-driven virtualization 接線(005 hook → focus 行到視窗邊推進)

## Implementation Notes

- Equip/unequip/claim 成功 = 明文 silent(map);salvage execute 一響 count-invariant;modal 開關全 `ui_sheet_*`
- Link path 雙 cue(#22 close + #23 open)= 016 verify(AC-09)— 本 story map 內列明唔重 assert

## Out of Scope

- Story 016:AC-09 link path;manual SR walkthrough = AC-31(protocol @ 018)

## QA Test Cases

(= AC GWT;邊界:coalesce 窗內連續 section 切換[最後一條為準]/ deferred error 零 toast 零 announce 零 cue)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_aria.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 009-014(flows 齊先有 walkthrough)
- Unlocks: —
