# Story 008: Mailbox section render(F2-M + retention 行 + receipt glyph + grace 誠實 + badge)

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rule 10 + F1 render guards + EC-08/15 + UX spec MAILBOX wireframe
**Requirement**: direct GDD trace(AC-14 / AC-15)

**ADR Governing Implementation**: ADR-0007(secondary — RarityTier badge)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: injected clock + tz seam(AC-14 過期 fixture)

**Control Manifest Rules (Presentation)**: 零 #17 internal;TTL referenced 唔 duplicate

---

## Acceptance Criteria

- [x] **AC-15** *(G-IU-1)*:mailbox 混合 fixture → **F2-M sort(acquired asc)** + retention 行(普通件 −1 day)/ receipt 件無 retention 行 + note + glyph;MAILBOX tab「(N)」dim text(0 件唔 render);#23 唔 render evict 預警(negative fold)
- [x] **AC-14** *(G-IU-1)*:DISCONNECTED + 過期 non-receipt 件(grace)→ row 照列 + **過去日期原文案**(零 urgency styling)+「領取」enabled;claim → ok(rescue);件已被 sweep(fixture erase)→「領取」→ `not_in_mailbox` → toast + re-read
- [x] MAILBOX section 時 Z3 sub-header 唔 render(UX spec Zones)

## Implementation Notes

- Retention 行 render = F1 三 guard(receipt / acquired<=0 / 過期照印)— formula 層已有信號(story 004),呢度只接 render
- Badge 文法:dim ink 純文字,禁 pill/紅/dot/pulse(AC-32 manual 都會睇)

## Out of Scope

- Story 009:claim flow 本體;Story 010:inspect 限制

## QA Test Cases

(= AC-14/15 GWT;邊界:同秒 tie 序 / 過期+receipt 並存件 / mailbox 0 件)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_mailbox.gd`
**Status**: [x] Created — 7 tests 全 pass;combined gate CLEAN 2309/2308/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 3/3 passing
**Deviations**: (1) `claim_item` dispatch ①②③ 結構連 ② MAKE_ROOM 入口一齊喺本 story 落地(Rule 11 binding 順序唔可分割;EC-05 分支 / pending lifecycle / hint = story 009);(2) **8-fail isolation episode**:新 tests 用真 PersistenceLayer boot #17 → in-memory cache 同 run 交叉污染(隔離 pass / full fail)— 4 file 補「add_child 前注入 MockPersistenceLayer」(suite 慣例),lesson 入 memory
**Test Evidence**: 7 tests — AC-15(F2-M + retention golden + receipt 三件套 + badge + negative fold)/ badge 0 件 / 同秒 tie / sub-header / AC-14(grace verbatim + rescue claim + swept→not_in_mailbox toast)/ 過期+receipt 並存
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 006(+ 004 F2-M)
- Unlocks: 009 / 010
