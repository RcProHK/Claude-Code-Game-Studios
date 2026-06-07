# Story 007: INV-M1 freeze-release 單一出口 + EC-M1 suspend + EC-M2 reject degrade

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-2/52/53 全 + AC-1 兩 path(×4 parametrize 完成 @ 011/012 cancel paths 落地後);GUT 56/56;combined 1986/1985/0 fail;commit b7d82b1)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 11 INV-M1 / EC-M1 / EC-M2 / EC-M3 note)
**ADR**: N/A — #21-side invariant;release API shape gated G-LM-3(fake seam 先行,021 解封)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(time-stop dangling = 全 game 凍結 — #21 最高危 failure mode)

**Control Manifest Rules**:
- Required:#21 唔自己掂 `get_tree().paused`(#6 own Suspended 安全網)
- Forbidden:多個 release call-site(INV-M1 要求單一出口)

## Acceptance Criteria

- [ ] **AC-1**(INV-M1,×4 parametrized):任一 tier reveal 喺 S2b freeze active(fake #6 seam),行 4 個 cancel path 之一(fast-complete / `loot_rollback` / pre-S3 force-close / EC-M1 Suspended)→ freeze entry release **exactly once** 且 4 path 經同一 release 出口(spy 單一 call-site)**[release API shape gated G-LM-3]**
- [ ] **AC-2**(idempotent + 未-issue no-op):ledger entry 已被 #6 Suspended override 清走 **或 freeze 從未 issue**(tap 落 S2a)→ release no-op 無 error 無 double-decrement
- [ ] **AC-52**(EC-M1):S2b freeze 中 SUSPENDED(fake #6 已自清)→ resume ≤30s 直接重入 S3(receive_loot @ 重入嗰下 exactly-once)、`ceremony_freeze` spy count **不增**、release no-op;>30s → pre-S3 cancel 語意(唔 emit、留 pending、零 receive_loot — D1)
- [ ] **AC-53**(EC-M2):fake #6 reject freeze → ceremony 照行 motion_reduction variant、完整到 S3、telemetry `freeze_rejected`

## Implementation Notes

- 單一 `_release_freeze()` 私有出口;所有 cancel path(fast-complete / rollback / force-close / Suspended)必須經佢;「未 issue → no-op」係出口內部 guard。
- EC-M1 resume threshold = #15 `BFCACHE_CONTINUE_THRESHOLD_MS`(30s)— config 讀。
- **嚴禁 re-issue `ceremony_freeze`** 喺 resume 重入 S3 path。
- EC-M2 reject pattern 對齊 `screen_effects.gd:344-346`(BOOTING/SUSPENDED 唔 serviceable)。
- Freeze 狀態永不 survive suspend boundary。

## Out of Scope

- Ledger 本體 + max-remaining(020/021 #6-side);force-close branch 全貌(011);rollback 全貌(012)。

## QA Test Cases

GDD AC-1/2/52/53 GWT(qa-plan-import-equivalent);AC-1 ×4 parametrized over cancel paths,fake #6 seam。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_inv_m1_release.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 006
- Unlocks: 011、012
