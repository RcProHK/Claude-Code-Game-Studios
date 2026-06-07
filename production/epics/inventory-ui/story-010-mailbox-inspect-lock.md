# Story 010: Mailbox inspect 限制 + lock D1(honest copy)+ salvage 零-dispatch invariant

> **Epic**: Inventory UI (#23)
> **Status**: Ready
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

- [ ] **AC-18**:mailbox 件 inspect → equip/salvage disabled +「先領取」hint + **lock toggle enabled**;stale race per-command:equip(仍 IN_MAILBOX)→ `in_mailbox_claim_first`;equip/salvage(已消失)→ `not_found`;claim(已消失)→ `not_in_mailbox` — 有 code 嘅 toast + re-read;**salvage 零 dispatch invariant**(negative;positive control = 同 file IN_INVENTORY 件 salvage dispatch 存在)
- [ ] **AC-34**:mailbox unlocked receipt 件 lock on → ok + lock 標記 + receipt glyph 並存 + honest copy「鎖定 — 批量分解唔會掂佢;保留期照計」;`bulk_salvage(該 rarity)` → 件存活;locked **non-receipt** mailbox 件 retention 行**照 render**(lock 唔擋 sweep — 日期仍係事實)

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
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 008
- Unlocks: —
