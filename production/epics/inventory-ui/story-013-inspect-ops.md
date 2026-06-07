# Story 013: ITEM_INSPECT 單件 ops(equip / EQUIPPED「卸下」/ nudge locus / salvage 兩步)

> **Epic**: Inventory UI (#23)
> **Status**: Complete
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

- [x] **AC-25**:(a)IN_INVENTORY 件 →「裝備」→ `equip(id, slot_affinity)` + **lock nudge inline 喺 sheet 內**(unconditional;[鎖定] one-tap → set_lock + 確認態;sheet 閂咗 nudge 即棄);cosmetic 同款(slot_affinity 1:1 — 同 code path);(b)EQUIPPED 件 →「裝備」**唔 render**,「現役」標記 +「卸下」→ `unequip(slot)` ok + re-read(badge 消失);(c)單件 salvage confirm 成功 → SALVAGE_CONFIRM + ITEM_INSPECT **一齊閂** → NONE + toast
- [x] Salvage 入口:locked → disabled +「上鎖中」hint(#22 Rule 20 同款);兩步 = #22 P-15 文法(view:yield + provenance + signature + equipped warning + default focus cancel)

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
**Status**: [x] Created — 7 tests 一 take 全 pass;combined gate CLEAN 2346/2345/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 2/2 passing
**Deviations**: (1) nudge lifetime = sheet-local(閂咗即棄 — GDD 冇 pin duration,#23 nudge 唔跟 list 所以唔需要 timer);(2) **story-009 AC-16 deferred positive-control leg 喺度收回**(manual equip → nudge 出現 assert);(3) unequip 成功 = 零 toast 零 SFX + ARIA announce(cue map silent + UI Req announce set)
**Test Evidence**: 7 tests — (a) equip + nudge 三段(出現/one-tap 確認態/閂棄)/ locked equip 無 nudge / (b) affordances + unequip + count 不變 / equip 後即 inspect → (b) / (c) 兩層閂 + P-15 view / locked disabled + double guard / equipped warning
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 006
- Unlocks: 014
