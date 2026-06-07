# Story 020: G-CS-5 + G-CS-6 doc errata + manual evidence protocol

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — G-CS-5 / G-CS-6 rows + Group G ADVISORY ACs
**Requirement**: direct GDD trace

**ADR Governing Implementation**: N/A — doc errata + evidence protocol(#21 story-027 先例)
**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **G-CS-5**:loot-drop-modal.md OQ-1 row → RESOLVED(ticker 留 #22 Rule 16;modal 唔加 slot)
- [ ] **G-CS-6**:interaction-patterns.md errata —(a)P-03「Used In: #22」sync note(F1 ≠ ticker);(b)P-07/P-08 SR narrates 行更新(shipped announce_aria 已超越 v0.2+ 措辭)
- [ ] **Manual evidence protocol 交付**(AC-43b/44/45b/46/47/48 — 收集 EXTERNAL):`production/qa/evidence/character-screen/README.md` 寫明逐條 setup / verify / pass condition(#21 protocol 先例);AC-46 evidence 標準 =(a)`check_platform_detect_callers.gd` lint pass cite +(b)web build back-button 截圖
- [ ] AC-49 RATIFICATION-GATED 記錄在案(mobile 真機 — ADR-0001 ratify 後)

## Implementation Notes

- Pattern library 5 個 NEW patterns(UX spec UXQ-4:ledger-watermark-line / three-zone-item-card / inline-nudge-strip / destructive-confirm-modal / bottom-sheet-picker)— 隨 G-CS-6 batch 加 catalog stub rows(Defined 留 /ux-design patterns session)
- AC-48 playtest protocol:≥3 testers ≥5min + 三 observable + 2 watch-items(nudge noticed rate / 進步引用元素)

## Out of Scope

- 真 browser / 真 SR / 真機收集(EXTERNAL — protocol 交付即 story 完成,#21 027 先例);audio assets(Q-CS7 /asset-spec)

## QA Test Cases

- **Doc diff**: 3 份 doc 對應行 diff;grep OQ-1「RESOLVED」hit
- **Protocol**: README 每條 AC 有 unambiguous pass condition

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: doc diffs + `production/qa/evidence/character-screen/README.md` + smoke check
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(doc 隨時;protocol 引用 UI 行為 — nominal 016/018 後出最準)
- Unlocks: None(leaf;epic 收線項)
