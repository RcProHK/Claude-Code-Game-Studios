# Story 009: INV-M3 S3 commit point + EC-M14 五 variant + EC-M5 coercion + AC-21 lint

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-20/21(lint PASS)/56 unit 半/65 #21-side 半;GUT 77/77;combined 2007/2006/0 fail;commit d29363b)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 7 INV-M3 / EC-M14 / EC-M5)
**ADR**: ADR-0007(RarityTier classification coercion,primary for EC-M5)+ ADR-0003(stateless — #21 零 persistence 寫入)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:enum coercion `EnumType.get(name, SENTINEL)` 慣例(EC-M5 用 COMMON floor,#17 `inventory_system.gd:180` 同源)
- Forbidden:#21 寫任何 persistence namespace(stateless presentation)

## Acceptance Criteria

- [ ] **AC-20**(receive_loot @ S3 exactly-once):S3 到達(未 tap)→ call exactly once;tap 後無第二次;永不 tap + stash-exit → 已 banked
- [ ] **AC-21**(唯一 caller,owner-exempt CI lint):CI grep `src/` — `receive_loot(` caller 喺 `inventory_system.gd`(owner 內部 4 個 re-entrancy/boot-drain sites)以外只有 #21 coordinator 一個 call site — Static/CI
- [ ] **AC-56**(EC-M5 coercion 同源):`rarity_tier="MYTHIC"` → `RarityTier.get(s, COMMON)` 喺 ladder lookup **前**、COMMON ceremony、無 bar、telemetry `unknown_tier`;cross-check 同 fixture 餵 real #17 → 入庫 tier == 顯示 tier
- [ ] **AC-65(#21-side 半)**(EC-M14 ×5,fake #17):S3 `receive_loot` 回 OK → 正常;FAILED_ROLLBACK → **零 user-visible delta** + 照 dismiss + CRITICAL telemetry + `report_receive_failure(drop_id)` call exactly-once(**[#15 handler gated G-LM-4 — fake seam]**);QUEUED_SUSPENDED → 當 success + stash-exit;DUPLICATE_NOOP → success + 無第二 micro_ack;CONVERTED_DUPE → 正常 + shard ack 入 F4 deferred aggregate(flush 喺 terminal + safe state)

## Implementation Notes

- INV-M3:S3 = **唯一** banking + dequeue commit point;tap 純 ceremonial(撳快門);S3 未到 = 件未離開 #15 queue(零 emit 零 bank)。
- `FAILED_ROLLBACK` 真假 ambiguous(re-entrant defer path 都 return — `inventory_system.gd:161-163`)— 零 error UI,report 對 defer path 係 no-op class(#15 handler dedupe)。
- AC-21 lint 跟 PR #12 owner-exempt 教訓:lint 必須 exempt owner 內部 call sites,grep owner file 防 main RED。
- `ReceiveResult` 五值 @ `equipment_enums.gd:56-62`。

## Out of Scope

- `report_receive_failure` #15-side handler(018);batch commit 路徑(015/024);micro_ack banking(013)。

## QA Test Cases

GDD AC-20/21/56/65 GWT(qa-plan-import-equivalent);AC-65 ×5 parametrized over `ReceiveResult`(integration 半邊 real #17 喺 026)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_s3_commit.gd` + `tools/ci/check_receive_loot_callers.gd`(owner-exempt)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 006
- Unlocks: 011、013、026
