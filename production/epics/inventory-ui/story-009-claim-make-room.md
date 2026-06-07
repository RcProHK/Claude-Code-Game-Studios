# Story 009: Claim flow(dispatch ①②③)+ MAKE_ROOM D4(雙入口 + transient + inline hint)

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rule 11 全段(D4)+ EC-04/05/16 + States(MAKE_ROOM row + pending 軸)
**Requirement**: direct GDD trace(AC-16 / AC-17)

**ADR Governing Implementation**: ADR-0006(secondary — re-read)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: claim return 處理係 Dictionary key 檢查 — **dispatch 順序 binding**(① ok ② shortfall>0[無 error key — L715] ③ error)

**Control Manifest Rules (Presentation)**: 零 optimistic UI(synchronous return + re-read)

---

## Acceptance Criteria

- [ ] **AC-16**:claim ok → auto-equip 判定 predicate(`get_item(id).lifecycle_state == EQUIPPED`)→「已領取並裝上」/「已領取」分支 + re-read;零 lock nudge(positive control:**同 file** 重做 AC-25 同款 manual-equip-nudge assert)
- [ ] **AC-17**:inventory full + claim → MAKE_ROOM(「要騰 1 個位」+ 雙入口[批量分解→BULK_SELECT / 自行整理→NONE+INVENTORY])+ `make_room_pending` set;零自動分解(state-based:#17 shards+count 全程不變);騰位後(count<120)→ inline hint「已騰出空位 — 領取『[name]』」one-tap ok + pending 清空;dismiss → pending 清空 + claim 可重試
- [ ] EC-16:deferred claim replay return 丟棄 — 設計接受(test:`_mutating=true` 注入 → deferred → re-read 後件仍 IN_MAILBOX → re-tap recovery)

## Implementation Notes

- `make_room_pending` 清空六條件(open reset / close / force-close / claim 成功 / not_in_mailbox / dismiss)— States 表
- Hint strip = P-14 文法 static render(L0;唔 slide 唔 pulse);dismiss X
- 入口 (a) 開 BULK_SELECT 時 pending 保留(BULK_CONFIRM claim-target warning 喺 011 接)

## Out of Scope

- Story 011:BULK_CONFIRM warning render;Story 014:not_in_mailbox toast 文案(error map)

## QA Test Cases

(= AC GWT;邊界:騰位後 count 啱啱 == 119 / pending 件被 bulk 食咗[hint 唔出 — re-read 後件唔存在 → pending 清?GDD 冇明文 — implementer note:hint render 前 verify `get_item(pending)` 仍 IN_MAILBOX,唔係就清 pending,silent]/ MAKE_ROOM dismiss 後再 claim 同件)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_mailbox.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 008
- Unlocks: 011(claim-target warning context)
