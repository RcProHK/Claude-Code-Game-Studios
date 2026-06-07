# Story 004: F1 timeline budget + 統一 timing model + motion_reduction

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-38/39/40/41;**AC-55 移交 story-006**(EC-M4 matrix assert 對象 = ladder 調用);GUT 23/23;combined 1953/1952/0 fail;commit 603ebe9)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(F1 + 統一 timing model + EC-M4 + Tuning Knobs C1 約束)
**ADR**: N/A — pure presentation formula;數值 source = #15 Visual Spec Table(data-driven 讀,零 hardcode)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:gameplay values data-driven(config resource,唔 hardcode)
- Forbidden:runtime clamp 代替 data-load assert(F1 明文)

## Acceptance Criteria

- [ ] **AC-38**:default config T_block == 200/350/650/950/**1200**;ceiling assert 係 `≤`(LEGENDARY equality 必須 pass)
- [ ] **AC-39**:注入違 C1 config(LEG D_entry=1300)→ validation **fail** 且**冇** runtime clamp
- [ ] **AC-40**:LEGENDARY fake clock — S1 同 S2a 喺 T=0 同時起跑,實測 T_block == 1200ms 非 1650ms(非 additive)
- [ ] **AC-41**:motion_reduction on → T_block == 200/350/500/650/800、D_timestop==0、單調性保留
- [ ] **AC-55**(EC-M4 matrix):motion_reduction on → `request_focal` **零 call 全 tier**、shake 0、particle ×0.5、hold/dismiss/queue 同 off 一致

## Implementation Notes

- `T_block(tier) = max(D_entry, D_hold + D_timestop)`;C1:`D_entry ≤ D_hold + D_timestop` ∀ tier — CI/data-load assert。
- 三 track 由 T=0 並行(S1 entry / focal push [0,D_hold] / ladder window);S0 = frame-0 event 唔係 duration;trigger→T=0 latency 唔計 budget。
- 全部 timer 行 global reveal clock(delta-time 累積);fake-clock test 錨 T=0 frame。
- Freeze 錨點:EPIC/LEG = `focal_completed`(fallback timer T=D_hold+0.2s);RARE/C-U = clock T=D_hold;budget 算術用 nominal config 數(唔受 signal jitter 影響)。
- Knob 互動:cross-reveal flash budget assert `2/(T_block_min+EXIT_ANIM+GAP) ≤ 3`(data-load,Tuning Knobs matrix)。

## Out of Scope

- Ladder 調用序 + watchdog(006);F5 tap 窗(005);freeze API 本體(G-LM-3,021)。

## QA Test Cases

GDD AC-38/39/40/41/55 GWT + pinned vectors(qa-plan-import-equivalent)。AC-55 negative spy on fake #7。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_f1_timeline.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 003
- Unlocks: 005、006
