# Story 014: Error model(6+1 codes + toast map + dispatch)+ DISCONNECTED suite

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rule 14 全段 + Rule 11 dispatch + EC-13
**Requirement**: direct GDD trace(AC-26 / AC-27)

**ADR Governing Implementation**: ADR-0006(secondary)+ ADR-0003(DISCONNECTED = local 全功能)
**ADR Decision Summary**: unsynced-only client wins — offline 全 command 照行。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: deferred 誘發 = `_mutating=true` 注入(header seam — 唔算 stub);#22 toast map fork 後**必須加 `not_in_mailbox` entry**(唔加 = raw code leak)

**Control Manifest Rules (Presentation)**: toast = ARIA live region(silent-fail 禁令)

---

## Acceptance Criteria

- [x] **AC-26**:6 codes(not_found / in_mailbox_claim_first / slot_type_mismatch / slot_empty / locked / **not_in_mailbox**)真 #17 誘發 → toast + re-read(not_in_mailbox 專屬文案「件物品已唔喺信箱(可能已自動分解)」);deferred_reentrancy → 唔 toast 下 frame 收割;claim `{ok:false, shortfall:1}`(無 error key)→ MAKE_ROOM 路徑**唔行** toast 路徑(dispatch ①②③)
- [x] **AC-27**:DISCONNECTED + OPEN → claim/bulk/equip/**unequip**/lock/salvage 逐個同 IDLE 一致;唯一 delta = banner

## Implementation Notes

- 真誘發 recipe:equip(L657/659/661)/ unequip(L677 slot_empty)/ salvage(L554/556)/ claim(L712);deferred = `_mutating` 注入後任一 command
- 同屏最多 1 條 toast(新取代舊 — #22 同款)

## Out of Scope

- Story 015:ARIA announce 內容驗收(toast 文字 announce 喺度接)

## QA Test Cases

(= AC GWT;邊界:連續兩 error[toast 取代]/ deferred 之後 re-read 收割 state 正確)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_commands.gd`
**Status**: [x] Created — +5 tests(suite 12)全 pass;combined gate CLEAN 2351/2350/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 2/2 passing
**Deviations**: (1) `equip_item` 加 optional `slot_override` param(#22 equip(id, slot) signature parity — slot_type_mismatch 真誘發需要 explicit slot);(2) claim ③ not_in_mailbox 統一行 `_handle_command_error` map(pending-clear 保留喺 claim);(3) **「下 frame 收割」timing 真相**:#17 replay 係 process_frame one-shot(frame N+1),coordinator call_deferred re-read 行先(frame N 尾)— 收割實際由**下一個 re-read trigger** 完成(EC-16 design-accept class;#22 同款 gap;test 斷言改為誠實版)
**Test Evidence**: +5 tests — 6 codes 真誘發逐個(locked 用 confirm 期間外部 lock 真路徑)/ deferred 無 toast + 下個 re-read 收割 / shortfall 行 ② 唔行 toast / toast 取代 / AC-27 六 command offline suite
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 013 + 009
- Unlocks: 015
