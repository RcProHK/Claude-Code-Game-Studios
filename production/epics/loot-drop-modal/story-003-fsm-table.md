# Story 003: FSM 8-state × in_catchup table-driven

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(States and Transitions — 8-state 表 + terminal emit 語意 + 統一 timing model)
**ADR**: ADR-0006(state-machine 慣例,primary)+ ADR-0009(signal payload)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:signal naming snake_case past tense;payload minimal + intrinsic
- Forbidden:表外 transition 靜默跳

## Acceptance Criteria

- [ ] **AC-37**:table-driven 行 **8-state × in_catchup flag** 每條 edge(HIDDEN/ENTRY/CEREMONY/STEADY/EXITING/CATCHUP_PROMPT/CATCHUP_STREAM/CATCHUP_GRID;包括 CATCHUP_STREAM、EXITING→CATCHUP_GRID、CATCHUP_GRID terminal emit、rollback re-query edges)→ transition 按表;表外 → assert/no-op 唔靜默跳

## Implementation Notes

- Edge 全列跟 GDD FSM 表逐行(HIDDEN 三分支 depth==0/0<d<threshold/≥threshold;EXITING 四出口;CATCHUP_* 各 exit)。
- **FSM state ≠ timeline stage**:ENTRY/CEREMONY 係 input-policy gate;`ceremony_freeze` 發出時機由 timeline(T=D_hold)決定,唔係 state transition。
- `in_catchup: bool` 係 first-class mode flag,AC-37 斷言以 (state, in_catchup) pair 為 edge 單位。
- Terminal emit:`modal_dismissed("", terminal=true)`(空 drop_id 慣例 — Rule 13)。
- 下游 story 逐個填 state 行為;本 story 起 transition 骨架 + 表 + edge assert。

## Out of Scope

- 各 state 內行為(timing 004 / input 005 / ladder 006 / commit 009 / drain 010 / catch-up 014-015)。

## QA Test Cases

GDD AC-37 GWT:table-driven parametrized sweep,每 edge 一 case;off-table 注入 assert 觸發(qa-plan-import-equivalent)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_fsm_table.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 004、005、006、010、014
