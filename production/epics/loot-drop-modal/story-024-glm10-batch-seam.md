# Story 024: G-LM-10 — #17 public batch seam(begin/end_receive_batch)

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation(epic)/ 改動喺 Feature #17
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-10 + Rule 7 catch-up batch commit + #17 erratum draft ×3)
**ADR**: ADR-0003(persist-once 語意 — aggregate/push/persist 各一次)
**Engine**: Godot 4.6 | **Risk**: LOW(wrap 現有 internal 機制)

**Control Manifest Rules**:
- Required:public seam wrap internal `_batch_depth`(`inventory_system.gd:308/320/454/458`)— 唔重新發明 coalescing
- Forbidden:nested batch 無 guard;batch 中途 crash 留 dangling depth

## Acceptance Criteria(G-LM-10 — 解封 AC-72 batch 半 / AC-28+58 seam call 半)

- [ ] **`begin_receive_batch()` / `end_receive_batch()` public API**:wrap shipped internal `_batch_depth`;batch 內連發 N 個 `receive_loot` → aggregate / push / persist **各一次**(shipped external caller 連發 = N 次 full persist `inventory_system.gd:389-393` 問題修復)
- [ ] **Re-entrancy / depth guard**:nested begin/end 正確配對;unbalanced end no-op + warn;batch 內 `FAILED_ROLLBACK` 唔破壞 depth
- [ ] **#17 GDD/code erratum ×3**:`inventory_system.gd:145` doc comment caller = #21 @ S3(INV-M3)/ EC-1 recovery locus 經 `report_receive_failure` / EC-22+AC-29 batching 語意 internal-context-only 註明 + G-LM-10 public seam 指向
- [ ] **Gated ACs 解封驗證**:story 015 fake-seam tests 換 real #17 重跑(AC-28/58 seam call 半邊)— green(AC-72 persist count 留 026)
- [ ] **Combined CI gate green**(#17 1843+ tests 零變紅)

## Implementation Notes

- Shipped `_batch_depth` coalescing 係 internal-only(boot/suspended drain 專用)— 零 public API;本 story 只開口,唔改內部語意。
- Caller(#21)用法:stream-end / force-close / grid-overflow 嗰 frame `begin → 連發 receive_loot → end`。
- RARE+ ceremonies 照 per-item commit(唔經 batch — 件數 ≤K=5 有界)。

## Out of Scope

- #21-side batch 調用(015 已寫);AC-72 integration persist count(026)。

## QA Test Cases

G-LM-10 gate text(qa-plan-import-equivalent);persist-once test:batch 內 5 件 → persist spy count == 1;unbalanced end edge。

## Test Evidence

**Required**: `tests/unit/equipment/test_receive_batch_seam.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(parallel wave)
- Unlocks: 026(AC-72)
