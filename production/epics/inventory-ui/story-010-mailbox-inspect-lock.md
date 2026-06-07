# Story 010: Mailbox inspect 限制 + lock D1(honest copy)+ salvage 零-dispatch invariant

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rule 12 全段(D1 + 零-dispatch invariant + rescue window)+ EC-06
**Requirement**: direct GDD trace(AC-18 / AC-34)

**ADR Governing Implementation**: N/A — UI affordance gating + #17 public API consume
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: **ground truth(grep-verified)**:`set_lock` L692-698 冇 lifecycle check(IN_MAILBOX 有效);`salvage` L548-556 **冇 IN_MAILBOX guard — dispatch 咗 = 件已毀**;`in_mailbox_claim_first` 只喺 equip path L658-659

**Control Manifest Rules (Presentation)**: 防線唔靠 #17(salvage 零 code guard)— disabled 入口 + 零-dispatch invariant 係 #23 binding

---

## Acceptance Criteria

- [x] **AC-18**:mailbox 件 inspect → equip/salvage disabled +「先領取」hint + **lock toggle enabled**;stale race per-command:equip(仍 IN_MAILBOX)→ `in_mailbox_claim_first`;equip/salvage(已消失)→ `not_found`;claim(已消失)→ `not_in_mailbox` — 有 code 嘅 toast + re-read;**salvage 零 dispatch invariant**(negative;positive control = 同 file IN_INVENTORY 件 salvage dispatch 存在)
- [x] **AC-34**:mailbox unlocked receipt 件 lock on → ok + lock 標記 + receipt glyph 並存 + honest copy「鎖定 — 批量分解唔會掂佢;保留期照計」;`bulk_salvage(該 rarity)` → 件存活;locked **non-receipt** mailbox 件 retention 行**照 render**(lock 唔擋 sweep — 日期仍係事實)

## Implementation Notes

- Disabled affordance 帶 hint 文字(SR focus announce 接線喺 015)
- Honest copy 係 pinned 文案 — 唔好「改善」成「完全保護」(D1 裁決:lock 擋 bulk 唔擋 sweep,照直講)

## Out of Scope

- Story 013:IN_INVENTORY/EQUIPPED inspect affordances;Story 015:SR announce

## QA Test Cases

(= AC GWT;邊界:locked receipt 件[全保護 — sweep 免 receipt + bulk 免 lock]/ lock off 再 bulk[件被食])

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_mailbox.gd`
**Status**: [x] Created — +6 tests(suite 20)全 pass;combined gate CLEAN 2322/2321/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 2/2 passing
**Deviations**: (1) `confirm_salvage` 加 dispatch 前 IN_MAILBOX re-check(defence-in-depth — 「唯一防線」指 #17-side 冇 guard,唔限 #23 內部層數;invariant 最強讀法);(2) inspect 機制(open_inspect / get_inspect_view / equip_item / request+confirm_salvage / toggle_lock / _handle_command_error)本 story 落 mailbox 面 + 基本 dispatch — story 013 收 inventory/equipped affordances + nudge + 兩層閂;error map 014 收全
**Test Evidence**: +6 tests — affordance gating / 零-dispatch(SpyInventory subclass call-level)+ positive control / stale race ×2 / lock receipt 全保護 + bulk 存活 / locked non-receipt retention / lock-off 對照
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 008
- Unlocks: —
