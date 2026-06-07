# Story 006: Ceremony ladder D2 調用序 + EC-M9 margin/watchdog + S1 content-final

> **Scope 變更(2026-06-07)**:**AC-55(EC-M4 motion_reduction matrix)由 story-004 移入** — assert 對象(`request_focal` 零 call / shake 0 / particle ×0.5)係本 story 先存在嘅 ladder 調用;F1 timing variant 半邊已喺 004 完成(AC-41)。

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 3 / Rule 4 / EC-M9 / F1 freeze 錨點)
**ADR**: ADR-0001(particle preset caps,secondary);數值 source = #15 Visual Spec Table(data-driven)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(cross-system 調用序;freeze API shape gated G-LM-3 — fake seam 先行)

**Control Manifest Rules**:
- Required:particle 經 `ParticleSystemWrapper.play()`(CI enforced);camera 經 `CameraController.request_focal`(直接 mutate Camera2D forbidden)
- Forbidden:`GPUParticles2D` 直 instantiate;hardcode ladder 數值(grep source 無 magic number — AC-13)

## Acceptance Criteria

- [ ] **AC-8**(FR-2 structural):reveal 開始 → #5 `play()` 同一 call stack 同步發出(無 await/timer 先行)且 preset per tier 正確(C/U/R→LOOT_BURST;E/L→LOOT_RARE_BURST)
- [ ] **AC-10**(S1 content all-final):scale-in 完成 frame,視覺 content slots(UX §B 1-6)== final fixture 且零 active content tween(slot 7 SR @ S3 唔屬範圍)
- [ ] **AC-12**(D2 調用序,LEGENDARY fake spies):burst + fanfare(frame 0)→ `request_focal`(GSM==LOOT_DROP 後,T=0)→ **`focal_completed` 收到先** call `ceremony_freeze`(duration 由 #15 ladder config 讀)→ shake;saturation call **[gated G-LM-3 新 API — fake seam 先]**;fake #7 唔 emit → fallback timer T=D_hold+0.2s 照 freeze + telemetry
- [ ] **AC-13**(focal per-tier config):C/U 零 `request_focal`;RARE pulse / EPIC / LEG 各一次,args == #15 表數值(config 讀,grep 零 hardcode literal)
- [ ] **AC-14**(無 auto-dismiss):S3 無 input,fake clock 推 60s,modal 仍 open、無 scheduled dismiss timer
- [ ] **AC-60**(EC-M9):連續 2 件 EPIC+ → 件距 == `max(INTER_REVEAL_GAP_SEC, FOCAL_EXIT_MARGIN_SEC)`(deterministic,零 #7 state query — negative spy);fake #7 永不 emit → fallback freeze + queue 照 advance + telemetry `loot_reveal.focal_fallback`

## Implementation Notes

- D2 freeze-as-hold:camera push-in == S2a(focal entry duration == #15 hold 數值同源);`focal_completed` → freeze 將 pause-bound exit tween 凍住 → camera 釘 peak;freeze 自然 expiry → S3,exit tween 喺 S3 non-blocking 行完。
- `reveal_anchor_pos` = `get_tree().get_first_node_in_group(&"avatar_anchor")` query,缺位 fallback viewport center;burst 同 focal 共用。
- Fanfare caller = #21 coordinator(`play_sfx(loot_fanfare_{tier})` @ S0 — EG-1 precedent);LEGENDARY pre-roll 0.1s pre-shake 對齊(023 落 catalog)。
- **G-flag-4(story-readiness grep)**:#7 `FOCAL_EXIT_DURATION`(0.5)const — `FOCAL_EXIT_MARGIN_SEC`(0.6)下限約束 `≥ 0.5 − EXIT_ANIM_SEC + 0.1`。
- Shake #6 現有 API(ALWAYS process freeze 期間照行);saturation 經 fake seam(021 解封)。

## Out of Scope

- Freeze/release/saturation API 本體(020/021);INV-M1 出口(007);queue advance 機制(010)。

## QA Test Cases

GDD AC-8/10/12/13/14/60 GWT(qa-plan-import-equivalent);全部 fake #5/#6/#7/#4 seams + call-order spies。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_ceremony_ladder.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 004、005
- Unlocks: 007、009、010
