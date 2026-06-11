# Story 002: G-CV-1 ADR-0001 amendment — 2 CanvasLayer topology

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(§Detailed Design Core Rules intro + R-11 + UI Requirements + Q-CV2)
**Requirement**: `TR-cvf-002`(trace 直接 GDD;#21/#22/#23/#24/#26 layer-amendment 先例)

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary)
**ADR Decision Summary**: CanvasLayer topology + 200 particle cap + BackBufferCopy@100 capture ≤100 / >100 immune;layer amendment 須喺 ADR 明寫 enumeration 防 phantom-citation。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: CanvasLayer `follow_viewport_enabled`(Godot 4.x — number layer 跟 Camera2D);`>100` layer 喺 BackBufferCopy@100 之上故唔被 capture(免第二 BBCopy,#24 ErrorBannerLayer 111 先例)。ratification-gated(同 #5/#6 FR-1/2/3 gated)。

**Control Manifest Rules (Presentation)**:
- Required: CanvasLayer 拓撲改動經 ADR-0001 amendment;BBCopy enumeration 明寫
- Forbidden: 加 layer 而唔更新 ADR enumeration(phantom-citation,[[feedback_lint_allowlist_adr_sync]])
- Guardrail: overlay ≤1 blend pass;200 cap 全局共享

---

## Acceptance Criteria

*From GDD G-CV-1 / Q-CV2:*

- [x] ADR-0001 amendment 加**兩個** #25-owned CanvasLayer:**(a)** `CombatNumberLayer`(`follow_viewport_enabled=true`,sort order 坐 ParticleLayer[10] 上 / HUDLayer[50] 下,**入** #6 world-shake shader-uniform 施加範圍)+ **(b)** `CombatOverlayLayer`(layer **105**,全屏)— diagram + #25 revision subsection + amendment header
- [x] BBCopy enumeration note 明寫:`105 > 100` 故 shake/BackBufferCopy-immune,**唔加入** capture list(防 phantom-citation;對齊 #24 ErrorBannerLayer 111 先例)— mechanism note 加 105 immune list;CombatNumberLayer 15* 入 captured band(positional <100,跟 #22/#23/#24 enumeration-sync discipline)
- [x] layer ordering 記錄:`CombatOverlayLayer(105) < CelebrationVFXLayer(110)` → loot ceremony 永遠視覺壓過 combat overlay
- [x] ratification gate 標記:amendment ratify 前 = EC-20 degrade(overlay 無 flash + `CRITICAL_DEGRADE_PAUSE_SEC=0.100`;number fixed-viewport)— whole-overlay gated class (同 #5/#6 FR-1/2/3);AC-24 `pending()` gated-honesty;degrade(AC-07b)CI-testable

---

## Implementation Notes

*Derived from ADR-0001:*

- 呢個 story = **doc amendment**(ADR-0001 文件 + technical-preferences ADR-0001 entry);實際 CanvasLayer node 創建喺 story 003(scaffold)/ 009(number layer host)/ 010(overlay)。
- `CombatNumberLayer` 解決「autoload-owned Node2D 但要 world-anchored + shaken」矛盾:autoload 自管一個 `follow_viewport_enabled` CanvasLayer,#6 world-shake uniform 施落此 layer。確認接駁機制(uniform 施加點)vs reparent 替代 = amendment 內寫明。
- BBCopy enumeration:現有 capture list 枚舉 ≤100 嘅 layer;#25 兩 layer 中 `CombatNumberLayer`(10-50)**入** capture(跟 world shake);`CombatOverlayLayer`(105)**唔入**(immune)。明寫防後續 lint phantom。

---

## Out of Scope

- Story 003/009/010: 實際 CanvasLayer node 創建 + render
- Story 016: registry knob 註冊

---

## QA Test Cases

- **AC-1**: ADR enumeration 完整
  - Given: ADR-0001 文件
  - When: 加 #25 兩 layer amendment
  - Then: 兩 layer 各有 sort/immune/capture-membership 明寫;`105>100` immune note 在
  - Edge cases: 漏寫 BBCopy membership → 後續 lint phantom（驗 enumeration 完整）
- **AC-2**: ratification gate 標記
  - Given: amendment 未 ratify
  - When: 讀 EC-20
  - Then: degrade path(無 flash + degrade-pause 0.100 + number fixed-viewport)有定義

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check — ADR-0001 amendment doc 完整(兩 layer enumeration + BBCopy membership + ratification note)
**Status**: [x] Verified 2026-06-11 — ADR-0001 amendment doc complete: amendment header + topology diagram (CombatNumberLayer 15* + CombatOverlayLayer 105) + #25 revision subsection + BBCopy mechanism-note sync (105 immune / 15* captured) + GDD-Requirements row + technical-preferences ADR-0001 entry. Doc-only (no code/test; node creation deferred to story 003/009/010). `--import` unaffected (no .gd change).

---

## Dependencies

- Depends on: None(scaffold 前提之二)
- Unlocks: Story 009(number layer host)、Story 010(overlay layer)
