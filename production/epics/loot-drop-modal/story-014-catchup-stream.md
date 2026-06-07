# Story 014: Catch-up prompt + stream + F3 + EC-M13/M18 + phase-gate termination

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 10 / F3 / EC-M8 / EC-M13 / EC-M18)
**ADR**: N/A — presentation flow;threshold/cadence 數值 #15 own(config 讀)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:`CATCH_UP_THRESHOLD`(5)/ `C_stream`(0.15)讀 #15 const;`MAX_STREAM_BEATS`/`K_CEREMONY_MAX` #21 knobs config 讀
- Forbidden:per-beat flash transient(WCAG 2.3.1 — luminance-stable beats,015 視覺斷言)

## Acceptance Criteria

- [ ] **AC-26**(threshold boundary):pending==4 → sequential;pending==5(==threshold,讀 #15 const)→ CATCHUP_PROMPT
- [ ] **AC-27**(prompt defer 零動作):CATCHUP_PROMPT defer → terminal emit → HIDDEN、pending 不變、`receive_loot` 零 call、零 GSM direct call
- [ ] **AC-46**(F3 bound + caps):worst-case(>40 sub-RARE、>5 RARE+ 全 EPIC+)→ T_machine ≤**15.8s**(前提:#7 正常 emit;watchdog degraded path 除外);120 sub-RARE → 40 beats(6.0s)+ 80 折 grid
- [ ] **AC-47**(F3 regression):30 件 fixture(14C+10U+4R+1E+1L)→ T_machine == **10.3s**(L+E+3R ceremony、1R 折 grid、L 前 gap 0.6)
- [ ] **AC-59**(EC-M8 phase-gate + termination):stream 中新 drop → append 規則按 phase(sub-RARE append stream 尾受 cap;RARE+ 插 ascending 受 K cap,cap 滿留 pending 唔入 grid;phase 已過留 pending);持續注入 → catch-up 仍 terminate(收斂 assert)
- [ ] **AC-64**(EC-M13 exclusive):boot force-reveal + depth 0/3/7 → 唔入 / sequential / catch-up;assert banner 同 sequential **永不同時**
- [ ] **AC-69**(EC-M18):banner deferred N=5 時新 drop → count→6 in-place、零新 entrance tween

## Implementation Notes

- Center prompt surface(唔用 top-edge banner — thumb-reach);input 語言同 modal 一致:全屏 tap = reveal-all,corner ≥48px = 「稍後再拆」defer。
- Defer = 留 Pending 下次再嚟;terminal emit → GSM 推進(retry-suppression 歸 G-LM-4 ⑥ — 019)。
- F3:`T_machine = T_banner_beat + min(N_sub, MAX_STREAM_BEATS)×C_stream + Σ top-K (G_gap + T_block) + T_grid`;ceremony 揀選 tier 降序 top-K,reveal ascending。
- 15s window truncation = accepted limitation(per-item/batch commit 零 loss;telemetry `catchup_truncated`)。
- Phase 唔回頭 = termination 保證。

## Out of Scope

- Stream 視覺 beats + commit 語意 + grid(015);稍後再拆 input z-order(005 keyboard / 015 行為)。

## QA Test Cases

GDD AC-26/27/46/47/59/64/69 GWT + pinned vectors(qa-plan-import-equivalent;F3 worked example 10.3s golden)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_catchup_flow.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 003、010、013
- Unlocks: 015
