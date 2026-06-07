# Story 018: G-LM-4b — #15 handlers/signals(dismiss dequeue / loot_confirmed / report_receive_failure)

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — ③④⑤ + AC-19/34b/65 解封 + AC-71 ordering 全鏈;**bonus bug fix:#15 micro_ack optimistic emit 早過 registration → get_drop 永遠 null,emit 移去 post-registration**;integration 6/6;combined 2068/2067/0 fail;commit 3697f96)
> **Layer**: Presentation(epic)/ 改動喺 Core #15
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-4 ③④⑤ + Rule 6/7/13)
**ADR**: ADR-0009(payload)+ ADR-0006(GSM exit chain — `loot_confirmed` → GSM 訂閱,zero-direct-call AC-14)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(改 shipped #15 + 接 GSM seam — combined CI gate 必行)

**Control Manifest Rules**:
- Required:`modal_dismissed(drop_id, terminal)` payload minimal;dequeue **以 drop_id**(唔係 head-pop — catch-up 可重排;transition_id debug path 會碰撞)
- Forbidden:#21 direct call GSM

## Acceptance Criteria(G-LM-4 ③④⑤ — 解封 AC-19/29/34b/65 #15 半邊)

- [ ] **③ `modal_dismissed(drop_id, terminal)` handler**:#15 訂閱 #21 emit,以 drop_id dequeue;#15 EC-29 double-dismiss guard 兼容;catch-up 重排順序下正確
- [ ] **④ terminal → emit `loot_confirmed`**:#15 見 terminal=true 且 queue 空 → emit `loot_confirmed` → GSM 訂閱觸發 exit transition(GSM AC-14 / L234 locked 機制)— AC-19/34 嘅 #15 半邊解封
- [ ] **⑤ `report_receive_failure(drop_id)` handler**:#15 寫 `loot.pending.recovery`(sole-writer namespace);**dedupe**(defer-path 假報 = no-op class);#17 EC-1 boot-drain eventual grant 鏈接通 — AC-65 report 半邊解封
- [ ] **Gated ACs 解封驗證**:story 009/010/013 嘅 fake-seam tests 換 real #15 重跑(AC-19 full / AC-34b dequeue 半 / AC-65 report 半)— 全 green
- [ ] **Combined CI gate green**

## Implementation Notes

- Emit-back seam:#21 → emit → #15 handler — reverse-wire pattern(#18 G-PR-2 先例)。
- `loot_confirmed` 係 shipped GSM 訂閱對象(gsm L234/L363)— #15 emit 半邊係新增,GSM 唔使郁(wiring 喺 019)。
- Pre-S3 cancel 路徑零 emit(D1)— handler 唔會收到未 banked 件。

## Out of Scope

- Retry-suppression + `_check_pending_loot_reveal` wiring(019);fast-victory ⑧(019)。

## QA Test Cases

GDD AC-19/34b/65 gated 半邊 GWT(qa-plan-import-equivalent)+ G-LM-4 ③④⑤ gate text;integration tests real #15 + fake GSM spy。

## Test Evidence

**Required**: `tests/integration/loot_reveal/test_loot_handlers_reverse_wire.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 017(+ 009/010/013 嘅 fake-seam tests 先存在)
- Unlocks: 019、026
