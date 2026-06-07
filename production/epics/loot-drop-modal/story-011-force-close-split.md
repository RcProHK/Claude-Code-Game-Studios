# Story 011: Force-close D1 pre/post-S3 split + stash-exit F6 + S4 idempotent

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-22/22b/23/51 + AC-62(EC-M11 safe→safe)+ AC-1 第三 cancel path;GUT 91/91;combined 2021/2020/0 fail;commit a7cd5f9)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 8 / Rule 7 D1 / F6 / Rule 5 MIN_REVEAL_WINDOW 措辭)
**ADR**: ADR-0006(GSM retry 語意 — `loot_reveal_pending` 保持 true 對齊 shipped GSM L127)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:cancel path 經 INV-M1 單一出口(007)
- Forbidden:pre-S3 emit `modal_dismissed`(會 dequeue 未 banked 件)

## Acceptance Criteria

- [ ] **AC-22**(post-S3 stash-exit):modal S3 open,GSM 外部 force-transition → stash anim ≤0.3s(無 input)→ emit `modal_dismissed` → deferred-ack +1 → 下次 safe-state entry(F4 flush gate)出 aggregated「+N」toast
- [ ] **AC-22b**(pre-S3 cancel + re-reveal,D1):S0/S1/S2 任一段 force-transition → ≤1 frame cancel、INV-M1 release、`modal_dismissed` emit count == 0、`receive_loot` 零 call、件留 #15 queue;下次 GSM→LOOT_DROP 該件 re-reveal(full ceremony 重行)、`re_reveal_count(tier)` telemetry +1、無 toast
- [ ] **AC-23**(S4 idempotent):S4 行緊時 force-close 落中途 → `modal_dismissed` emit count == 1
- [ ] **AC-51**(F6,post-S3 only):stash-exit → freeze release 同 frame + collapse ≤`STASH_COLLAPSE_SEC` + 總 ≤0.3s,release idempotent;SUSPENDED-triggered → 零 anim 即 emit(Rule 8)

## Implementation Notes

- D1 哲學:未撳快門 = 張相從未影過 — re-reveal untapped 係誠實;**已 banked(post-S3)永不 re-reveal**。
- Pre-S3 cancel 同 rollback-cancel 同 shape(INV-M1 出口);`loot_reveal_pending` 保持 true = GSM L127 retry 語意(shipped contract 對齊,#21 唔使郁 GSM)。
- `MIN_REVEAL_WINDOW`(15s)係 GSM **entry gate** 唔係 suppression window — `rest_ended` event-driven 可以 pre-S3 fire(D1 場景)。
- SUSPENDED-triggered force-close(任何段):零 frame render — 跳全部動畫即時行對應 branch。
- Stash anchor 固定 screen corner(UX spec §E)。

## Out of Scope

- F4 flush gate 本體(013);catch-up phase force-close(015 EC-M7);#15 queue 留件機制(017)。

## QA Test Cases

GDD AC-22/22b/23/51 GWT(qa-plan-import-equivalent);F6 budget 斷言(release 同 frame + collapse + jitter ≤0.3s)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_force_close_split.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 007、009、010
- Unlocks: 015、016
