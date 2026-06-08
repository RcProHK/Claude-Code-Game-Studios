# Smoke Check — Story 018: G-LS-7 FSM extraction closure

> **Date**: 2026-06-09
> **Story**: `production/epics/login-shell/story-018-fsm-extraction-closure.md`
> **Type**: Config/Data (doc) — comment-only closure note
> **Verdict**: ✅ PASS

## Scope

G-LS-7 = close the rule-of-three FSM-extraction question that the #23 InventoryUICoordinator
fork notice left pending「the shared base/component ADR opens at #24 Shell authoring」.
#24 (Login/Shell) is now authored → it reviewed and decided NOT to extract a shared
ScreenLifecycleFsm. doc-only: NO change to #22/#23 production FSM code.

## Verification

| 檢查項 | 期望 | 實測 | Pass |
|--------|------|------|------|
| #23 fork notice closure | `inventory_ui_coordinator.gd` FSM FORK NOTICE block 加 G-LS-7 CLOSURE 注記指向 Rule 14 | ✓ 加在 fork-block 尾(divergences 後、==== 前) | ✅ |
| #22 header closure | `character_screen_coordinator.gd` header 加對應 closure 注記 | ✓ 加在「Pure overlay review surface」後 | ✅ |
| 裁決一致性(godot-specialist degraded-inline) | login = boot-surface ≠ overlay lifecycle → 唔 extract = 正確抽象;將來第三個真 overlay 先 extract | ✓ 兩 header 注記一致,指向 GDD Rule 14 | ✅ |
| 零 FSM code 改動 | #22/#23 各自 5-態 overlay FSM(ScreenState enum / advance / open / close / _on_gsm)不變 | ✓ 純 comment 注記,零 production code 改動 | ✅ |
| Parse 不破壞 | comment-only,#22/#23 + 其 test 仍 green | ✓ import + char_screen/inventory_ui tests green(見 commit gate) | ✅ |

## Verdict

✅ **PASS** — G-LS-7 closed. #22/#23 fork notice 各有 Rule 14 closure 注記(裁決:#24 唔
extract — login boot-surface ≠ overlay lifecycle);零 FSM code 改動;fork 維持 mirror-maintained。
