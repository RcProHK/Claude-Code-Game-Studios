# Story 012: Bulk execute + preview-execute drift + EC-12 兩邊

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 16(execute 段)/17/18 + EC-01/12
**Requirement**: direct GDD trace(AC-21 / AC-22 / AC-23 / AC-36)

**ADR Governing Implementation**: ADR-0006(secondary — force-close 語意)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `bulk_salvage` synchronous single transaction(L585-617)— EC-12 兩邊由「synchronous 已執行就成立」推導

**Control Manifest Rules (Presentation)**: toast 報 execute return 唔報 preview(誠實 — EC-01)

---

## Acceptance Criteria

- [x] **AC-21**:confirm → toast 報 **execute return**(count/shards — thousands separators[017 落地前 placeholder + TODO])+ `ui_salvage_execute` 恰好 1 響 + `modal := NONE` + re-read;locked 件全存活
- [x] **AC-22**:row-tap preview 後 execute 前外部 mutation(test 直接 `_inv.salvage(victim)`)→ confirm → execute 當下真值,toast ≠ preview — 零 crash(+ 0-count 誠實邊界)
- [x] **AC-23**:equipped unlocked 件喺 range → #17 auto-unequip + backfill → re-read 反映(backup 要有 mods — strictly-better-than-empty 先 backfill)
- [x] **AC-36**:confirm 同 frame GSM force-close(EC-12 executed 邊)→ #17 state 已變(count/shards assert)+ 零 toast 零 SFX 零 re-read;下次 open render 新 state(mid-transaction subclass 模擬)

## Implementation Notes

- Bulk rebuild scroll reset 頂(005 component API);禁逐件 fade-out cascade(visual 紀律 — AC-32 manual 都會睇)
- EC-12 cancel 邊已喺 007(AC-05)— 本 story 只做 executed 邊

## Out of Scope

- Story 017:formatter 真身

## QA Test Cases

(= AC GWT;邊界:execute count==0[全部被外部食晒 — toast「已分解 0 件」照報 execute 真值]/ pending 件被 bulk 食[009 note 接])

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_bulk.gd`
**Status**: [x] Created — +5 tests(suite 17)全 pass;combined gate CLEAN 2339/2338/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 4/4 passing
**Deviations**: AC-36 實現機制 — `confirm_bulk_salvage` dispatch 後 re-check `_state != OPEN` 先 skip presentation;test 用 `ForceCloseMidTransactionInventory` subclass(bulk_salvage return 前觸發 GSM transition)模擬「同 frame」executed 邊 — 確定性重現 EC-12
**Test Evidence**: +5 tests — AC-21(SfxSpy 恰好一響 + locked 存活)/ AC-22 drift + 0-count / AC-23 backfill badge / AC-36 全鏈(transaction 成立 + 三零 + is_same view 證零 re-read + 下次 open 收割)
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 011
- Unlocks: —
