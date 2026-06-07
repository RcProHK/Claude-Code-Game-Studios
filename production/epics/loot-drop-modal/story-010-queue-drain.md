# Story 010: Queue drain intra/terminal + EC-M6/M20 + empty-queue + content source

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 6 / Rule 13 / EC-M6 / EC-M20 / Rule 2 pull model)
**ADR**: ADR-0009(`modal_dismissed(drop_id, terminal)` payload minimal+intrinsic,primary)+ ADR-0006(GSM zero-direct-call seam)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:signal snake_case past tense;payload 唔帶 ambient context
- Forbidden:#21 direct call GSM(exit 行 #15 `loot_confirmed` chain — GSM AC-14)

## Acceptance Criteria

- [ ] **AC-18**(intra-queue):queue 2 件,第 1 件 dismiss → `modal_dismissed(drop_id, terminal=false)` 正確、**全程零 GSM direct call**(negative spy)、gap 後第 2 件 ENTRY
- [ ] **AC-19(#21-side 半)**(terminal 順序):queue 剩 1 件 dismiss → S4 anim **完成先** emit `modal_dismissed(drop_id, terminal=true)`,anim 中途零 emit;零 GSM direct call(**[#15 handler emit 半邊 gated G-LM-4]**)
- [ ] **AC-32**(content source):signal payload 同 `get_drop()` 餵唔同值 → 顯示 == `get_drop()`(committed store);fill 時 null → EC-M6 skip,永不 render placeholder
- [ ] **AC-34**(empty-queue entry):GSM→LOOT_DROP 但 queue 空 → 即 emit `modal_dismissed("", terminal=true)`、modal 唔開、GSM 唔 stuck(#15 chain)
- [ ] **AC-57**(EC-M6):`get_drop()` null → skip(無 modal / receive_loot)、CRITICAL telemetry `dangling_drop`、gap 後 advance;terminal 件 → terminal dismiss 出口
- [ ] **AC-70**(EC-M20):terminal S4 行緊時新 drop → 永不 mid-exit 重入;gap 後重評 terminal → 有新件唔 exit GSM 繼續

## Implementation Notes

- Pull model:dismiss → emit → re-query `get_pending_drops()`;intra-queue gap = `max(INTER_REVEAL_GAP_SEC, 上件 EPIC+ ? FOCAL_EXIT_MARGIN_SEC : 0)`(EC-M9)。
- Intra-queue **GSM 唔郁**(唔 exit/re-enter LOOT_DROP)— **G-flag-3 殘餘(story-readiness grep)**:intra-queue 語意 + GSM L128 drain cadence erratum(019 執行)。
- Terminal 判定喺 gap 結束時重新評估(EC-M20)。
- One-modal-at-a-time:reveal 行緊時新 `loot_dropped` → no-op(doorbell,002 已接)。

## Out of Scope

- #15 dequeue handler + `loot_confirmed` emit(018);force-close idempotent S4(011);catch-up 重排(014/015)。

## QA Test Cases

GDD AC-18/19/32/34/57/70 GWT(qa-plan-import-equivalent);fake #15 queue seam + GSM negative spy。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_queue_drain.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 006
- Unlocks: 011、012、014
