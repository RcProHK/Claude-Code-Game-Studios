# Story 015: #17 command 模式 + error handling + EC-04 orderings + DISCONNECTED suite

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 14/15(return shape pin + sequencing note + toast live region)+ EC-04/17/23/30
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0006(call_deferred / frame ordering)
**ADR Decision Summary**: #17 commands synchronous Dictionary return;`stat_changed(EQUIPMENT)` 喺 return **之前** fire;`deferred_reentrancy` = #17 下 frame replay。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(frame-ordering tests)
**Engine Notes**: AC-33(iii)**必須真 #17 誘發**(`_mutating` window 經 signal-handler re-entrant call — `tests/unit/equipment/test_reentrancy_guard.gd` idiom;**禁 mock stub**);replay 收割 `await process_frame` ×1

---

## Acceptance Criteria(GDD AC-25/26/33/50)

- [ ] **AC-25**:equip ok → 同 frame re-read + slot card 更新;cosmetic equip → 無 stat tween,`avatar_visual_updated` 驅動 swap
- [ ] **AC-26**:**全 5 error**(not_found/slot_type_mismatch/in_mailbox_claim_first/slot_empty/locked)→ re-read + toast(`.get("error","")`);deferred_reentrancy → 無 toast,下 frame 收割
- [ ] **AC-33**:EC-04 三 ordering 逐個重演 =(i)command 成立+skip render+toast drop(ii)input ignore(iii)replay 照行+下次 open 收割 — (iii) 真 #17 誘發
- [ ] **AC-50**:DISCONNECTED + OPEN:equip/set_lock/salvage confirm/slider settle 全部同 IDLE 一致,唯一 delta = banner

## Implementation Notes

- Success return 冇 "error" key(equip `{"ok": true}` L670;salvage `{"ok": true, "shards": N}` L578)
- Toast = ARIA live region 標記(announce 喺 story 019 wire);同屏最多 1 條(UX spec 並發表)
- EC-04(iii):#17 replay 係 #17 自己機器 — #22 唔 re-read 唔 toast

## Out of Scope

- Story 016:salvage modal flow;Story 019:announce_aria wiring

## QA Test Cases

GDD AC-25/26/33/50 GWT embed;真 #17 fixture(injection seam);EC-17 stale item_id case;frame-stepping process_frame only

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_commands.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 014
- Unlocks: Story 016 / 017
