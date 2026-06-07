# Story 008: Mailbox section render(F2-M + retention 行 + receipt glyph + grace 誠實 + badge)

> **Epic**: Inventory UI (#23)
> **Status**: Ready
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

- [ ] **AC-15** *(G-IU-1)*:mailbox 混合 fixture → **F2-M sort(acquired asc)** + retention 行(普通件 −1 day)/ receipt 件無 retention 行 + note + glyph;MAILBOX tab「(N)」dim text(0 件唔 render);#23 唔 render evict 預警(negative fold)
- [ ] **AC-14** *(G-IU-1)*:DISCONNECTED + 過期 non-receipt 件(grace)→ row 照列 + **過去日期原文案**(零 urgency styling)+「領取」enabled;claim → ok(rescue);件已被 sweep(fixture erase)→「領取」→ `not_in_mailbox` → toast + re-read
- [ ] MAILBOX section 時 Z3 sub-header 唔 render(UX spec Zones)

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
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 006(+ 004 F2-M)
- Unlocks: 009 / 010
