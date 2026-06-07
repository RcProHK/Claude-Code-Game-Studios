# Story 021: G-LM-3b — #6 ceremony_freeze + release(handle) + saturation API

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — ①③④⑤ + EC-M3 主測試;ceremony_freeze→handle / idempotent release / saturation uniform path + recovery;解封 AC-1 release-shape / AC-12 freeze-shape / AC-54;combined 2083/2082/0 fail;commit 964b781)
> **Layer**: Presentation(epic)/ 改動喺 Foundation #6
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-3 ①③④⑤ + EC-M3 + Formulas grep ①④)
**ADR**: ADR-0001(HIGH — saturation 行 BackBufferCopy shader uniform path,Compatibility/WebGL2)
**Engine**: Godot 4.6 | **Risk**: **HIGH**(shader path + engine pause 互動;G-LM-1 topology 前提)

**Control Manifest Rules**:
- Required:shader uniform path(shake 同款慣例);#21 唔掂 `get_tree().paused` — #6 own
- Forbidden:`ceremony_freeze` 受 `MAX_PAUSE_SEC=0.12` clamp(自己 ceiling `CEREMONY_FREEZE_MAX_SEC=0.4`)

## Acceptance Criteria(G-LM-3 ①③④⑤ — 解封 AC-1 release / AC-12 freeze-shape / AC-54)

- [ ] **① `ceremony_freeze(duration)` API**:ceiling 0.4s 自管(唔受 `MAX_PAUSE_SEC` 管);BOOTING/SUSPENDED 唔 serviceable → reject(`screen_effects.gd:344-346` pattern — EC-M2 caller 兜);共用 020 ledger
- [ ] **③ idempotent 早收 `release(handle)` API**:早於自然 expiry 收回自己 entry;double-release no-op;未-issue handle no-op(INV-M1 出口而家有 API 兌現)
- [ ] **④ saturation API(全新)**:world −60% desaturation 經 BackBufferCopy shader uniform 通路;>100 layers immune(G-LM-1 topology);2.0s recovery non-blocking ambient
- [ ] **⑤ Suspended/focus-resume 安全網繼承**:override hard-cancel 清 ceremony entries + 還原(EC-M1 嘅 #6 半邊)
- [ ] **EC-M3 主測試(#6-side)**:已有 active freeze 時 `ceremony_freeze` → max-remaining 延長;release 只清自己 entry — AC-54 嘅主場(#21-side 只係 smoke)
- [ ] **Gated ACs 解封驗證**:story 006/007 fake-seam tests 換 real #6 重跑(AC-1 release-API 半 / AC-12 freeze-shape)— green
- [ ] **Combined CI gate green**(#6 existing tests 零變紅)

## Implementation Notes

- Freeze ceiling 理由差異:hit pause 0.12 = 「無 visual anchor 嘅 freeze 似 hang」;ceremony 期間 modal layer ALWAYS + burst 動畫做 anchor → 0.4 合法。
- Saturation shader:grep 證實 shipped #6 零 saturation 實現 —「現有 API」係 phantom,全新建。
- `release(handle)` 係 #21 INV-M1 嘅 API 載體 — 簽名要支持 spy 斷言(單一 call-site)。

## Out of Scope

- Ledger 結構(020 已做);#21-side 調用(006/007 已寫,本 story 解封);AC-87 visual 截圖(027)。

## QA Test Cases

G-LM-3 ①③④⑤ gate text + GDD AC-54 GWT(qa-plan-import-equivalent);release idempotency ×3(early / double / never-issued)。

## Test Evidence

**Required**: `tests/unit/screen_effects/test_ceremony_freeze_api.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 020(+ 001 G-LM-1 topology pin)
- Unlocks: 026(AC-54 smoke)、027(AC-87)
