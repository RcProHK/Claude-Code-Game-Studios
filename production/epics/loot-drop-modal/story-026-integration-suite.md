# Story 026: Cross-system integration suite(real #15/#17/GSM/#20)

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-54 smoke/72/73/74(**G-flag-1 grep-VERIFIED:零 runtime gating site**);AC-71 @ 018 收;**AC-78 BLOCKED-ON #20 Q-OQ6 suppress 接線**(#20-side,deferred-tracked);combined 2101/2100/0 fail;commit 84a5ed2)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(AC §E Cross-system Integration 全組)
**ADR**: ADR-0006(GSM chain)+ ADR-0005(#15 round-trip)+ ADR-0003(#17 persist)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(real systems 組合 — headless GUT)

**Control Manifest Rules**:
- Required:integration tests 喺 `tests/integration/loot_reveal/`;combined CI gate
- Forbidden:isolation fake 冒充 integration(本 story 全 real systems)

## Acceptance Criteria

- [ ] **AC-71**(#15 round-trip):real #15+#21,`loot_dropped`→reveal→dismiss→`modal_dismissed(drop_id, terminal)` → #15 以 drop_id dequeue(非 head-pop)、下次 query 唔見該件;**ordering case**:backend ACK 先到、reveal 後到 → 件仍喺 reveal queue、照 reveal、dequeue 唔 skip commit rename
- [ ] **AC-72**(#17 full handoff):real #17,full reveal → S3 → inventory 含 item、auto-equip 唔被阻;catch-up:stream batch 經 `begin/end_receive_batch` seam 連發 + RARE+ 逐件 S3 → #17 aggregate/push/persist **per batch/件各一次**(persist count spy)
- [ ] **AC-73**(GSM full loop):real GSM + real #15,entry→reveal→terminal dismiss → `modal_dismissed(terminal)` → #15 emit `loot_confirmed` → GSM 離開 LOOT_DROP(#21 zero GSM direct call — spy);intra-queue 期間 state 全程不變
- [ ] **AC-74**(**G-flag-1**):reveal 開咗 2s(<15s)player tap dismiss → 即生效(dismiss = completion 非 interruption)— **story-readiness 先 grep GSM code 證實 15s window 唔阻 player dismiss;唔對齊 → escalate CD**
- [ ] **AC-54**(EC-M3 smoke):已有 active freeze 時 `ceremony_freeze` → max-remaining、release 只清自己 entry(主測喺 021 #6-side,呢度只 smoke 防雙邊 drift)
- [ ] **AC-78**(#20 banner stack):real #20 audio banner 顯示中,`loot_disabled` 到 → 同屏一條、private_mode 取代;清走後 audio banner re-render(displacement ≠ one-shot)— **[gated #20 Q-OQ6:「同屏一條」arbitration 需 #20-side suppress 接線;#20-side 未有 → 本 AC 標 BLOCKED-ON #20 wiring,其餘 5 條唔受影響]**

## Implementation Notes

- 全部 gates(017–025)落地先開本 story — gated ACs 嘅 real-system 半邊喺度收齊。
- Combined CI gate(`tests/unit` + `tests/integration`)必行 — cross-file bug 教訓。
- AC-78 嘅 #20-side suppress 接線如需 #20 patch:consumer-forward-contract 原則 — #21 唔 patch #20 GDD,接線 story 屬 #20-side(escalate 處理)。

## Out of Scope

- 真 browser wall-clock / SR / 視覺(027);G-PR/#2 backend live(EXTERNAL)。

## QA Test Cases

GDD AC-54/71/72/73/74/78 GWT(qa-plan-import-equivalent);AC-72 persist count spy 係 G-LM-10 嘅 ground truth。

## Test Evidence

**Required**: `tests/integration/loot_reveal/test_cross_system_suite.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 017、018、019、020、021、022、023、024、025(全 gates)+ 009–016(#21-side)
- Unlocks: 027、epic 收線
