# Story 012: Bulk execute + preview-execute drift + EC-12 兩邊

> **Epic**: Inventory UI (#23)
> **Status**: Ready
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

- [ ] **AC-21**:confirm → toast 報 **execute return**(count/shards — thousands separators[017 落地前 placeholder + TODO])+ `ui_salvage_execute` 恰好 1 響 + `modal := NONE` + re-read;locked 件全存活
- [ ] **AC-22**:row-tap preview 後 execute 前外部 mutation(test 直接 `_inv.salvage(victim)`)→ confirm → execute 當下真值,toast ≠ preview — 零 crash
- [ ] **AC-23**:equipped unlocked 件喺 range → #17 auto-unequip + backfill → re-read 反映
- [ ] **AC-36**:confirm 同 frame GSM force-close(EC-12 executed 邊)→ #17 state 已變(count/shards assert)+ 零 toast 零 SFX 零 re-read;下次 open render 新 state

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
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 011
- Unlocks: —
