# Story 012: Rollback paths(pre-S3 / S3 no-op / queued / re-query)

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 11 全四 bullet + 永不 show-then-revoke 原則)
**ADR**: N/A — #21-side presentation policy(#15 rollback path own queue 處理)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:rollback cancel 用 0-frame snap(唯一准用 0-frame 嘅 path);timescale guaranteed-restore(INV-M1)
- Forbidden:rollback 時 emit `modal_dismissed`(#15 自己處理 queue — emit 會 double-advance)

## Acceptance Criteria

- [ ] **AC-30**(rollback mid-reveal,×3):S0–S2 任一段收 `loot_rollback`(該 drop_id)→ ≤1 frame cancel、timescale restored、無 terminal frame、無 toast、`modal_dismissed` count == 0、cancel 後 re-query:queue 非空 → gap 後下一件 ENTRY;空 → terminal emit(GSM 唔 stuck)
- [ ] **AC-30b**(S3 = 顯示層 no-op):S3 收 `loot_rollback` → modal 照留 STEADY、可正常 dismiss、telemetry `late_rollback`、零 cancel 副作用(post-banking)
- [ ] **AC-31**(queued rollback):rollback 目標係未 reveal queued drop → #21 零動作(pull model — 下次 query 見唔到)

## Implementation Notes

- Rollback-cancel 之後**必須 re-query**(否則 GSM 永久 stuck — Rule 13 只係 entry-time check);in_catchup 時 re-query 對象 = 本次已揀定 ceremonies 殘餘(K-cap 唔重揀);ceremonies 清咗 → CATCHUP_GRID。
- S3 post-banking rollback 屬 #15/#17 post-grant reconciliation,#21 唔演(show-then-revoke 禁令)。
- S0 burst 係 non-committal;S1 content 填充 gate 喺 #15 optimistic persist local commit 窗口後 — 玩家見到嘅失敗形態永遠係 deferral 唔係 revocation。

## Out of Scope

- EC-M16 stream beat rollback(015);#15 rollback queue 處理(#15 shipped);INV-M1 出口本體(007)。

## QA Test Cases

GDD AC-30/30b/31 GWT(qa-plan-import-equivalent);AC-30 ×3 parametrized S0/S1/S2 + re-query 雙 branch + in_catchup branch。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_rollback_paths.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 007、010
- Unlocks: 015
