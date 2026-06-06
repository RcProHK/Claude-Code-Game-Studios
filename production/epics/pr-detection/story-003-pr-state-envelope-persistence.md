# Story 003: `pr.state` envelope persistence + round-trip

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 8 / EC-11)
**ADR**: ADR-0006 C3(SerializableResource to_dict/from_dict)+ ADR-0003(backend-primary;flush=true anchor)+ ADR-0009(typed envelope)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:envelope 經 `to_dict()` 落 `write()`(#3 flush = JSON.stringify — write Resource instance = silent corrupt;GSM tombstone `game_state_machine.gd:540` + loot `loot_drop_system.gd:634` 先例)
- Forbidden:localStorage;per-key `pr.best.*`(IPersistence 冇 enumeration — Rule 8 binding)

## Acceptance Criteria

- [ ] **AC-17**:`pr.state` envelope(baselines / pending / candidates / workout_seq / lifetime_count / lifetime_pr_score)round-trip 還原;PR 確認 = **一次** write flush=true(Rule 6.6 collapse)
- [ ] **AC-26**:write return false → in-memory 保持(後續判定一致)+ `pr.persist_failed` telemetry;唔 crash

## Implementation Notes

- 單一 key `pr.state`;envelope schema 跟 GDD Rule 8 逐 field。Pending inner:`{e1rm_raw, weight, reps, opened_seq}`。`workout_seq` 喺 #2 `workout_started` +1。
- Round-trip test **必須行 fresh-load 真 path**(JSON coercion;#19 AC-08 同款 lesson — 同 instance cache read = phantom pass);typed dict values rebuild。
- Boot:`read("pr.state")` 還原 + **stale candidates discard**(Rule 8a)。

## Out of Scope

- Server baseline reconcile(008)/ candidates 語意(006)/ pending 語意(007)。

## QA Test Cases

GDD AC-17 / AC-26 GWT。Edge:corrupt envelope(non-Dictionary)→ fresh state + telemetry;flush 失敗 = #3 corrupt path whole-cache wipe(EC-11 acknowledge,唔 assert #3 內部)。

## Test Evidence

**Required**:`tests/integration/pr_detection/test_pr_state_roundtrip.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 005, 006, 007, 008, 010
