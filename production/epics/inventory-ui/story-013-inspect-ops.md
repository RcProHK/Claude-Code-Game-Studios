# Story 013: ITEM_INSPECT 單件 ops(equip / EQUIPPED「卸下」/ nudge locus / salvage 兩步)

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rule 13 全段(per-lifecycle affordance set)
**Requirement**: direct GDD trace(AC-25)

**ADR Governing Implementation**: ADR-0007(secondary)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `unequip(slot: int)` L674 signature;`equip` 對 EQUIPPED 件係 benign self-swap — 所以「裝備」button 唔 render(唔係靠 error 擋)

**Control Manifest Rules (Presentation)**: NO optimistic UI

---

## Acceptance Criteria

- [ ] **AC-25**:(a)IN_INVENTORY 件 →「裝備」→ `equip(id, slot_affinity)` + **lock nudge inline 喺 sheet 內**(unconditional;[鎖定] one-tap → set_lock + 確認態;sheet 閂咗 nudge 即棄);cosmetic 同款;(b)EQUIPPED 件 →「裝備」**唔 render**,「現役」標記 +「卸下」→ `unequip(slot)` ok + re-read(badge 消失);(c)單件 salvage confirm 成功 → SALVAGE_CONFIRM + ITEM_INSPECT **一齊閂** → NONE + toast
- [ ] Salvage 入口:locked → disabled +「上鎖中」hint(#22 Rule 20 同款);兩步 = #22 P-15 文法

## Implementation Notes

- Affordance set 由 view model lifecycle 欄位 branch — 唔好喺 render 層 call `get_item()` 攞 live state
- Equip/unequip 成功 = silent(event→cue map)— toast + badge 承擔

## Out of Scope

- Story 010:IN_MAILBOX affordances;Story 014:error paths

## QA Test Cases

(= AC GWT;邊界:equip 後即 inspect 同一件[affordance 變 (b)]/ unequip 後 count 不變[L1125 口徑]/ salvage locked 件 disabled)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_commands.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 006
- Unlocks: 014
