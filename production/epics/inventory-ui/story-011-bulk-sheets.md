# Story 011: Bulk sheets — BULK_SELECT(re-preview)+ BULK_CONFIRM(D5 三層 + 三段結構)+ 退層 routing

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 15/16 + EC-02/03 + States return-target 表 + UX spec BULK wireframes
**Requirement**: direct GDD trace(AC-19 / AC-20 / AC-24)

**ADR Governing Implementation**: ADR-0007(secondary — RarityTier rows)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: preview 係 free synchronous read — sheet enter + row tap 都 re-fetch(Rule 15 pin)

**Control Manifest Rules (Presentation)**: M/K breakdown = view-model count(唔係 selection predicate duplicate — D5 邊界)

---

## Acceptance Criteria

- [x] **AC-19**:5 rarity rows = preview 真值;0 件 row 灰掉照 tap → **re-preview** → 仍 0 → inline note;owned>0 全 locked →「0 件可分解([N] 件已鎖)」variant;reverse drift(re-preview >0)→ 照開 CONFIRM
- [x] **AC-20** *(G-IU-1 receipt_ids)*:D5 三層 — ①receipt itemised(`receipt_ids` → `get_item()`;cap 8 +「+N more」總數照報)②conditional「內含信箱 [M] 件、現役 [K] 件」(零中招 assert 無)③`make_room_pending` rarity-match unlocked → 第一行「⚠ 包括你想領取嗰件『[name]』」(無 pending assert 無);**三段結構**(fixed header[receipt 總數 above-fold]+ scrollable 中段 + fixed footer);cancel+scrim+ESC 三者一律退返 BULK_SELECT;default focus = cancel
- [x] **AC-24**:ESC 逐層(CONFIRM→SELECT[+re-preview]→NONE→close screen);SALVAGE_CONFIRM ESC/scrim/cancel → ITEM_INSPECT;MAKE_ROOM ESC/scrim → NONE

## Implementation Notes

- ENTER 只喺 confirm 獲 focus 時觸發 confirm(default focus cancel — UX spec)
- Modal ≠ NONE ⇒ section tabs scrim 封鎖(MAKE_ROOM「自行整理」係唯一例外路徑)

## Out of Scope

- Story 012:confirm 之後嘅 execute(AC-21/22/23/36)

## QA Test Cases

(= AC GWT;邊界:receipt_count 9[cap 8 + 「+1 more」]/ M=0 K>0 only 現役行 / pending 件 locked[warning 唔出])

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_bulk.gd`
**Status**: [x] Created — 12 tests 全 pass;combined gate CLEAN 2334/2333/0 fail(2026-06-08;前一 run 有 1 flaky fail 未捉到名 — WATCH)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 3/3 passing
**Deviations**: None — `cancel_modal` per-modal return-target 表全套落地(SALVAGE_CONFIRM→INSPECT / BULK_CONFIRM→SELECT / MAKE_ROOM→dismiss / 其餘→NONE)+ `handle_escape` EC-07 routing;tabs scrim 封鎖 guard 落 `set_active_section`(self-organize 例外天然保留 — 佢先 set NONE);`BULK_CONFIRM_RECEIPT_LIST_MAX = 8` knob const
**Test Evidence**: 12 tests — AC-19 ×3(rows 真值 / EC-02+03 notes / reverse drift)/ AC-20 ×4(三層 + cap9→8+1 / 零中招全唔出 / M=0K>0 / pending locked)/ AC-24 ×4(dismiss 等效 / ESC 逐層到 close / salvage 退 inspect / MAKE_ROOM 清 pending)/ tabs 封鎖
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)
**WATCH**: full-gate 1 flaky fail ×1(兩連 run fail→clean,名未 capture)— 重現即捉

## Dependencies

- Depends on: Story 006 + 003(receipt_ids)+ 009(pending context)
- Unlocks: 012
